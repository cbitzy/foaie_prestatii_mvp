class SplitResult {
  final int dayWorkMin;
  final int nightWorkMin;
  final int festiveDayMin;
  final int festiveNightMin;
  const SplitResult({
    required this.dayWorkMin,
    required this.nightWorkMin,
    required this.festiveDayMin,
    required this.festiveNightMin,
  });
}

bool _isHolidayOrWeekend(DateTime d, Set<DateTime> roHolidays) {
  // Normalizează la 00:00
  final key = DateTime(d.year, d.month, d.day);
  if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) return true;
  // Listele tale de sărbători trebuie normalizate la 00:00 în kRomanianLegalHolidays
  return roHolidays.contains(key);
}

/// Zi = [06:00, 22:00), Noapte = [22:00, 06:00)
SplitResult splitServiceTime(
    DateTime start,
    DateTime end,
    Set<DateTime> roHolidays,
    ) {
  // FIX: Validare mai strictă - end trebuie STRICT după start
  assert(end.isAfter(start), 'End must be strictly after start (no zero-duration segments allowed)');

  int day = 0, night = 0, fday = 0, fnight = 0;

  DateTime cursor = start;
  while (cursor.isBefore(end)) {
    // Sfârșitul zilei curente (00:00 a zilei următoare, calendaristic)
    final dayBoundary = DateTime(cursor.year, cursor.month, cursor.day + 1);
    final localEnd = end.isBefore(dayBoundary) ? end : dayBoundary;

    // Ferestrele zilei curente
    final dayStart = DateTime(cursor.year, cursor.month, cursor.day, 6, 0);
    final dayEnd   = DateTime(cursor.year, cursor.month, cursor.day, 22, 0);

    // Intersecția segmentului cu fereastra de ZI [06:00, 22:00)
    final ziStart = cursor.isAfter(dayStart) ? cursor : dayStart;
    final ziEnd   = localEnd.isBefore(dayEnd) ? localEnd : dayEnd;
    final ziMin   = ziEnd.isAfter(ziStart) ? ziEnd.difference(ziStart).inMinutes : 0;

    // Noaptea sunt resturile din [cursor, localEnd) care nu intră în [06:00,22:00)
    final totalMin = localEnd.difference(cursor).inMinutes;
    final noapteMin = totalMin - ziMin;

    final festive = _isHolidayOrWeekend(cursor, roHolidays);
    if (festive) {
      fday   += ziMin;
      fnight += noapteMin;
    } else {
      day   += ziMin;
      night += noapteMin;
    }

    cursor = localEnd;
  }

  return SplitResult(
    dayWorkMin: day,
    nightWorkMin: night,
    festiveDayMin: fday,
    festiveNightMin: fnight,
  );
}
