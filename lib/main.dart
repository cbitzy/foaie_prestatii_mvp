// /lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

import 'package:foaie_prestatii_mvp/in_app_update_helper.dart';
import 'package:foaie_prestatii_mvp/privacy_policy_text.dart';
import 'package:foaie_prestatii_mvp/screens/whats_new_dialog.dart';

import 'package:foaie_prestatii_mvp/screens/home_screen/index.dart';
import 'package:foaie_prestatii_mvp/screens/privacy_policy_consent_screen.dart';
import 'screens/onboarding_screen.dart';
import 'utils/holidays.dart';
import 'services/migrations/service_name_migration.dart';
import 'services/migrations/dst_march_2026_split_fix_migration.dart';
import 'services/recalculator.dart';

// Global navigator key to allow showing SnackBars right after app mounts
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const String kDidRunRegieWorkedMinutesRecalcV1 =
    'did_run_regie_worked_minutes_recalc_v1';
const String kInitialSetupStartedV1 = 'initial_setup_started_v1';
const String kInitialSetupCompletedV1 = 'initial_setup_completed_v1';
const String kDidRunDstMarch2026SplitFixV2 =
    'did_run_dst_march_2026_split_fix_v2';
const String kDstMarch2026SplitFixAttemptCountV2 =
    'dst_march_2026_split_fix_attempt_count_v2';
const int kDstMarch2026SplitFixMaxAttempts = 3;

const Duration kStartupUiStabilizationDelay = Duration(seconds: 2);

bool _shouldShowOnboarding(SharedPreferences prefs, String? name) {
  final hasName = name != null && name.trim().isNotEmpty;
  if (!hasName) {
    return true;
  }

  final setupStarted = prefs.getBool(kInitialSetupStartedV1) ?? false;
  final setupCompleted = prefs.getBool(kInitialSetupCompletedV1) ?? false;

  return setupStarted && !setupCompleted;
}

Future<DstMarch2026SplitFixRunResult> _runDstMarch2026SplitFixIfNeeded(
    SharedPreferences prefs,
    ) async {
  final didRun = prefs.getBool(kDidRunDstMarch2026SplitFixV2) ?? false;
  if (didRun) {
    return const DstMarch2026SplitFixRunResult.empty();
  }

  final attempts = prefs.getInt(kDstMarch2026SplitFixAttemptCountV2) ?? 0;
  if (attempts >= kDstMarch2026SplitFixMaxAttempts) {
    await prefs.setBool(kDidRunDstMarch2026SplitFixV2, true);
    return const DstMarch2026SplitFixRunResult.empty();
  }

  try {
    final result =
    await DstMarch2026SplitFixMigration.repairAffectedServices();

    final nextAttempts = attempts + 1;
    await prefs.setInt(
      kDstMarch2026SplitFixAttemptCountV2,
      nextAttempts,
    );

    if (result.repairedCount > 0 ||
        nextAttempts >= kDstMarch2026SplitFixMaxAttempts) {
      await prefs.setBool(kDidRunDstMarch2026SplitFixV2, true);
    }

    debugPrint(
      'Migrare split DST martie 2026: încercare $nextAttempts/$kDstMarch2026SplitFixMaxAttempts, reparate ${result.repairedCount} servicii.',
    );

    return result;
  } catch (e, st) {
    final nextAttempts = attempts + 1;
    await prefs.setInt(
      kDstMarch2026SplitFixAttemptCountV2,
      nextAttempts,
    );

    if (nextAttempts >= kDstMarch2026SplitFixMaxAttempts) {
      await prefs.setBool(kDidRunDstMarch2026SplitFixV2, true);
    }

    debugPrint(
      'Migrare split DST martie 2026: eroare la încercarea $nextAttempts/$kDstMarch2026SplitFixMaxAttempts: $e',
    );
    debugPrint('$st');

    return const DstMarch2026SplitFixRunResult.empty();
  }
}

