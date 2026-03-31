// report_storage_v2.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../screens/Adauga_modifica_serviciu/nume_serviciu.dart' show buildServiceNameFromSegments;

/// Box schema (`daily_reports_v2`):
///  - `YYYY-MM-DD#svc` : Map indexat de `serviceId` → `Map<String, int>` (metrics)
///  - `YYYY-MM-DD#seg` : Map indexat de `serviceId` → `List<Map<String, dynamic>>` (segments)
///
/// Metrics keys:
///  `trenTotalMin`, `trenDayMin`, `trenNightMin`, `trenFestDayMin`, `trenFestNightMin`,
///  `regieMin`, `odihnaMin`, `mvStatieMin`, `mvDepouMin`, `acarMin`, `revizorMin?`, `sefTuraMin?`, `alteMin`

class ReportStorageV2 {
  static const String metaBoxName = 'service_meta_v1'; // serviceId -> { 'name': String }
  static const String boxName = 'daily_reports_v2';

  static Future<Box> _open() async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  /// Idempotent write: replaces this `serviceId`'s metrics for a given day.
  static Future<void> writeDayForService(String dateKey,
      String serviceId,
      Map<String, int> metrics,) async {
    final box = await _open();
    final svcKey = '$dateKey#svc';
    final Map<String, dynamic> all =
    Map<String, dynamic>.from(box.get(svcKey) ?? <String, dynamic>{});
    all[serviceId] = Map<String, int>.from(metrics);
    await box.put(svcKey, all);
  }

  /// Idempotent write: replaces this `serviceId`'s segments list for a given day.
  static Future<void> writeDaySegmentsForService(String dateKey,
      String serviceId,
      List<Map<String, dynamic>> segments,) async {
    final box = await _open();
    final segKey = '$dateKey#seg';
    final Map<String, dynamic> all =
    Map<String, dynamic>.from(box.get(segKey) ?? <String, dynamic>{});
    all[serviceId] = segments;
    await box.put(segKey, all);

    // update service name meta from current segments
    final name = buildServiceNameFromSegments(segments);
    await setServiceName(serviceId, name);
  }

  /// Delete a single segment (exact match) from a given day/serviceId.
  static Future<bool> deleteDaySegment({
    required String dateKey, // 'YYYY-MM-DD'
    required String serviceId,
    required Map<String,
        dynamic> segmentToMatch, // {type, trainNo?, start, end}
  }) async {
    final box = await _open();
    final segKey = '$dateKey#seg';
    if (!box.containsKey(segKey)) return false;

    final Map<String, dynamic> byService =
    Map<String, dynamic>.from(box.get(segKey));
    if (!byService.containsKey(serviceId)) return false;

    final list = List<Map<String, dynamic>>.from(
      (byService[serviceId] as List).map((e) =>
      Map<String, dynamic>.from(e as Map)),
    );

    final before = list.length;
    list.removeWhere((e) =>
    e['type'] == segmentToMatch['type'] &&
        (e['trainNo'] ?? '') == (segmentToMatch['trainNo'] ?? '') &&
        e['start'] == segmentToMatch['start'] &&
        e['end'] == segmentToMatch['end']);

    final removed = list.length < before;
    if (removed) {
      if (list.isEmpty) {
        byService.remove(serviceId);
        if (byService.isEmpty) {
          await box.delete(segKey);
        } else {
          await box.put(segKey, byService);
        }
        await deleteServiceName(serviceId);
      } else {
        byService[serviceId] = list;
        await box.put(segKey, byService);
        final name = buildServiceNameFromSegments(list);
        await setServiceName(serviceId, name);
      }
    }
    return removed;
  }

  /// Update a single segment (exact match -> replace with `newSegment`).
  static Future<bool> updateDaySegment({
    required String dateKey, // 'YYYY-MM-DD'
    required String serviceId,
    required Map<String, dynamic> oldSegment,
    required Map<String, dynamic> newSegment, // {type, trainNo?, start, end}
  }) async {
    final box = await _open();
    final segKey = '$dateKey#seg';
    if (!box.containsKey(segKey)) return false;

    final Map<String, dynamic> byService =
    Map<String, dynamic>.from(box.get(segKey));
    if (!byService.containsKey(serviceId)) return false;

    final list = List<Map<String, dynamic>>.from(
      (byService[serviceId] as List).map((e) =>
      Map<String, dynamic>.from(e as Map)),
    );

    final idx = list.indexWhere((e) =>
    e['type'] == oldSegment['type'] &&
        (e['trainNo'] ?? '') == (oldSegment['trainNo'] ?? '') &&
        e['start'] == oldSegment['start'] &&
        e['end'] == oldSegment['end']);

    if (idx == -1) return false;

    list[idx] = Map<String, dynamic>.from(newSegment);
    byService[serviceId] = list;
    await box.put(segKey, byService);
    // refresh service name after update
    final name = buildServiceNameFromSegments(list);
    await setServiceName(serviceId, name);
    return true;
  }

