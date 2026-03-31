// /lib/screens/setari/actiune_resetare_aplicatie.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/report_storage_v2.dart';
import '../privacy_policy_consent_screen.dart';

/// Backwards-compat alias kept so existing calls keep working.
/// Old callers use [showConfirmResetApp]. New code can use [showResetConfirmDialog].
Future<void> showConfirmResetApp(BuildContext context) => showResetConfirmDialog(context);

/// Afișează dialogul de confirmare, apoi rulează resetarea completă a datelor
/// și repornește fluxul aplicației (navighează la ecranul de consimțământ Privacy Policy).
Future<void> showResetConfirmDialog(BuildContext context) async {
  final bool? firstOk = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmare resetare'),
      content: const Text(
        'Această acțiune șterge toate datele aplicației: servicii, totaluri, norme, setări. '
            'Ești sigur că vrei să continui?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Resetează'),
        ),
      ],
    ),
  );

  if (firstOk != true || !context.mounted) {
    return;
  }

  final bool? secondOk = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmare resetare'),
      content: const Text(
        'Ești sigur că dorești ștergerea tuturor datelor?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Nu'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Da'),
        ),
      ],
    ),
  );

  if (secondOk == true && context.mounted) {
    await _performFullReset(context);
  }
}

/// IMPORTANT:
/// - Evităm `Hive.deleteFromDisk()` în runtime; curățăm cu `clear()` box-urile cunoscute
///   și închidem redeschizând Hive pentru stabilitate.
/// - Curățăm și SharedPreferences.
/// - Apoi golim stiva și navigăm la ecranul de consimțământ Privacy Policy.
Future<void> _performFullReset(BuildContext context) async {
  // Ecran de progres modal, blocant.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // 1) Închidem Hive ca să nu existe boxuri deschise.
    try {
      await Hive.close();
    } catch (_) {}

    // 2) Re-deschidem și GOLIM explicit toate box-urile cunoscute.
    final List<String> boxesToClear = <String>[
      ReportStorageV2.boxName,
      ReportStorageV2.metaBoxName,
      'monthly_norms_v1',
      'monthly_totals_v1',
      'monthly_overtime_v1',
      'legal_holidays_v1',
    ];

    for (final name in boxesToClear) {
      try {
        final box = await Hive.openBox(name);
        await box.clear();
        await box.close();
      } catch (_) {
        // ignorăm errorile de deschidere/inexistență
      }
    }

    // 3) SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    // 4) Asigură-te că Hive nu mai are nimic deschis.
    try {
      await Hive.close();
    } catch (_) {}

    // 5) Feedback vizual
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset complet. Aplicația a fost curățată.')),
      );
    }

    // 6) Navigăm către ecranul de consimțământ Privacy Policy și golim stiva.
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const PrivacyPolicyConsentScreen(
            initialShowOnboarding: true,
          ),
        ),
            (_) => false,
      );
    }
  } finally {
    // Închidem spinner-ul dacă încă este pe ecran.
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route is! PopupRoute);
    }
  }
}
