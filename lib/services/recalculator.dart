
import 'dart:async';
import 'package:hive/hive.dart';

import '../calcule_ore/api.dart'; // exports: totalsForSlice, emptyTotals, kRomanianLegalHolidays, loadLegalHolidaysFromDb

/// Recalculator: batch utilities for (re)aggregating monthly totals and computing overtime.
///
/// Boxes used:
/// - 'daily_reports_v2'    : existing, stores 'YYYY-MM-DD#seg' and 'YYYY-MM-DD#svc' per serviceId
/// - 'monthly_norms_v1'    : existing, stores per 'YYYY-MM' -> double hours (editable by user)
/// - 'monthly_totals_v1'   : NEW, stores 'YYYY-MM#totals' -> Map_String,int (minutes), snapshot
/// - 'monthly_overtime_v1' : NEW, stores 'YYYY-MM#overtime' -> int (minutes)
///
/// Notes:
/// - Overtime is stored as raw minutes (no rounding). UI can render as "XXh YYmin".
/// - "Worked minutes" = sum of all minutes EXCEPT 'odihnaMin'.
class Recalculator {
  // ---------------------- Public API ----------------------

  /// Returns the set of months (YYYY-MM) that appear in daily_reports_v2 keys (#seg / #svc).
  static Future<Set<String>> listMonthsTouchedInDailyReports() async {
    final box = await _openBox('daily_reports_v2');
    final months = <String>{};
    for (final dynamic k in box.keys) {
      if (k is! String) continue;
      final idx = k.indexOf('#');
      if (idx <= 0) continue;
      final datePart = k.substring(0, idx); // YYYY-MM-DD
      if (datePart.length < 7) continue;
      final ym = datePart.substring(0, 7); // YYYY-MM
      months.add(ym);
    }
    return months;
  }

  /// Re-aggregates monthly totals from daily '#svc' entries and writes a snapshot to monthly_totals_v1.
  /// If [months] is null, aggregates for ALL months found in daily_reports_v2.
  static Future<void> reaggregateAndWriteMonthlyTotals({Set<String>? months}) async {
    final monthsToDo = months ?? await listMonthsTouchedInDailyReports();
    for (final ym in monthsToDo) {
      final totals = await aggregateMonthTotals(ym);
      await writeMonthlyTotals(ym, totals);
    }
  }

  /// Aggregates all daily '#svc' totals in a given month (YYYY-MM).
  /// Returns a Map_String,int with minute counters per metric.
  static Future<Map<String, int>> aggregateMonthTotals(String yyyyMm) async {
    final box = await _openBox('daily_reports_v2');
    final out = <String, int>{};
    for (final dynamic k in box.keys) {
      if (k is! String) continue;
      if (!k.endsWith('#svc')) continue;
      final day = _extractDayFromKey(k);
      if (day == null) continue;
      if (!day.startsWith('$yyyyMm-')) continue;
      final dynamic value = box.get(k);
      if (value is Map) {
        // value can be:
        //  A) flat map metric -> minutes
        //  B) map serviceId -> (map metric -> minutes)
        _accumulateTotals(out, value);
      }
    }
    return out;
  }

  /// Writes monthly totals snapshot to 'monthly_totals_v1' under key 'YYYY-MM#totals'.
  static Future<void> writeMonthlyTotals(String yyyyMm, Map<String, int> totals) async {
    final mbox = await _openBox('monthly_totals_v1');
    await mbox.put('$yyyyMm#totals', Map<String, int>.from(totals));
  }

  /// Recalculates monthly overtime for the given months (YYYY-MM) and persists to 'monthly_overtime_v1'.
  /// Overtime (minutes) = max(0, workedMin - normMin) (no rounding).
  /// workedMin = sum(monthly totals except 'odihnaMin', fără defalcările trenDayMin/trenNightMin/trenFest*).
  /// normMin   = norma manuală salvată sau, pentru lunile automate, norma recalculată din calendarul curent.
  static Future<void> recalcMonthlyOvertimeForMonths(Set<String> months) async {
    final normsBox = await _openBox('monthly_norms_v1');
    final monthlyTotalsBox = await _openBox('monthly_totals_v1');
    final overtimeBox = await _openBox('monthly_overtime_v1');

    final dynamic rawMap = normsBox.get('map', defaultValue: <String, dynamic>{});
    final dynamic rawManual = normsBox.get('manual_flags', defaultValue: <String, dynamic>{});

    final Map<String, dynamic> map =
    rawMap is Map ? Map<String, dynamic>.from(rawMap) : <String, dynamic>{};
    final Map<String, dynamic> manualMap =
    rawManual is Map ? Map<String, dynamic>.from(rawManual) : <String, dynamic>{};

    await loadLegalHolidaysFromDb();

    for (final ym in months) {
      Map<String, int>? totals =
      (monthlyTotalsBox.get('$ym#totals') as Map?)?.cast<String, int>();
      totals ??= await aggregateMonthTotals(ym);

      final workedMin = _sumWorkedMinutes(totals);

      final dynamic manualRaw = manualMap[ym];
      final bool isManual = manualRaw == true || manualRaw.toString().toLowerCase() == 'true';

      double normHours = 0.0;

      if (isManual) {
        final dynamic h = map[ym] ?? normsBox.get(ym);
        normHours = _asDouble(h) ?? 0.0;
      } else {
        final int? year = int.tryParse(ym.substring(0, 4));
        final int? month = int.tryParse(ym.substring(5, 7));

        if (year != null && month != null) {
          int workingDays = 0;
          final end = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

          for (int day = 1; day <= end.day; day++) {
            final cur = DateTime(year, month, day);
            final weekday = cur.weekday;
            final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;
            final isHoliday = kRomanianLegalHolidays.contains(
              DateTime(cur.year, cur.month, cur.day),
            );
            if (!isWeekend && !isHoliday) {
              workingDays++;
            }
          }

          normHours = workingDays * 8.0;
        }
      }

      final double normMinutesExact = normHours * 60.0;
      final int normMin = normMinutesExact.floor();

      final int diffMin = workedMin - normMin;
      final int overtimeMin = (diffMin > 0) ? diffMin : 0;
      await overtimeBox.put('$ym#overtime', overtimeMin);
    }
  }

