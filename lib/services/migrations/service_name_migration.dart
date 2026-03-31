import 'package:hive_flutter/hive_flutter.dart';
import '../../screens/Adauga_modifica_serviciu/nume_serviciu.dart' show buildServiceNameFromSegments;

/// Migration that only updates names if they aren't in the current format.
/// - Recomputes the expected name and updates Meta only if it differs.
class ServiceNameMigration {
  static const String _metaBox = 'service_meta_v1';
  static const String _dataBox = 'daily_reports_v2';

  /// Run migration across all services. Returns number of updated entries.
  static Future<int> migrateAllIfNeeded() async {
    final data = await _openData();
    final meta = await _openMeta();

    // Collect all segments per serviceId.
    final Map<String, List<Map<String, dynamic>>> segsByService = {};

    for (final key in data.keys) {
      if (key is! String || !key.endsWith('#seg')) continue;
      final dayMapRaw = data.get(key);
      if (dayMapRaw is! Map) continue;

      final dayMap = Map<String, dynamic>.from(dayMapRaw);
      for (final entry in dayMap.entries) {
        final serviceId = entry.key;
        final segsRaw = entry.value;
        if (segsRaw is! List) continue;

        final segs = List<Map<String, dynamic>>.from(
          segsRaw.map((e) => Map<String, dynamic>.from(e as Map)),
        );

        segsByService.putIfAbsent(serviceId, () => <Map<String, dynamic>>[]).addAll(segs);
      }
    }

    int updated = 0;
    for (final e in segsByService.entries) {
      final serviceId = e.key;
      final computedName = buildServiceNameFromSegments(e.value);
      final prevMeta = Map<String, dynamic>.from(meta.get(serviceId) ?? const <String, dynamic>{});
      final prevName = (prevMeta['name'] as String?)?.trim() ?? '';

      if (prevName != computedName) {
        prevMeta['name'] = computedName;
        await meta.put(serviceId, prevMeta);
        updated++;
      }
    }
    return updated;
  }

  static Future<Box> _openData() async {
    if (!Hive.isBoxOpen(_dataBox)) {
      return await Hive.openBox(_dataBox);
    }
    return Hive.box(_dataBox);
  }

  static Future<Box> _openMeta() async {
    if (!Hive.isBoxOpen(_metaBox)) {
      return await Hive.openBox(_metaBox);
    }
    return Hive.box(_metaBox);
  }
}