  /// Aggregate a whole month by summing all `serviceId` contributions per day.
  static Future<Map<String, int>> getMonth(int year, int month) async {
    final box = await _open();
    final prefix = '${year.toString().padLeft(4, '0')}-${month
        .toString()
        .padLeft(2, '0')}';
    final result = <String, int>{};

    for (final key in box.keys) {
      if (key is String && key.startsWith(prefix) && key.endsWith('#svc')) {
        final Map<String, dynamic> dayServices = Map<String, dynamic>.from(
            box.get(key));
        for (final svc in dayServices.values) {
          final m = Map<String, int>.from(svc);
          for (final e in m.entries) {
            result[e.key] = (result[e.key] ?? 0) + e.value;
          }
        }
      }
    }
    return result;
  }

  /// List per-day totals for a month (sum over `serviceId`s for that day).
  static Future<Map<String, Map<String, int>>> listMonthDays(int year,
      int month) async {
    final box = await _open();
    final prefix = '${year.toString().padLeft(4, '0')}-${month
        .toString()
        .padLeft(2, '0')}';
    final out = <String, Map<String, int>>{};

    for (final key in box.keys) {
      if (key is String && key.startsWith(prefix) && key.endsWith('#svc')) {
        final dayKey = key.substring(0, 10);
        final Map<String, dynamic> dayServices = Map<String, dynamic>.from(
            box.get(key));
        final totals = <String, int>{};
        for (final svc in dayServices.values) {
          final m = Map<String, int>.from(svc);
          for (final e in m.entries) {
            totals[e.key] = (totals[e.key] ?? 0) + e.value;
          }
        }
        out[dayKey] = totals;
      }
    }
    return out;
  }

  /// For each day in the month, return the combined segments from all `serviceId`s sorted chronologically.
  static Future<Map<String, List<Map<String, dynamic>>>> listMonthDaySegments(
      int year, int month) async {
    final box = await _open();
    final prefix = '${year.toString().padLeft(4, '0')}-${month
        .toString()
        .padLeft(2, '0')}';
    final out = <String, List<Map<String, dynamic>>>{};

    for (final key in box.keys) {
      if (key is String && key.startsWith(prefix) && key.endsWith('#seg')) {
        final dayKey = key.substring(0, 10);
        final Map<String, dynamic> byService = Map<String, dynamic>.from(
            box.get(key));
        final combined = <Map<String, dynamic>>[];
        for (final list in byService.values) {
          final L = List<Map<String, dynamic>>.from(
              (list as List).map((e) => Map<String, dynamic>.from(e as Map)));
          combined.addAll(L);
        }
        combined.sort((a, b) =>
            DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])));
        out[dayKey] = combined;
      }
    }
    return out;
  }

  /// Flat list of all segments across the month, with their `serviceId` preserved.
  /// Each item: `{ 'serviceId': String, 'type': String, 'trainNo': String?, 'start': String, 'end': String }`
  static Future<List<Map<String, dynamic>>> listMonthSegmentsWithServiceIds(
      int year, int month) async {
    final box = await _open();
    final prefix = '${year.toString().padLeft(4, '0')}-${month
        .toString()
        .padLeft(2, '0')}';
    final out = <Map<String, dynamic>>[];

    for (final key in box.keys) {
      if (key is String && key.startsWith(prefix) && key.endsWith('#seg')) {
        final dayKey = key.substring(0, 10);
        final Map<String, dynamic> byService = Map<String, dynamic>.from(
            box.get(key));
        byService.forEach((serviceId, list) {
          final L = List<Map<String, dynamic>>.from(
              (list as List).map((e) => Map<String, dynamic>.from(e as Map)));
          for (final seg in L) {
            out.add({
              'serviceId': serviceId,
              'type': seg['type'],
              'trainNo': seg['trainNo'],
              'start': seg['start'],
              'end': seg['end'],
              '_dayKey': dayKey, // pentru update/delete rapid
            });
          }
        });
      }
    }

    out.sort((a, b) =>
        DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])));
    return out;
  }

  /// Toate segmentele unui serviceId, colectate din toate zilele (toate cheile 'YYYY-MM-DD#seg').
  static Future<List<Map<String, dynamic>>> listAllSegmentsForService(String serviceId) async {
    final box = await _open();
    final out = <Map<String, dynamic>>[];

    for (final key in box.keys) {
      if (key is! String) continue;
      if (!key.endsWith('#seg')) continue; // doar zilele cu segmente
      final Map<String, dynamic> byService = Map<String, dynamic>.from(box.get(key) ?? {});
      final list = byService[serviceId];
      if (list is List) {
        out.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    }

    out.sort((a, b) => DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])));
    return out;
  }

  /// Listează serviciile ancorate într-o lună canonică (yyyy-MM),
  /// aducând TOATE segmentele fiecărui serviciu.
  static Future<Map<String, List<Map<String, dynamic>>>> listServicesByCanonicalMonth(String yyyyMm) async {
    final meta = await _openMetaBox();
    final out = <String, List<Map<String, dynamic>>>{};

    for (final key in meta.keys) {
      if (key is! String) continue; // serviceId
      final v = meta.get(key);
      if (v is Map && (v['month'] as String?) == yyyyMm) {
        final segs = await listAllSegmentsForService(key);
        if (segs.isNotEmpty) {
          out[key] = segs;
        }
      }
    }

    return out;
  }

  /// Returnează toate serviciile (serviceId) din luna [year, month],
  /// cu segmentele lor combinate (ordonate cronologic).
  /// Map: `serviceId` -> `List<Map<String, dynamic>>` segmente
  static Future<
      Map<String, List<Map<String, dynamic>>>> listServicesForMonthWithSegments(
      int year, int month) async {
    final box = await _open();
    final prefix = '${year.toString().padLeft(4, '0')}-${month
        .toString()
        .padLeft(2, '0')}';
    final out = <String, List<Map<String, dynamic>>>{};

    for (final key in box.keys) {
      if (key is! String) continue;
      if (!key.startsWith(prefix) || !key.endsWith('#seg')) continue;

      final Map<String, dynamic> byService = Map<String, dynamic>.from(
          box.get(key));
      byService.forEach((serviceId, list) {
        final L = List<Map<String, dynamic>>.from(
          (list as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        out.putIfAbsent(serviceId, () => <Map<String, dynamic>>[]).addAll(L);
      });
    }

    // ordonează segmentele fiecărui serviceId
    out.updateAll((_, segs) {
      segs.sort((a, b) =>
          DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])));
      return segs;
    });
    return out;
  }

  static Future<Box> _openMetaBox() async => Hive.openBox(metaBoxName);

  static Future<void> setServiceName(String serviceId, String name) async {
    final b = await _openMetaBox();
    final prev = Map<String, dynamic>.from(b.get(serviceId) ?? const <String, dynamic>{});
    prev['name'] = name;
    await b.put(serviceId, prev);
  }

  static Future<String?> getServiceName(String serviceId) async {
    final b = await _openMetaBox();
    final v = b.get(serviceId);
    if (v is Map && v['name'] is String) return v['name'] as String;
    if (v is String) return v; // fallback foarte vechi
    return null;
  }

  static Future<void> deleteServiceName(String serviceId) async {
    // lăsăm cheia meta dacă are și alte câmpuri (ex: 'month')
    final b = await _openMetaBox();
    final prev = Map<String, dynamic>.from(b.get(serviceId) ?? const <String, dynamic>{});
    prev.remove('name');
    if (prev.isEmpty) {
      await b.delete(serviceId);
    } else {
      await b.put(serviceId, prev);
    }
  }

  /// setează / citește luna canonică (yyyy-MM) în același meta box
  static Future<void> setServiceMonth(String serviceId, String yyyyMm) async {
    final b = await _openMetaBox();
    final prev = Map<String, dynamic>.from(b.get(serviceId) ?? const <String, dynamic>{});
    prev['month'] = yyyyMm; // ex: '2025-01'
    await b.put(serviceId, prev);
  }

  static Future<String?> getServiceMonth(String serviceId) async {
    final b = await _openMetaBox();
    final v = b.get(serviceId);
    if (v is Map && v['month'] is String) return (v['month'] as String).trim();
    return null;
  }

  /// dacă vrei să ștergi TOT meta-ul (nume + lună canonică) pentru un service
  static Future<void> deleteServiceMeta(String serviceId) async {
    final b = await _openMetaBox();
    await b.delete(serviceId);
  }

  /// Șterge complet un serviceId din toate cheile (#seg și #svc).
  static Future<void> deleteServiceEverywhere(String serviceId) async {
    final box = await _open();
    final keys = box.keys.toList(growable: false);

    for (final k in keys) {
      if (k is! String) continue;
      if (!k.endsWith('#seg') && !k.endsWith('#svc')) continue;

      final Map<String, dynamic> byService =
      Map<String, dynamic>.from(box.get(k) ?? {});
      if (!byService.containsKey(serviceId)) continue;

      byService.remove(serviceId);
      if (byService.isEmpty) {
        await box.delete(k);
      } else {
        await box.put(k, byService);
      }
    }
    // fail-safe: dacă a rămas vreo cheie neatinsă, ne asigurăm că meta-name dispare
    await deleteServiceMeta(serviceId);
  }

}