  /// Recompute all daily '#svc' totals from '#seg' using the CURRENT ruleset (holidays, etc.).
  /// If [months] is provided, only days in those YYYY-MM are processed.
  static Future<void> recalcAllDailyTotalsUsingSegments({Set<String>? months}) async {
    // Ensure holidays set is up to date
    await loadLegalHolidaysFromDb();

    final box = await _openBox('daily_reports_v2');
    final Set<String>? monthsFilter = months;

    for (final dynamic k in box.keys) {
      if (k is! String) continue;
      if (!k.endsWith('#seg')) continue;

      final String? day = _extractDayFromKey(k);
      if (day == null) continue;
      final String ym = day.substring(0, 7);

      if (monthsFilter != null && !monthsFilter.contains(ym)) {
        continue;
      }

      // Read segments for this day indexed by serviceId
      final dynamic segValue = box.get(k);
      if (segValue is! Map) {
        // Nothing to recalc; ensure a paired #svc exists (empty map)
        await box.put('$day#svc', <String, Map<String, int>>{});
        continue;
      }
      final Map<String, dynamic> byService =
      Map<String, dynamic>.from(segValue);

      // Recompute totals for each serviceId in that day
      final Map<String, Map<String, int>> totalsByService =
      <String, Map<String, int>>{};

      for (final entry in byService.entries) {
        final String serviceId = entry.key.toString();
        final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
          (entry.value as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );

        // Totals for this day and serviceId
        final Map<String, int> totals = {}..addAll(emptyTotals());

        for (final m in list) {
          final String typeKey = (m['type'] ?? '').toString();
          final String sIso = (m['start'] ?? '').toString();
          final String eIso = (m['end'] ?? '').toString();
          if (typeKey.isEmpty || sIso.isEmpty || eIso.isEmpty) continue;

          DateTime start, end;
          try {
            start = DateTime.parse(sIso);
            end = DateTime.parse(eIso);
          } catch (_) {
            continue;
          }
          if (!end.isAfter(start)) continue;

          final Map<String, int> slice = totalsForSlice(
            typeKey: typeKey,
            start: start,
            end: end,
            holidays: kRomanianLegalHolidays,
          );
          // Accumulate into totals
          slice.forEach((k2, v2) {
            final int add = v2;
            totals[k2] = (totals[k2] ?? 0) + add;
          });
        }

        totalsByService[serviceId] = totals;
      }

      // Write the paired #svc with recalculated totals
      await box.put('$day#svc', totalsByService);
    }
  }

  // ---------------------- Helpers ----------------------

  static Future<Box> _openBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box(name);
    return Hive.openBox(name);
  }

  static String? _extractDayFromKey(String k) {
    final idx = k.indexOf('#');
    if (idx <= 0) return null;
    final datePart = k.substring(0, idx); // YYYY-MM-DD
    if (datePart.length != 10) return null;
    return datePart;
  }

  static void _accumulateTotals(Map<String, int> out, Map value) {
    // Shape A: flat map of metric -> minutes (int).
    final bool looksFlat = value.values.every((v) => v is num);
    if (looksFlat) {
      value.forEach((key, v) {
        final int add = (v is num) ? v.toInt() : 0;
        out.update(key.toString(), (old) => old + add, ifAbsent: () => add);
      });
      return;
    }

    // Shape B: serviceId -> (metric -> minutes)
    value.forEach((sid, inner) {
      if (inner is Map) {
        inner.forEach((key, v) {
          final int add = (v is num) ? v.toInt() : 0;
          out.update(key.toString(), (old) => old + add, ifAbsent: () => add);
        });
      }
    });
  }

  static int _sumWorkedMinutes(Map<String, int> totals) {
    int sum = 0;
    sum += totals['trenTotalMin'] ?? 0;
    sum += totals['regieMin'] ?? 0;
    sum += totals['mvStatieMin'] ?? 0;
    sum += totals['mvDepouMin'] ?? 0;
    sum += totals['acarMin'] ?? 0;
    sum += totals['revizorMin'] ?? 0;
    sum += totals['sefTuraMin'] ?? 0;
    sum += totals['alteMin'] ?? 0;
    return sum;
  }

  static double? _asDouble(dynamic h) {
    if (h == null) return null;
    if (h is double) return h;
    if (h is int) return h.toDouble();
    if (h is String) {
      return double.tryParse(h);
    }
    return null;
  }
}
