// /lib/screens/setari/actiune_backup_aplicatie.dart

// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/report_storage_v2.dart';
import 'norma_lunara.dart';

const String kBackupSignaturePrimary = 'foaie_prestatii_mvp::backup';
const String kBackupSignatureLegacyV1 = 'foaie_prestatii_mvp::backup::v1';
const int kSchemaMinSupported = 1;
const int kSchemaMaxSupported = 1;

// Prefix cerut: bkp_prog_mec_
const String kBackupFilePrefix = 'bkp_prog_mec_';

const String kPrefsLastBackupDirKey = 'foaie_prestatii_last_backup_dir';

enum BackupDestinationType { downloads, customDirectory }

/// Dialog + logic pentru backup selectiv,
/// cu un singur selector pentru director (public) și posibilitatea de a seta numele fișierului.
Future<void> showDialogBackup(BuildContext context) async {
  bool selAll = true;
  bool selHolidays = true;
  bool selServices = true;
  bool selMonthlyNorms = true;
  bool selMechanicName = true;

  // Implicit: încearcă să folosească ultimul director folosit la backup (dacă există),
// altfel memoria internă -> Download/Program_Mecanici/backup
  final prefs = await SharedPreferences.getInstance();
  final savedDirPath = prefs.getString(kPrefsLastBackupDirKey);

  BackupDestinationType dest;
  String? customDirPath;
  if (savedDirPath != null && savedDirPath.isNotEmpty) {
    dest = BackupDestinationType.customDirectory;
    customDirPath = savedDirPath;
  } else {
    dest = BackupDestinationType.downloads;
    customDirPath = null;
  }

  Directory currentDir = await _resolveDestinationDir(dest, customDirPath: customDirPath);
  List<File> currentFiles = (await _listBackupFilesInDir(currentDir)).cast<File>();

  // Nume fișier: implicit generat automat FĂRĂ extensie, dar editabil
  final String suggestedNameNoExt = _suggestBackupFileNameNoExt();
  final TextEditingController fileNameCtrl = TextEditingController(text: suggestedNameNoExt);

  try {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Backup date'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Director backup (implicit: ultimul director folosit la backup):'),
                    const SizedBox(height: 8),

                    // === SELECTORUL DE DIRECTOR (UNUL SINGUR) ===
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder_outlined),
                      title: const Text('Salvează backup în'),
                      subtitle: Text(currentDir.path, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      trailing: const Icon(Icons.edit_location_alt_outlined),
                      onTap: () async {
                        final picked = await FilePicker.platform.getDirectoryPath();
                        if (picked != null) {
                          dest = BackupDestinationType.customDirectory;
                          customDirPath = picked;

                          // NU persistăm nimic în SharedPreferences (nu mai există „last used”).
                          currentDir = await _resolveDestinationDir(dest, customDirPath: customDirPath);
                          currentFiles = (await _listBackupFilesInDir(currentDir)).cast<File>();
                          if (!ctx.mounted) return;
                          setState(() {});
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text('Fișiere backup existente în directorul curent:'),
                    const SizedBox(height: 8),

                    // === LISTA DE FIȘIERE SUS ===
                    if (currentFiles.isEmpty)
                      const Text(
                        'Nu există încă backup-uri în acest director.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      )
                    else
                      SizedBox(
                        height: 200,
                        width: 420,
                        child: ListView.builder(
                          itemCount: currentFiles.length,
                          itemBuilder: (_, i) {
                            final f = currentFiles[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.description_outlined),
                              title: Text(f.uri.pathSegments.last, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(f.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                              onTap: null,
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

// === NUME FIȘIER (EDITABIL) — fără extensie! ===
                    TextField(
                      controller: fileNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nume fișier backup',
                        hintText: 'ex: bkp_prog_mec_03112025_1315',
                        prefixIcon: Icon(Icons.drive_file_rename_outline),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6.0),
                      child: Text(
                        'Extensia .json este adăugată automat. Dacă introduci o extensie, va fi ignorată.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selAll,
                      onChanged: (v) {
                        if (!ctx.mounted) return;
                        setState(() {
                          selAll = v ?? false;
                          selHolidays = selAll;
                          selServices = selAll;
                          selMonthlyNorms = selAll;
                          selMechanicName = selAll;
                        });
                      },
                      title: const Text('Selectează tot'),
                    ),
                    const Divider(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selHolidays,
                      onChanged: (v) {
                        if (!ctx.mounted) return;
                        setState(() {
                          selHolidays = v ?? false;
                          selAll = selHolidays && selServices && selMonthlyNorms && selMechanicName;
                        });
                      },
                      title: const Text('Zile festive'),
                      secondary: const Icon(Icons.calendar_month),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selServices,
                      onChanged: (v) {
                        setState(() {
                          selServices = v ?? false;
                          selAll = selHolidays && selServices && selMonthlyNorms && selMechanicName;
                        });
                      },
                      title: const Text('Servicii (toate lunile)'),
                      secondary: const Icon(Icons.train_outlined),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selMonthlyNorms,
                      onChanged: (v) {
                        setState(() {
                          selMonthlyNorms = v ?? false;
                          selAll = selHolidays && selServices && selMonthlyNorms && selMechanicName;
                        });
                      },
                      title: const Text('Normă lunară'),
                      secondary: const Icon(Icons.schedule),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selMechanicName,
                      onChanged: (v) {
                        setState(() {
                          selMechanicName = v ?? false;
                          selAll = selHolidays && selServices && selMonthlyNorms && selMechanicName;
                        });
                      },
                      title: const Text('Numele mecanicului'),
                      secondary: const Icon(Icons.badge_outlined),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Backup-ul salvează doar ce bifezi. Fișierul include o semnătură unică.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ]
                  ,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Anulează'),
                ),
                TextButton(
                  onPressed: () async {
                    // Ștergere în masă / selectivă (dialog separat)
                    await _showDialogDeleteBackups(
                      context,
                      destination: dest,
                      customDirPath: customDirPath,
                    );
                    // Refresh listă după ștergere
                    currentFiles = (await _listBackupFilesInDir(currentDir)).cast<File>();
                    if (ctx.mounted) (ctx as Element).markNeedsBuild();
                  },
                  child: const Text('Șterge backup'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Salvează backup'),
                  onPressed: () async {
                    try {
                      // Preluăm numele introdus FĂRĂ extensie (ignorăm ce e după ultimul punct)
                      String baseName = _stripExtension(_sanitizeFilename(fileNameCtrl.text.trim()));
                      if (baseName.isEmpty) {
                        baseName = suggestedNameNoExt;
                      }
                      final desiredName = '$baseName.json';

                      // Dacă fișierul există, cere confirmare overwrite
                      final candidate = File('${currentDir.path}/$desiredName');
                      if (await candidate.exists()) {
                        final overwrite = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Fișier existent'),
                            content: Text('„$desiredName” există deja. Vrei să îl suprascrii?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Nu')),
                              FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Da, suprascrie')),
                            ],
                          ),
                        );
                        if (overwrite != true) return;
                      }

                      final file = await _performBackup(
                        includeHolidays: selHolidays,
                        includeServices: selServices,
                        includeMonthlyNorms: selMonthlyNorms,
                        includeMechanicName: selMechanicName,
                        destination: dest,
                        customDirPath: customDirPath,
                        overrideFileName: desiredName,
                      );

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(kPrefsLastBackupDirKey, file.parent.path);

                      if (ctx.mounted) Navigator.of(ctx).pop();

                      await showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Backup reușit'),
                          content: Text('Fișierul a fost salvat la:\n${file.path}'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK')),
                          ],
                        ),
                      );
                    } catch (e) {
                      await showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Eroare la backup'),
                          content: Text(_friendlyFsError(e)),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK')),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    // FIX: Controller-ul e eliberat ÎN AFARA builder-ului, după ce dialogul s-a închis.
    fileNameCtrl.dispose();
  }
}

String _friendlyFsError(Object e) {
  final msg = e.toString();
  if (msg.contains('Permission denied') || msg.contains('EACCES')) {
    return 'Nu am permisiunea să scriu în acest director. Alege un director accesibil aplicației.';
  }
  if (msg.contains('Read-only file system') || msg.contains('EROFS')) {
    return 'Sursa de stocare este numai-citire. Schimbă pe memoria internă sau în „Descărcări”.';
  }
  if (msg.contains('OS Error') && msg.contains('No such file or directory')) {
    return 'Directorul nu există. Creează-l sau alege alt director.';
  }
  return msg;
}

// Numele PRESET — fără extensie.
// FORMAT: bkp_prog_mec_<dd><mm><yyyy>_<hh><min>
String _suggestBackupFileNameNoExt() {
  final ts = DateTime.now();
  final dd = ts.day.toString().padLeft(2, '0');
  final mm = ts.month.toString().padLeft(2, '0');
  final yyyy = ts.year.toString().padLeft(4, '0');
  final hh = ts.hour.toString().padLeft(2, '0');
  final min = ts.minute.toString().padLeft(2, '0');
  return 'bkp_prog_mec_$dd$mm${yyyy}_$hh$min';
}

String _sanitizeFilename(String name) {
  // Elimină separatori de cale și caractere potențial problematice
  var n = name.replaceAll(RegExp(r'[\\/]+'), '_');
  n = n.replaceAll(RegExp(r'[:*?"<>|]'), '_');
  n = n.trim();
  return n;
}

// Taie orice extensie (tot ce e după ultimul punct) — ca să nu salvezi alt format din greșeală.
String _stripExtension(String name) {
  final idx = name.lastIndexOf('.');
  if (idx <= 0) return name; // fie fără punct, fie punct pe prima poziție
  return name.substring(0, idx);
}

Future<Directory> _resolveDestinationDir(BackupDestinationType destination, {String? customDirPath}) async {
  switch (destination) {
    case BackupDestinationType.downloads:
    // Public: Internal storage/Download/Program_Mecanici/backup
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      Directory base;
      if (dirs != null && dirs.isNotEmpty) {
        // Preferă prima intrare (de regulă /storage/emulated/0/Download)
        base = dirs.first;
      } else {
        base = await getApplicationDocumentsDirectory(); // fallback
      }
      final d = Directory('${base.path}/Program_Mecanici/backup');
      if (!await d.exists()) {
        await d.create(recursive: true);
      }
      return d;
    case BackupDestinationType.customDirectory:
      if (customDirPath == null || customDirPath.isEmpty) {
        throw 'Nu ai ales un director personalizat.';
      }
      final d2 = Directory(customDirPath);
      if (!await d2.exists()) {
        await d2.create(recursive: true);
      }
      return d2;
  }
}

Future<List<FileSystemEntity>> _listBackupFilesInDir(Directory dir) async {
  if (!await dir.exists()) return [];
  final entries = await dir.list().toList();
  // Accept doar .json; prioritizăm fișierele cu prefix-ul aplicației
  final files = entries.whereType<File>().where((f) {
    final name = f.uri.pathSegments.last.toLowerCase();
    return name.endsWith('.json') && (name.startsWith(kBackupFilePrefix) || name.contains('.json'));
  }).toList();
  files.sort((a, b) => b.path.compareTo(a.path));
  return files;
}

Future<void> _showDialogDeleteBackups(BuildContext context, {required BackupDestinationType destination, String? customDirPath}) async {
  final dir = await _resolveDestinationDir(destination, customDirPath: customDirPath);
  List<File> files = (await _listBackupFilesInDir(dir)).cast<File>();
  final selected = <String>{};
  bool selAll = false;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Șterge backup'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (files.isEmpty)
                  const Text('Nu există fișiere de backup în directorul selectat.', style: TextStyle(color: Colors.black54)),
                if (files.isNotEmpty) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selAll,
                    onChanged: (v) {
                      if (!ctx.mounted) return;
                      setState(() {
                        selAll = v ?? false;
                        selected.clear();
                        if (selAll) {
                          for (final f in files) {
                            selected.add(f.path);
                          }
                        }
                      });
                    },
                    title: const Text('Selectează tot'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    child: ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (_, i) {
                        final f = files[i];
                        final isSel = selected.contains(f.path);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: isSel,
                          onChanged: (v) {
                            if (!ctx.mounted) return;
                            setState(() {
                              if (v == true) {
                                selected.add(f.path);
                              } else {
                                selected.remove(f.path);
                              }
                              selAll = selected.length == files.length && files.isNotEmpty;
                            });
                          },
                          title: Text(f.uri.pathSegments.last, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(f.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anulează'),
            ),
            if (files.isNotEmpty) ...[
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      title: const Text('Confirmă ștergerea'),
                      content: const Text('Această acțiune va șterge TOATE fișierele de backup din acest director. Continui?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Nu')),
                        FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Da, șterge tot')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    int count = 0;
                    for (final f in files) {
                      try { await f.delete(); count++; } catch (_) {}
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    await showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Ștergere efectuată'),
                        content: Text('Am șters $count fișiere.'),
                        actions: [ TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK')) ],
                      ),
                    );
                  }
                },
                child: const Text('Șterge tot'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Șterge selectate'),
                onPressed: selected.isEmpty ? null : () async {
                  final confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      title: const Text('Confirmă ștergerea'),
                      content: Text('Această acțiune va șterge ${selected.length} fișier(e) selectat(e). Continui?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Nu')),
                        FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Da, șterge')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    int count = 0;
                    for (final p in selected) {
                      try { await File(p).delete(); count++; } catch (_) {}
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    await showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Ștergere efectuată'),
                        content: Text('Am șters $count fișiere.'),
                        actions: [ TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK')) ],
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        );
      });
    },
  );
}

Future<File> _performBackup({
  required bool includeHolidays,
  required bool includeServices,
  required bool includeMonthlyNorms,
  required bool includeMechanicName,
  required BackupDestinationType destination,
  String? customDirPath,
  String? overrideFileName,
}) async {
  final Map<String, dynamic> out = {
    'signature': kBackupSignaturePrimary,
    'schemaVersion': 1,
    'appId': 'foaie_prestatii_mvp',
    'generatedAt': DateTime.now().toIso8601String(),
  };

  // 1) Zile festive
  if (includeHolidays) {
    final b = await Hive.openBox('legal_holidays_v1');
    final list = List<String>.from(b.get('dates', defaultValue: const <String>[]));
    out['legal_holidays_v1'] = {'dates': list};
  }

  // 2) Servicii
  if (includeServices) {
    final box = await Hive.openBox(ReportStorageV2.boxName);
    final Map<String, dynamic> daily = {};
    for (final k in box.keys) {
      daily['$k'] = box.get(k);
    }
    out[ReportStorageV2.boxName] = daily;

    final meta = await Hive.openBox(ReportStorageV2.metaBoxName);
    final Map<String, dynamic> serviceMeta = {};
    for (final k in meta.keys) {
      serviceMeta['$k'] = meta.get(k);
    }
    out[ReportStorageV2.metaBoxName] = serviceMeta;
  }

  // 3) Norme lunare
  if (includeMonthlyNorms) {
    final b = await Hive.openBox(kMonthlyNormBox);
    final map = Map<String, dynamic>.from(b.get(kMonthlyNormKey, defaultValue: const <String, dynamic>{}));
    final manual = Map<String, dynamic>.from(b.get(kMonthlyNormManualKey, defaultValue: const <String, dynamic>{}));
    out[kMonthlyNormBox] = {
      kMonthlyNormKey: map,
      kMonthlyNormManualKey: manual,
    };
  }

  // 4) SharedPreferences: numele mecanicului
  if (includeMechanicName) {
    final prefs = await SharedPreferences.getInstance();
    out['shared_preferences'] = {
      'mechanic_name': prefs.getString('mechanic_name'),
    };
  }

  final dir = await _resolveDestinationDir(destination, customDirPath: customDirPath);
  // overrideFileName deja include .json; dacă lipsește, îl formăm din numele preset fără extensie
  String fileName = (overrideFileName?.trim().isNotEmpty == true)
      ? overrideFileName!.trim()
      : '${_suggestBackupFileNameNoExt()}.json';

  // safety: curăță numele și forțează .json
  fileName = '${_stripExtension(_sanitizeFilename(fileName))}.json';

  final filePath = '${dir.path}/$fileName';

  final file = File(filePath);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(out), flush: true);
  return file;
}
