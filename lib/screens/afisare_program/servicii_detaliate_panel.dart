// /lib/screens/afisare_program/servicii_detaliate_panel.dart

import 'package:flutter/material.dart';
import 'afisare_servicii.dart';
import 'serviciu_afisare_avansata_sheet.dart';

typedef MergeSlicesFn = List<Map<String, dynamic>> Function(List<Map<String, dynamic>> input);

/// Panou dedicat pentru afișarea serviciilor în fereastră separată (bottom sheet / full screen).
class ServiciiDetaliatePanel extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> services;
  final MergeSlicesFn mergeMidnightSlices;

  const ServiciiDetaliatePanel({
    super.key,
    required this.services,
    required this.mergeMidnightSlices,
  });

  @override
  State<ServiciiDetaliatePanel> createState() => _ServiciiDetaliatePanelState();
}

class _ServiciiDetaliatePanelState extends State<ServiciiDetaliatePanel> {
  String? advancedServiceTitle;

  void _openAdvancedService(String serviceTitle) {
    setState(() {
      advancedServiceTitle = serviceTitle;
    });
  }

  void _closeAdvancedService() {
    setState(() {
      advancedServiceTitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bară de titlu simplă pentru sheet
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.view_list),
                const SizedBox(width: 8),
                Text(
                  'Servicii detaliate',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Închide',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                AfisareServicii(
                  services: widget.services,
                  mergeMidnightSlices: widget.mergeMidnightSlices,
                  showAdvancedServiceAction: true,
                  onOpenAdvancedService: _openAdvancedService,
                ),
                if (advancedServiceTitle != null)
                  Positioned.fill(
                    child: ServiciuAfisareAvansataSheet(
                      serviceTitle: advancedServiceTitle!,
                      onClose: _closeAdvancedService,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}