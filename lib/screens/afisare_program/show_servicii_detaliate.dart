// /lib/screens/afisare_program/show_servicii_detaliate.dart

import 'package:flutter/material.dart';
import 'servicii_detaliate_panel.dart';

typedef MergeSlicesFn = List<Map<String, dynamic>> Function(List<Map<String, dynamic>> input);

/// Deschide fereastra (bottom sheet) cu Servicii Detaliate.
Future<void> showServiciiDetaliateBottomSheet({
  required BuildContext context,
  required Map<String, List<Map<String, dynamic>>> services,
  required MergeSlicesFn mergeMidnightSlices,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final height = MediaQuery.of(ctx).size.height;
      return SizedBox(
        height: height * 0.9,
        child: ServiciiDetaliatePanel(
          services: services,
          mergeMidnightSlices: mergeMidnightSlices,
        ),
      );
    },
  );
}
