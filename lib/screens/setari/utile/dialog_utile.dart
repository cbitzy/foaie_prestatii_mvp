// /lib/screens/setari/utile/dialog_utile.dart

import 'package:flutter/material.dart';

import 'actiune_curata_fotografii_orfane.dart';

Future<void> showDialogUtile(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    useRootNavigator: false,
    builder: (ctx) {
      final screenWidth = MediaQuery.of(ctx).size.width;
      final dialogWidth = screenWidth < 600 ? screenWidth * 0.90 : 420.0;

      return AlertDialog(
        title: const Text('Utile'),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Curăță fisiere orfane'),
                  trailing: const Icon(Icons.photo_library_outlined),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await showCleanupOrphanPhotosDialog(context);
                  },
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