Future<void> _showDstMarch2026SplitFixDialogIfNeeded(
    BuildContext context,
    DstMarch2026SplitFixRunResult result,
    ) async {
  if (result.repairedServices.isEmpty) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  final dtFmt = DateFormat('dd.MM.yyyy HH:mm');
  final details = result.repairedServices.map((item) {
    final safeName = item.serviceName.trim().isEmpty
        ? '(fără nume serviciu)'
        : item.serviceName.trim();

    return '$safeName\n${dtFmt.format(item.start)} → ${dtFmt.format(item.end)}';
  }).join('\n\n');

  final title = result.repairedCount == 1
      ? 'A fost reparat automat 1 serviciu'
      : 'Au fost reparate automat ${result.repairedCount} servicii';

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                'Am găsit servicii salvate greșit din cauza split-ului de la schimbarea orei și le-am refăcut automat.\n\n$details',
                textAlign: TextAlign.start,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showServiceNameMigrationSnackBarIfNeeded(
    BuildContext context,
    int updatedCount,
    ) async {
  if (updatedCount <= 0) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Au fost actualizate $updatedCount servicii la noul format pentru nume.',
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}

Future<void> _runStartupUiSequence({
  required BuildContext context,
  required DstMarch2026SplitFixRunResult dstMarch2026SplitFixResult,
  required int updatedServiceNamesCount,
}) async {
  if (!context.mounted) {
    return;
  }

  await Future<void>.delayed(kStartupUiStabilizationDelay);

  if (!context.mounted) {
    return;
  }

  // Prioritate 1: "Ce este nou"
  await maybeShowWhatsNewDialog(context);

  if (!context.mounted) {
    return;
  }

  // Prioritate 2: servicii reparate automat
  await _showDstMarch2026SplitFixDialogIfNeeded(
    context,
    dstMarch2026SplitFixResult,
  );

  if (!context.mounted) {
    return;
  }

  // Prioritate 3: actualizare Google Play
  await InAppUpdateHelper.checkAndPrompt(
    context: context,
    immediateIfAllowed: true,
  );

  if (!context.mounted) {
    return;
  }

  // Prioritate 4: mesaj informativ neblocant
  await _showServiceNameMigrationSnackBarIfNeeded(
    context,
    updatedServiceNamesCount,
  );
}
Future<void> _runRegieWorkedMinutesRecalcIfNeeded(
    SharedPreferences prefs,
    ) async {
  final didRun = prefs.getBool(kDidRunRegieWorkedMinutesRecalcV1) ?? false;
  if (didRun) {
    return;
  }

  try {
    final monthsTouched = await Recalculator.listMonthsTouchedInDailyReports();

    if (monthsTouched.isNotEmpty) {
      await Recalculator.recalcAllDailyTotalsUsingSegments(
        months: monthsTouched,
      );
      await Recalculator.reaggregateAndWriteMonthlyTotals(
        months: monthsTouched,
      );
      await Recalculator.recalcMonthlyOvertimeForMonths(monthsTouched);
    }

    await prefs.setBool(kDidRunRegieWorkedMinutesRecalcV1, true);
    debugPrint(
      'Migrare recalcul regie: finalizată pentru ${monthsTouched.length} luni.',
    );
  } catch (e, st) {
    debugPrint('Migrare recalcul regie: eroare la prima pornire: $e');
    debugPrint('$st');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive + storage
  await Hive.initFlutter();
  await loadLegalHolidaysFromDb();

  final prefs = await SharedPreferences.getInstance();
  final dstMarch2026SplitFixResult =
  await _runDstMarch2026SplitFixIfNeeded(prefs);
  await _runRegieWorkedMinutesRecalcIfNeeded(prefs);

  // Verifică și actualizează numele serviciilor doar dacă e nevoie
  final updatedCount = await ServiceNameMigration.migrateAllIfNeeded();
  debugPrint('Migrare nume servicii: actualizate $updatedCount înregistrări');

  // Locale română pentru DateFormat & widget-uri
  await initializeDateFormatting('ro_RO', null);
  Intl.defaultLocale = 'ro_RO';

  final name = prefs.getString('mechanic_name');
  final privacyAccepted =
      prefs.getBool(privacyPolicyAcceptedKey) ?? false;
  final privacyAcceptedVersion =
  prefs.getString(privacyPolicyAcceptedVersionKey);
  final privacyAcceptedForCurrentVersion =
      privacyAccepted && privacyAcceptedVersion == privacyPolicyVersion;

  final showOnboarding = _shouldShowOnboarding(prefs, name);

  runApp(
    Phoenix(
      child: MyApp(
        initialShowOnboarding: showOnboarding,
        initialPrivacyPolicyAccepted: privacyAcceptedForCurrentVersion,
      ),
    ),
  );

  // După montarea primei pagini rulăm toate ferestrele de startup
  // doar după stabilizarea aplicației și într-o ordine clară.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      return;
    }

    if (!privacyAcceptedForCurrentVersion) {
      return;
    }

    if (showOnboarding) {
      return;
    }

    await _runStartupUiSequence(
      context: ctx,
      dstMarch2026SplitFixResult: dstMarch2026SplitFixResult,
      updatedServiceNamesCount: updatedCount,
    );
  });
}

class MyApp extends StatelessWidget {
  final bool initialShowOnboarding;
  final bool initialPrivacyPolicyAccepted;
  const MyApp({
    super.key,
    required this.initialShowOnboarding,
    required this.initialPrivacyPolicyAccepted,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Prestatii Serviciu Mecanic',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
      ),

      // forțăm ro_RO în aplicație
      locale: const Locale('ro', 'RO'),
      supportedLocales: const [Locale('ro', 'RO')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: initialPrivacyPolicyAccepted
          ? (initialShowOnboarding ? const OnboardingScreen() : const HomeScreen())
          : PrivacyPolicyConsentScreen(initialShowOnboarding: initialShowOnboarding),
    );
  }
}
