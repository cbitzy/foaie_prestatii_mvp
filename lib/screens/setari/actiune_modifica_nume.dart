// /lib/screens/setari/actiune_modifica_nume.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> showDialogModificaNume(BuildContext context) async {
  // stocăm un context local înainte de primul await
  final ctx = context;
  final prefs = await SharedPreferences.getInstance();
  final initialName = prefs.getString('mechanic_name') ?? '';
  final controller = TextEditingController(text: initialName);

  final result = await showDialog<bool>(
    context: ctx, // folosim contextul stocat înainte de await
    builder: (ctxDialog) {
      return AlertDialog(
        title: const Text('Editare nume mecanic'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Nume mecanic',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctxDialog, false),
            child: const Text('Renunță'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                if (!ctxDialog.mounted) return;
                ScaffoldMessenger.of(ctxDialog).showSnackBar(
                  const SnackBar(content: Text('Numele nu poate fi gol.')),
                );
                return;
              }

              await prefs.setString('mechanic_name', newName);
              if (!ctxDialog.mounted) return;
              Navigator.of(ctxDialog).pop(true);
            },
            child: const Text('Salvează'),
          ),
        ],
      );
    },
  );

  // IMPORTANT: eliminăm condiția de cursă dintre închiderea dialogului și
  // reconstruirile următoare ale arborelui de widgeturi. Dispunem controllerul
  // după ce Flutter finalizează frame-ul curent.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
  });

  return result == true;
}
