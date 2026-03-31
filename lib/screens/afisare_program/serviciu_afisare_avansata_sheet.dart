// /lib/screens/afisare_program/serviciu_afisare_avansata_sheet.dart

import 'package:flutter/material.dart';

class ServiciuAfisareAvansataSheet extends StatelessWidget {
  final String serviceTitle;
  final VoidCallback? onClose;

  const ServiciuAfisareAvansataSheet({
    super.key,
    required this.serviceTitle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        Theme.of(context).bottomSheetTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor;

    return Material(
      elevation: 12,
      color: backgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.view_list),
                const SizedBox(width: 8),
                Text(
                  'Afisare Avansata',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Închide',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(
                  serviceTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('ACEASTA ZONA ESTE IN LUCRU'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}