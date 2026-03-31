// /lib/screens/Adauga_modifica_serviciu/avansat/formular_odihna.dart

import 'package:flutter/material.dart';

class FormularOdihna extends StatelessWidget {
  final TextEditingController dormitorCtrl;
  final TextEditingController cameraCtrl;

  const FormularOdihna({
    super.key,
    required this.dormitorCtrl,
    required this.cameraCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: dormitorCtrl,
          decoration: const InputDecoration(
            labelText: 'Dormitor',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cameraCtrl,
          decoration: const InputDecoration(
            labelText: 'Camera',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}