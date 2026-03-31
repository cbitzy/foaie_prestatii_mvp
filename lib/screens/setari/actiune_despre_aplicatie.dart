// /lib/screens/setari/actiune_despre_aplicatie.dart

import 'package:flutter/material.dart';

import 'package:foaie_prestatii_mvp/privacy_policy_text.dart';
import 'package:foaie_prestatii_mvp/whats_new_text.dart';

import 'package:foaie_prestatii_mvp/screens/whats_new_dialog.dart';

import 'actiune_privacy_policy.dart';

void showDialogDespreAplicatie(BuildContext context, String appVersion) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final screenSize = MediaQuery.of(ctx).size;

      return AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.04,
          vertical: screenSize.height * 0.015,
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        title: Text(
          'Despre aplicație',
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
                  const Text('Program Prestatii Mecanic'),
                  const SizedBox(height: 4),
                  Text(
                    appVersion.isEmpty ? 'Versiune: —' : 'Versiune: $appVersion',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aplicație pt. calculul și evidența orelor prestate.',
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Ce este nou $whatsNewVersion'),
                    trailing: const Icon(Icons.new_releases_outlined),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        showDialogWhatsNew(context);
                      });
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Privacy Policy ($privacyPolicyVersion)'),
                    trailing: const Icon(Icons.privacy_tip_outlined),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        showDialogPrivacyPolicy(context);
                      });
                    },
                  ),
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
      );
    },
  );
}