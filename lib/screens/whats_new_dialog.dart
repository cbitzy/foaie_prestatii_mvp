// /lib/screens/whats_new_dialog.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foaie_prestatii_mvp/whats_new_text.dart';

Future<void> showDialogWhatsNew(BuildContext context) async {
  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final screenSize = MediaQuery.of(ctx).size;
      final latestEntry = whatsNewEntries.first;
      final latestText = buildWhatsNewEntryText(latestEntry);
      final olderText = buildWhatsNewOlderEntriesText();
      final hasOlderEntries = olderText.trim().isNotEmpty;

      return PopScope(
        canPop: false,
        child: AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.04,
            vertical: screenSize.height * 0.015,
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: Text(
            '$whatsNewTitle în $whatsNewVersion',
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenSize.width * 0.92,
              maxHeight: screenSize.height * 0.84,
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SelectableText(
                        latestText,
                        textAlign: TextAlign.start,
                      ),
                    ),
                    if (hasOlderEntries) ...[
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Versiuni anterioare',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          height: 380,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Theme.of(ctx).dividerColor),
                              bottom: BorderSide(color: Theme.of(ctx).dividerColor),
                            ),
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                olderText,
                                textAlign: TextAlign.start,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Închide'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> maybeShowWhatsNewDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final shownVersion = prefs.getString(whatsNewShownVersionKey);

  // Instalare curată: memorăm versiunea curentă, dar nu afișăm dialogul.
  if (shownVersion == null) {
    await prefs.setString(whatsNewShownVersionKey, whatsNewVersion);
    return;
  }

  if (shownVersion == whatsNewVersion) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  await showDialogWhatsNew(context);

  await prefs.setString(whatsNewShownVersionKey, whatsNewVersion);
}