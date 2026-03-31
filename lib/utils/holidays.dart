import 'package:hive_flutter/hive_flutter.dart';

/// Box și cheie pentru sărbători legale persistate.
const String _kLegalHolidaysBox = 'legal_holidays_v1';
const String _kLegalHolidaysKey = 'dates'; // List<String> ISO (yyyy-MM-dd)

/// Setul folosit în calcule. Este actualizat din DB prin `loadLegalHolidaysFromDb()`.
/// Dacă DB este gol, rămâne gol până la prima salvare în Setări.
Set<DateTime> kRomanianLegalHolidays = <DateTime>{};

/// Încarcă din DB toate datele marcate ca sărbători legale și actualizează
/// `kRomanianLegalHolidays`. Toate datele sunt normalizate la 00:00.
Future<void> loadLegalHolidaysFromDb() async {
  final box = await Hive.openBox(_kLegalHolidaysBox);
  final raw = box.get(_kLegalHolidaysKey, defaultValue: const <String>[]);
  final list = List<String>.from(raw);
  kRomanianLegalHolidays = list
      .map((s) => DateTime.parse(s))
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet();
}

/// Helper: întoarce `true` dacă `d` (ignorând ora) este zi liberă legală.
bool isLegalHoliday(DateTime d) {
  final DateTime dd = DateTime(d.year, d.month, d.day);
  return kRomanianLegalHolidays.contains(dd);
}
