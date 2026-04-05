// /lib/screens/setari/actiune_restore_aplicatie.dart

// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saf/saf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:restart_app/restart_app.dart'; // pentru restart real al aplicației

import '../../services/advanced_photo_cleanup_service.dart';
import '../../services/recalculator.dart';
import '../../services/report_storage_v2.dart';
import '../../utils/holidays.dart';
import 'norma_lunara.dart';

const String kBackupSignaturePrimary = 'foaie_prestatii_mvp::backup';
const String kBackupSignatureLegacyV1 = 'foaie_prestatii_mvp::backup::v1';
const int kSchemaMinSupported = 1;
const int kSchemaMaxSupported = 1;

const String kPrefsLastBackupDirKey = 'foaie_prestatii_last_backup_dir';

Future<void> showDialogRestore(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);

  // Determină directorul inițial pentru restore:
  // 1) încearcă ultimul director folosit la backup (salvat în SharedPreferences)
  // 2) dacă nu există, revine la directorul public implicit Download/Program_Mecanici/backup
  final prefs = await SharedPreferences.getInstance();
  final savedDirPath = prefs.getString(kPrefsLastBackupDirKey);

  String initialDirPath;
  if (savedDirPath != null && savedDirPath.isNotEmpty) {
    initialDirPath = savedDirPath;
  } else {
    initialDirPath = await _defaultPublicBackupDirPath();
  }

  final initialDir = Directory(initialDirPath);
  if (!await initialDir.exists()) {
    try {
      await initialDir.create(recursive: true);
    } catch (_) {}
  }

  String currentDirLabel = initialDirPath;

  List<File> backups = await _filterAndValidateFromIoDir(initialDirPath);

  String? chosenPath = backups.isNotEmpty ? backups.first.path : null;
  bool selAll = false;
  bool selHolidays = false;
  bool selServices = false;
  bool selMonthlyNorms = false;
  bool selMechanicName = false;

  bool hasHolidays = false;
  bool hasServices = false;
  bool hasMonthlyNorms = false;
  bool hasMechanicName = false;

  if (chosenPath != null) {
    try {
      final text = await File(chosenPath).readAsString();
      final Map<String, dynamic> data = json.decode(text) as Map<String, dynamic>;
      hasHolidays = data.containsKey('legal_holidays_v1');
      hasServices =
          data.containsKey(ReportStorageV2.boxName) || data.containsKey(ReportStorageV2.metaBoxName);
      hasMonthlyNorms = data.containsKey(kMonthlyNormBox);
      if (data.containsKey('shared_preferences') && data['shared_preferences'] is Map) {
        final sp = Map<String, dynamic>.from(data['shared_preferences'] as Map);
        hasMechanicName = sp.containsKey('mechanic_name');
      }
      selHolidays = hasHolidays;
      selServices = hasServices;
      selMonthlyNorms = hasMonthlyNorms;
      selMechanicName = hasMechanicName;
      selAll = (hasHolidays ? selHolidays : true) &&
          (hasServices ? selServices : true) &&
          (hasMonthlyNorms ? selMonthlyNorms : true) &&
          (hasMechanicName ? selMechanicName : true);
    } catch (_) {
      hasHolidays = false;
      hasServices = false;
      hasMonthlyNorms = false;
      hasMechanicName = false;
      selHolidays = false;
      selServices = false;
      selMonthlyNorms = false;
      selMechanicName = false;
      selAll = false;
    }
  }

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        Future<void> updateSelectionFromBackupPath(String? path) async {
          if (path == null) {
            hasHolidays = false;
            hasServices = false;
            hasMonthlyNorms = false;
            hasMechanicName = false;
            selHolidays = false;
            selServices = false;
            selMonthlyNorms = false;
            selMechanicName = false;
            selAll = false;
            if (!ctx.mounted) return;
            setState(() {});
            return;
          }
          try {
            final text = await File(path).readAsString();
            final Map<String, dynamic> data = json.decode(text) as Map<String, dynamic>;
            hasHolidays = data.containsKey('legal_holidays_v1');
            hasServices =
                data.containsKey(ReportStorageV2.boxName) || data.containsKey(ReportStorageV2.metaBoxName);
            hasMonthlyNorms = data.containsKey(kMonthlyNormBox);
            hasMechanicName = false;
            if (data.containsKey('shared_preferences') && data['shared_preferences'] is Map) {
              final sp = Map<String, dynamic>.from(data['shared_preferences'] as Map);
              hasMechanicName = sp.containsKey('mechanic_name');
            }
            selHolidays = hasHolidays;
            selServices = hasServices;
            selMonthlyNorms = hasMonthlyNorms;
            selMechanicName = hasMechanicName;
            selAll = (hasHolidays ? selHolidays : true) &&
                (hasServices ? selServices : true) &&
                (hasMonthlyNorms ? selMonthlyNorms : true) &&
                (hasMechanicName ? selMechanicName : true);
          } catch (_) {
            hasHolidays = false;
            hasServices = false;
            hasMonthlyNorms = false;
            hasMechanicName = false;
            selHolidays = false;
            selServices = false;
            selMonthlyNorms = false;
            selMechanicName = false;
            selAll = false;
          }
          if (!ctx.mounted) return;
          setState(() {});
        }

        Future<void> pickDirectoryWithSaf() async {
          // Alege un director folosind SAF (nu FilePicker), ca să putem accesa și folderele vechi
          final saf = Saf('~/backup_restore');
          final granted = await saf.getDirectoryPermission(isDynamic: true);
          if (granted != true) {
            return;
          }
          try {
            await saf.cache();
            final List<String> paths = (await saf.getCachedFilesPath()) ?? <String>[];
            final List<File> newBackups = await _filterAndValidateFromPaths(paths);

            backups
              ..clear()
              ..addAll(newBackups);

            if (backups.isNotEmpty) {
              chosenPath = backups.first.path;
              try {
                currentDirLabel = File(backups.first.path).parent.path;
              } catch (_) {
                currentDirLabel = 'Folder selectat prin SAF';
              }
            } else {
              chosenPath = null;
              currentDirLabel = 'Folder selectat prin SAF (nu are fișiere .json valide)';
            }

            await updateSelectionFromBackupPath(chosenPath);
            if (!ctx.mounted) return;
            setState(() {});
          } catch (_) {
            backups = <File>[];
            chosenPath = null;
            await updateSelectionFromBackupPath(chosenPath);
            if (!ctx.mounted) return;
            setState(() {});
            messenger.showSnackBar(
              const SnackBar(content: Text('Nu am putut citi fișierele din folderul ales (SAF).')),
            );
          }
        }

        return AlertDialog(
          title: const Text('Restore date'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Director backup'),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('Director backup (SAF)'),
                  subtitle: Text(
                    currentDirLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  trailing: const Icon(Icons.edit_location_alt_outlined),
                  onTap: pickDirectoryWithSaf,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Implicit: ultimul director unde s-a salvat backup-ul. Poți alege alt folder public folosind SAF.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Fișiere backup disponibile în directorul curent:'),
                const SizedBox(height: 8),
                if (backups.isEmpty)
                  const Text(
                    'Nu am găsit niciun fișier de backup în acest director.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  )
                else
                  SizedBox(
                    height: 220,
                    width: 420,
                    child: ListView.builder(
                      itemCount: backups.length,
                      itemBuilder: (_, i) {
                        final f = backups[i];
                        final isSel = f.path == chosenPath;
                        return ListTile(
                          dense: true,
                          leading: Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off),
                          title: Text(
                            f.uri.pathSegments.last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            f.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          onTap: () async {
                            if (!ctx.mounted) return;
                            setState(() => chosenPath = f.path);
                            await updateSelectionFromBackupPath(chosenPath);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Ce vrei să restaurezi?', style: TextStyle(fontWeight: FontWeight.bold)),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selAll,
                  onChanged: (v) {
                    selAll = v ?? false;
                    if (selAll) {
                      selHolidays = hasHolidays;
                      selServices = hasServices;
                      selMonthlyNorms = hasMonthlyNorms;
                      selMechanicName = hasMechanicName;
                    } else {
                      selHolidays = false;
                      selServices = false;
                      selMonthlyNorms = false;
                      selMechanicName = false;
                    }
                    setState(() {});
                  },
                  title: const Text('Selectează tot'),
                ),
                const Divider(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selHolidays,
                  onChanged: hasHolidays
                      ? (v) {
                    selHolidays = v ?? false;
                    selAll = (!hasHolidays || selHolidays) &&
                        (!hasServices || selServices) &&
                        (!hasMonthlyNorms || selMonthlyNorms) &&
                        (!hasMechanicName || selMechanicName);
                    setState(() {});
                  }
                      : null,
                  title: const Text('Zile festive'),
                  secondary: const Icon(Icons.calendar_month),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selServices,
                  onChanged: hasServices
                      ? (v) {
                    selServices = v ?? false;
                    selAll = (!hasHolidays || selHolidays) &&
                        (!hasServices || selServices) &&
                        (!hasMonthlyNorms || selMonthlyNorms) &&
                        (!hasMechanicName || selMechanicName);
                    setState(() {});
                  }
                      : null,
                  title: const Text('Servicii salvate'),
                  secondary: const Icon(Icons.train_outlined),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selMonthlyNorms,
                  onChanged: hasMonthlyNorms
                      ? (v) {
                    selMonthlyNorms = v ?? false;
                    selAll = (!hasHolidays || selHolidays) &&
                        (!hasServices || selServices) &&
                        (!hasMonthlyNorms || selMonthlyNorms) &&
                        (!hasMechanicName || selMechanicName);
                    setState(() {});
                  }
                      : null,
                  title: const Text('Normă lunară'),
                  secondary: const Icon(Icons.schedule),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selMechanicName,
                  onChanged: hasMechanicName
                      ? (v) {
                    selMechanicName = v ?? false;
                    selAll = (!hasHolidays || selHolidays) &&
                        (!hasServices || selServices) &&
                        (!hasMonthlyNorms || selMonthlyNorms) &&
                        (!hasMechanicName || selMechanicName);
                    setState(() {});
                  }
                      : null,
                  title: const Text('Numele mecanicului'),
                  secondary: const Icon(Icons.badge_outlined),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Atenție: categoriile selectate vor ÎNLOCUI datele existente.',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Anulează')),
            FilledButton.icon(
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('Restaurează'),
              onPressed: backups.isEmpty || chosenPath == null
                  ? null
                  : () async {
                try {
                  if (!(selHolidays || selServices || selMonthlyNorms || selMechanicName)) {
                    throw 'Selectează cel puțin o categorie pentru restore.';
                  }
                  final hasData = await _hasExistingData();
                  if (hasData) {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      barrierDismissible: true,
                      builder: (c) => AlertDialog(
                        title: const Text('Confirmă restaurarea'),
                        content: const Text(
                          'Datele existente vor fi înlocuite pentru categoriile selectate. Continui?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(c).pop(false),
                            child: const Text('Anulează'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(c).pop(true),
                            child: const Text('Continuă restore'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                  }

                  final restored = await _performRestore(
                    File(chosenPath!),
                    restoreHolidays: selHolidays,
                    restoreServices: selServices,
                    restoreMonthlyNorms: selMonthlyNorms,
                    restoreMechanicName: selMechanicName,
                  );

                  if (ctx.mounted) Navigator.of(ctx).pop();

                  if (!context.mounted) return;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Restore reușit'),
                      content: Text(
                        'Datele au fost restaurate din:\n${restored.path}\n\nAplicația se va reporni acum.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(c).pop(true),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );

                  if (ok == true) {
                    await Future.delayed(const Duration(milliseconds: 120));
                    Restart.restartApp();
                  }
                } catch (e) {
                  ScaffoldMessenger.maybeOf(context)
                      ?.showSnackBar(SnackBar(content: Text('Eroare la restore: $e')));
                }
              },
            ),
          ],
        );
      });
    },
  );
}

Future<String> _defaultPublicBackupDirPath() async {
  final dlDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
  String basePath;
  if (dlDirs != null && dlDirs.isNotEmpty) {
    final emu = dlDirs.firstWhere(
          (d) => d.path.contains('/storage/emulated/0/'),
      orElse: () => dlDirs.first,
    );
    basePath = emu.path;
  } else {
    basePath = '/storage/emulated/0/Download';
  }
  return '$basePath/Program_Mecanici/backup';
}

Future<List<File>> _filterAndValidateFromIoDir(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return <File>[];
  try {
    final entries = await dir.list().toList();
    final files = <File>[];
    for (final e in entries) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last.toLowerCase();
      if (!name.endsWith('.json')) continue;
      files.add(e);
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  } catch (_) {
    return <File>[];
  }
}

Future<List<File>> _filterAndValidateFromPaths(List<String> paths) async {
  final out = <File>[];
  for (final p in paths) {
    try {
      if (!p.toLowerCase().endsWith('.json')) continue;
      final f = File(p);
      if (!await f.exists()) continue;
      out.add(f);
    } catch (_) {}
  }
  out.sort((a, b) => b.path.compareTo(a.path));
  return out;
}

Future<bool> _hasExistingData() async {
  try {
    final box = await Hive.openBox(ReportStorageV2.boxName);
    if (box.isNotEmpty) return true;
  } catch (_) {}
  try {
    final meta = await Hive.openBox(ReportStorageV2.metaBoxName);
    if (meta.isNotEmpty) return true;
  } catch (_) {}
  try {
    final norm = await Hive.openBox(kMonthlyNormBox);
    final Map<String, dynamic> map =
    Map<String, dynamic>.from(norm.get(kMonthlyNormKey, defaultValue: const <String, dynamic>{}));
    final Map<String, dynamic> manual =
    Map<String, dynamic>.from(norm.get(kMonthlyNormManualKey, defaultValue: const <String, dynamic>{}));
    if (map.isNotEmpty || manual.isNotEmpty) return true;
  } catch (_) {}
  try {
    final holidays = await Hive.openBox('legal_holidays_v1');
    final List<dynamic> dates = List<dynamic>.from(
      holidays.get('dates', defaultValue: const <dynamic>[]) as List,
    );
    if (dates.isNotEmpty) return true;
  } catch (_) {}
  try {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('mechanic_name');
    if (name != null && name.trim().isNotEmpty) return true;
  } catch (_) {}
  return false;
}

Set<int> _extractYearsFromHolidayDates(List<String> dates) {
  final years = <int>{};
  for (final raw in dates) {
    final value = raw.trim();
    if (value.length < 10) continue;
    try {
      final d = DateTime.parse(value);
      years.add(d.year);
    } catch (_) {}
  }
  return years;
}

Set<String> _allMonthsForYears(Set<int> years) {
  final out = <String>{};
  for (final year in years) {
    final yy = year.toString().padLeft(4, '0');
    for (int month = 1; month <= 12; month++) {
      out.add('$yy-${month.toString().padLeft(2, '0')}');
    }
  }
  return out;
}

Future<void> _resetMonthlyNormsForMonths(Set<String> months) async {
  if (months.isEmpty) return;

  await loadLegalHolidaysFromDb();

  final box = await Hive.openBox(kMonthlyNormBox);
  final rawMap = box.get(kMonthlyNormKey, defaultValue: <String, dynamic>{});
  final rawManual = box.get(kMonthlyNormManualKey, defaultValue: <String, dynamic>{});

  final Map<String, double> stored = {
    for (final e in Map<String, dynamic>.from(rawMap).entries)
      e.key: (e.value is num ? (e.value as num).toDouble() : double.tryParse('${e.value}') ?? 0.0),
  };

  final Map<String, bool> manual = {
    for (final e in Map<String, dynamic>.from(rawManual).entries)
      e.key: e.value == true,
  };

  for (final ym in months) {
    if (ym.length < 7) continue;
    final year = int.tryParse(ym.substring(0, 4));
    final month = int.tryParse(ym.substring(5, 7));
    if (year == null || month == null) continue;

    final def = _defaultHoursForMonthUsingGlobalHolidays(year, month);
    stored[ym] = def;
    manual[ym] = false;
  }

  await box.put(kMonthlyNormKey, stored);
  await box.put(kMonthlyNormManualKey, manual);
}

double _defaultHoursForMonthUsingGlobalHolidays(int year, int month) {
  return _workingDaysInMonthUsingGlobalHolidays(year, month) * 8.0;
}

int _workingDaysInMonthUsingGlobalHolidays(int year, int month) {
  final DateTime end;
  if (month == 12) {
    end = DateTime(year + 1, 1, 1).subtract(const Duration(days: 1));
  } else {
    end = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
  }

  int count = 0;
  for (int day = 1; day <= end.day; day++) {
    final cur = DateTime(year, month, day);
    final weekday = cur.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      continue;
    }

    final d = DateTime(cur.year, cur.month, cur.day);
    if (kRomanianLegalHolidays.contains(d)) {
      continue;
    }

    count++;
  }

  return count;
}

Future<Map<String, String>> _restoreServicePhotosFromBackup(
    Map<String, dynamic> data,
    ) async {
  final restoredPhotoPaths = <String, String>{};

  if (!data.containsKey('services_photos') || data['services_photos'] is! Map) {
    return restoredPhotoPaths;
  }

  final appDir = await getApplicationDocumentsDirectory();
  final photosDir = Directory(
    '${appDir.path}/${AdvancedPhotoCleanupService.photosDirectoryName}',
  );

  if (!await photosDir.exists()) {
    await photosDir.create(recursive: true);
  }

  final photos = Map<String, dynamic>.from(data['services_photos'] as Map);

  for (final entry in photos.entries) {
    final oldPath = entry.key.trim();
    if (oldPath.isEmpty || entry.value is! Map) {
      continue;
    }

    final photoData = Map<String, dynamic>.from(entry.value as Map);
    final fileName = (photoData['fileName'] as String? ?? '').trim();
    final base64Data = (photoData['base64'] as String? ?? '').trim();

    if (fileName.isEmpty || base64Data.isEmpty) {
      continue;
    }

    final restoredPath = '${photosDir.path}/$fileName';
    await File(restoredPath).writeAsBytes(
      base64Decode(base64Data),
      flush: true,
    );

    restoredPhotoPaths[oldPath] = restoredPath;
  }

  return restoredPhotoPaths;
}

Map<String, dynamic> _rewriteServicePhotoPathsInDaySegments(
    Map<String, dynamic> byService,
    Map<String, String> restoredPhotoPaths,
    ) {
  final updatedByService = <String, dynamic>{};

  for (final entry in byService.entries) {
    final segmentsValue = entry.value;

    if (segmentsValue is! List) {
      updatedByService[entry.key] = entry.value;
      continue;
    }

    final updatedSegments = <Map<String, dynamic>>[];

    for (final segmentValue in segmentsValue) {
      if (segmentValue is! Map) {
        continue;
      }

      final segment = Map<String, dynamic>.from(segmentValue);
      final rawPhotoPaths = segment['advancedPhotoPaths'];

      if (rawPhotoPaths is List) {
        final updatedPhotoPaths = <String>[];

        for (final item in rawPhotoPaths) {
          final oldPath = item.toString().trim();
          if (oldPath.isEmpty) {
            continue;
          }

          final restoredPath = restoredPhotoPaths[oldPath];
          if (restoredPath != null && restoredPath.isNotEmpty) {
            updatedPhotoPaths.add(restoredPath);
          }
        }

        segment['advancedPhotoPaths'] = updatedPhotoPaths.isEmpty
            ? null
            : updatedPhotoPaths;
      }

      updatedSegments.add(segment);
    }

    updatedByService[entry.key] = updatedSegments;
  }

  return updatedByService;
}

Future<File> _performRestore(
    File file, {
      required bool restoreHolidays,
      required bool restoreServices,
      required bool restoreMonthlyNorms,
      required bool restoreMechanicName,
    }) async {
  final text = await file.readAsString();
  final Map<String, dynamic> data = json.decode(text) as Map<String, dynamic>;

  final sig = data['signature'];
  if (sig != kBackupSignaturePrimary && sig != kBackupSignatureLegacyV1) {
    throw 'Fișierul selectat nu este un backup al acestei aplicații.';
  }
  final schema = (data['schemaVersion'] is int) ? (data['schemaVersion'] as int) : 1;
  if (schema < kSchemaMinSupported || schema > kSchemaMaxSupported) {
    throw 'Schema backup incompatibilă.';
  }
  final affectedHolidayYears = <int>{};
  if (restoreHolidays && data.containsKey('legal_holidays_v1')) {
    final b = await Hive.openBox(kLegalHolidaysBox);

    final existingDates = List<String>.from(
      b.get(kLegalHolidaysKey, defaultValue: const <String>[]),
    );
    affectedHolidayYears.addAll(_extractYearsFromHolidayDates(existingDates));

    await b.clear();

    final v = data['legal_holidays_v1'] as Map<String, dynamic>;
    final dates = List<String>.from(v['dates'] ?? const <String>[]);
    affectedHolidayYears.addAll(_extractYearsFromHolidayDates(dates));

    await b.put(kLegalHolidaysKey, dates);
  }

  if (restoreServices) {
    final box = await Hive.openBox(ReportStorageV2.boxName);
    await box.clear();

    final meta = await Hive.openBox(ReportStorageV2.metaBoxName);
    await meta.clear();

    final monthlyTotals = await Hive.openBox('monthly_totals_v1');
    await monthlyTotals.clear();

    final monthlyOvertime = await Hive.openBox('monthly_overtime_v1');
    await monthlyOvertime.clear();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(
        '${appDir.path}/${AdvancedPhotoCleanupService.photosDirectoryName}',
      );
      if (await photosDir.exists()) {
        await photosDir.delete(recursive: true);
      }
    } catch (_) {}

    final hasServicesPhotos =
        data.containsKey('services_photos') && data['services_photos'] is Map;
    final restoredPhotoPaths = hasServicesPhotos
        ? await _restoreServicePhotosFromBackup(data)
        : <String, String>{};

    if (data.containsKey(ReportStorageV2.boxName)) {
      final Map<String, dynamic> daily = Map<String, dynamic>.from(data[ReportStorageV2.boxName] as Map);
      for (final entry in daily.entries) {
        if (hasServicesPhotos && entry.key.endsWith('#seg') && entry.value is Map) {
          final rewrittenByService = _rewriteServicePhotoPathsInDaySegments(
            Map<String, dynamic>.from(entry.value as Map),
            restoredPhotoPaths,
          );
          await box.put(entry.key, rewrittenByService);
        } else {
          await box.put(entry.key, entry.value);
        }
      }
    }

    if (data.containsKey(ReportStorageV2.metaBoxName)) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(data[ReportStorageV2.metaBoxName] as Map);
      for (final entry in m.entries) {
        await meta.put(entry.key, entry.value);
      }
    }
  }

  if (restoreMonthlyNorms && data.containsKey(kMonthlyNormBox)) {
    final b = await Hive.openBox(kMonthlyNormBox);
    await b.delete(kMonthlyNormKey);
    await b.delete(kMonthlyNormManualKey);

    final Map<String, dynamic> v = Map<String, dynamic>.from(data[kMonthlyNormBox] as Map);
    if (v.containsKey(kMonthlyNormKey)) {
      await b.put(kMonthlyNormKey, Map<String, dynamic>.from(v[kMonthlyNormKey] as Map));
    }
    if (v.containsKey(kMonthlyNormManualKey)) {
      await b.put(kMonthlyNormManualKey, Map<String, dynamic>.from(v[kMonthlyNormManualKey] as Map));
    }
  }

  if (restoreMechanicName && data.containsKey('shared_preferences')) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mechanic_name');

    final sp = Map<String, dynamic>.from(data['shared_preferences'] as Map);
    if (sp.containsKey('mechanic_name')) {
      await prefs.setString('mechanic_name', (sp['mechanic_name'] as String? ?? '').trim());
    }
  }

  if (restoreHolidays || restoreServices || restoreMonthlyNorms) {
    final monthsTouched = await Recalculator.listMonthsTouchedInDailyReports();

    if (restoreHolidays || restoreServices) {
      await Recalculator.recalcAllDailyTotalsUsingSegments(months: monthsTouched);
      await Recalculator.reaggregateAndWriteMonthlyTotals(months: monthsTouched);

      if (restoreHolidays && !restoreMonthlyNorms) {
        final monthsToResetNorms = _allMonthsForYears(affectedHolidayYears);
        await _resetMonthlyNormsForMonths(monthsToResetNorms);
      }

      await Recalculator.recalcMonthlyOvertimeForMonths(monthsTouched);
    } else {
      await Recalculator.recalcMonthlyOvertimeForMonths(monthsTouched);
    }
  }

  return file;
}
