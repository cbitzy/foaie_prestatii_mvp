// /lib/screens/setari/actiune_backup_restore_selector.dart

import 'package:flutter/material.dart';

import 'actiune_backup_aplicatie.dart';
import 'actiune_restore_aplicatie.dart';

/// Arată un mini-selector pentru Backup/Restore.
/// Folosește [parentContext] pentru SnackBar-uri vizibile și pentru a rămâne în dialogul de Setări.
Future<void> showDialogBackupOrRestore(BuildContext parentContext) async {
  await showDialog(
    context: parentContext,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Backup / Restore'),
        content: const Text('Ce vrei să faci?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(), // închide selectorul
            child: const Text('Anulează'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.settings_backup_restore),
            label: const Text('Restore'),
            onPressed: () async {
              Navigator.of(ctx).pop(); // închide selectorul
              await showDialogRestore(parentContext); // deschide dialogul de restore
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Backup'),
            onPressed: () async {
              Navigator.of(ctx).pop(); // închide selectorul
              await showDialogBackup(parentContext); // deschide dialogul de backup
            },
          ),
        ],
      );
    },
  );
}
