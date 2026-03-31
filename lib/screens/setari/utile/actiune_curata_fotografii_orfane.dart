// /lib/screens/setari/utile/actiune_curata_fotografii_orfane.dart

import 'package:flutter/material.dart';

import '../../../services/advanced_photo_cleanup_service.dart';

Future<void> showCleanupOrphanPhotosDialog(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Curățare fisiere orfane'),
      content: const Text(
        'Vor fi șterse doar fotografiile din memoria internă a aplicației care nu mai sunt folosite de niciun segment salvat. Continui?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Curăță'),
        ),
      ],
    ),
  );

  if (confirm != true || !context.mounted) {
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final result = await AdvancedPhotoCleanupService.cleanupOrphanAdvancedPhotoFiles();

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();

      final message = result.deletedFilesCount == 0
          ? 'Nu au fost găsite fisiere orfane. Verificate: ${result.existingFilesCount}.'
          : 'Au fost șterse ${result.deletedFilesCount} fisiere orfane din ${result.existingFilesCount} găsite.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Curățarea fisierelor orfane a eșuat.'),
        ),
      );
    }
  }
}