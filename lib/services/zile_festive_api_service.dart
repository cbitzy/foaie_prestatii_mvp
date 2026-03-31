import 'dart:async';

/// Serviciu care obține zilele festive conform regulilor folosite de aplicație.
/// Strategia este dublă:
/// 1) Zile legale conform Codului muncii – calculate local pentru anul cerut.
/// 2) Zi specială conform Contractului colectiv de muncă: 16 februarie.
///
/// NOTĂ:
/// - Calculul pentru Paște/Rusalii folosește algoritmul standard pentru Paștele Ortodox.
class HolidayItem {
  final DateTime date;
  /// ex: "Codul muncii (art. 139) — zi fixă", "Codul muncii — Paștele ortodox (algoritm Meeus)", "HG 2/10.01.2025"
  final String source;
  /// ex: "law_fixed", "law_easter", "law_good_friday", "law_pentecost"
  final String category;
  const HolidayItem({required this.date, required this.source, required this.category});
}

class ZileFestiveApiService {

  /// Varianta cu proveniență (sursă) pentru fiecare zi.
  Future<List<HolidayItem>> getZileFestiveWithSources(int an) async {
    final items = <HolidayItem>[];

    // Dummy call pentru a marca funcția ca "folosită"

    // Marcăm legal-urile prin metoda dedicată, ca să păstrăm logica într-un singur loc
    final legal = _computeHolidayDatesForAppRules(an).toSet();

    // Pregătim referințele pentru mobile, ca să putem eticheta corect
    final easter = _orthodoxEaster(an);
    final goodFriday = easter.subtract(const Duration(days: 2));
    final easterMonday = easter.add(const Duration(days: 1));
    final pentecost = easter.add(const Duration(days: 49));
    final pentecostMonday = easter.add(const Duration(days: 50));

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    for (final d0 in legal) {
      final d = DateTime(d0.year, d0.month, d0.day);
      String category;
      String label;

      if (sameDay(d, goodFriday)) {
        category = "law_good_friday";
        label = "Codul muncii — Vinerea Mare (calcul prin Paștele ortodox, algoritm Meeus)";
      } else if (sameDay(d, easter)) {
        category = "law_easter";
        label = "Codul muncii — Paștele ortodox (algoritm Meeus)";
      } else if (sameDay(d, easterMonday)) {
        category = "law_easter_monday";
        label = "Codul muncii — A doua zi de Paște (algoritm Meeus)";
      } else if (sameDay(d, pentecost)) {
        category = "law_pentecost";
        label = "Codul muncii — Rusaliile (algoritm Meeus)";
      } else if (sameDay(d, pentecostMonday)) {
        category = "law_pentecost_monday";
        label = "Codul muncii — A doua zi de Rusalii (algoritm Meeus)";
      } else if (d.year == an && d.month == 2 && d.day == 16) {
        category = "ccm_fixed";
        label = "Contractul colectiv de muncă — 16 februarie";
      } else {
        category = "law_fixed";
        label = "Codul muncii (art. 139) — zi fixă";
      }

      items.add(HolidayItem(date: d, source: label, category: category));
    }

    // Unic + sort
    final uniq = <String, HolidayItem>{};
    for (final it in items) {
      final k = "${it.date.year}-${it.date.month}-${it.date.day}-${it.category}";
      uniq[k] = it;
    }
    final result = uniq.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  Future<List<DateTime>> getZileFestive(int an) async {
    final items = await getZileFestiveWithSources(an);
    final all = items.map((e) => e.date).toSet().toList()..sort((a, b) => a.compareTo(b));
    return all;
  }

  /// 1) Zile legale după Codul muncii (Art. 139)
  /// 2) Zi specială configurată conform Contractului colectiv de muncă: 16 februarie
  List<DateTime> _computeHolidayDatesForAppRules(int year) {
    final easter = _orthodoxEaster(year);
    final goodFriday = easter.subtract(const Duration(days: 2));
    final easterMonday = easter.add(const Duration(days: 1));
    final pentecost = easter.add(const Duration(days: 49));
    final pentecostMonday = easter.add(const Duration(days: 50));

    final fixed = <DateTime>[
      DateTime(year, 1, 1),
      DateTime(year, 1, 2),
      DateTime(year, 1, 6),
      DateTime(year, 1, 7),
      DateTime(year, 1, 24),
      DateTime(year, 2, 16), // Contractul colectiv de muncă
      DateTime(year, 5, 1),
      DateTime(year, 6, 1),
      DateTime(year, 8, 15),
      DateTime(year, 11, 30),
      DateTime(year, 12, 1),
      DateTime(year, 12, 25),
      DateTime(year, 12, 26),
    ];

    final mobile = <DateTime>[
      goodFriday,
      easter,
      easterMonday,
      pentecost,
      pentecostMonday
    ];

    return [...fixed, ...mobile]
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList();
  }

  /// Algoritm Paște Ortodox (Meeus)
  DateTime _orthodoxEaster(int year) {
    final a = year % 4;
    final b = year % 7;
    final c = year % 19;
    final d = (19 * c + 15) % 30;
    final e = (2 * a + 4 * b - d + 34) % 7;
    final month = ((d + e + 114) ~/ 31);
    final day = ((d + e + 114) % 31) + 1;

    final julianEaster = DateTime(year, month, day + 13);
    return DateTime(julianEaster.year, julianEaster.month, julianEaster.day);
  }
}
