// /lib/screens/setari/dialog_setari.dart

import 'package:flutter/material.dart';
import 'package:foaie_prestatii_mvp/in_app_update_helper.dart';

import 'actiune_modifica_nume.dart';
import 'actiune_despre_aplicatie.dart';
import 'sarbatori_legale.dart';
import 'norma_lunara.dart';
import 'actiune_resetare_aplicatie.dart';
import 'utile/dialog_utile.dart';
//import 'actiune_backup_aplicatie.dart';
import 'actiune_backup_restore_selector.dart';

Future<void> showDialogSetari(
    BuildContext context, {
      required String appVersion,
      required Future<void> Function() onNameChanged,
    }) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    useRootNavigator: false, // rămânem în același navigator
    builder: (ctx) {
      final screenWidth = MediaQuery.of(ctx).size.width;
      final dialogWidth = screenWidth < 600 ? screenWidth * 0.90 : 520.0;
      return AlertDialog(
        // Titlu cu icoane Backup + Reset în dreapta sus (cu spațiu între ele)
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Setări'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Backup date',
                  icon: const Icon(Icons.backup_outlined),
                  onPressed: () async {
                    await showDialogBackupOrRestore(context);
                  },
                ),
                const SizedBox(width: 8), // puțin spațiu între butoane
                IconButton(
                  tooltip: 'Resetare aplicație',
                  icon: const Icon(Icons.restore, color: Colors.redAccent),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await showConfirmResetApp(context);
                  },
                ),
              ],
            ),
          ],
        ),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              ListTile(
                title: const Text('Modifică nume'),
                trailing: const Icon(Icons.person_outline),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final changed = await showDialogModificaNume(context);
                  if (changed == true) {
                    await onNameChanged();
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Zile festive'),
                trailing: const Icon(Icons.calendar_month),
                onTap: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(builder: (_) => const SarbatoriLegaleScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Normă lunară'),
                trailing: const Icon(Icons.schedule),
                onTap: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(builder: (_) => const NormaLunaraScreen()),
                  );
                },
              ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Utile'),
                    trailing: const Icon(Icons.build_outlined),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await showDialogUtile(context);
                    },
                  ),

                  // Linie de separare suplimentară pentru evidențiere
              const SizedBox(height: 8),
              const Divider(thickness: 1, height: 10),
              ListTile(
                title: Text(
                  'Despre aplicație',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(ctx).textTheme.bodyMedium?.color
                        ?.withAlpha((0.7 * 255).round()),
                  ),
                ),
                trailing: const Icon(Icons.info_outline, color: Colors.grey),
                onTap: () {
                  showDialogDespreAplicatie(ctx, appVersion);
                },
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    await InAppUpdateHelper.checkAndPrompt(
                      context: ctx,
                      immediateIfAllowed: true,
                      showNoUpdateMessage: true,
                    );
                  },
                  child: const Text(
                    'Check for Update',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),

                ],
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
