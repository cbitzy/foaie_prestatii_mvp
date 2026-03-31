// /lib/screens/screens/home_screen/sectiune_butoane.dart

import 'package:flutter/material.dart';

class SectiuneButoane extends StatelessWidget {
  final VoidCallback onOpenAfisareProgram;
  final Future<void> Function() onOpenAdaugaModifica;

  const SectiuneButoane({
    super.key,
    required this.onOpenAfisareProgram,
    required this.onOpenAdaugaModifica,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('Afișare Program'),
            onPressed: onOpenAfisareProgram,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Adaugă/Modifică Serviciu'),
            onPressed: () async {
              await onOpenAdaugaModifica();
            },
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.beach_access),
            label: const Text('Adaugă/Modifică Concediu'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcția pentru concediu nu a fost încă implementată în aplicație.'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
