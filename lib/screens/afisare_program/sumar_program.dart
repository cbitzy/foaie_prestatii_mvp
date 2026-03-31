// /lib/screens/afisare_program/sumar_program.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../utils/holidays.dart';

class MonthSummary {
  final Map<String, List<Map<String, dynamic>>> services; // serviceId -> segmente
  final int segmentsCount; // înainte de merge (diagnostic)
  final int totalWorkedMin;
  final int dayMin;
  final int nightMin;
  final int festDayMin;
  final int festNightMin;
  final int regieMin;
  final int odihnaMin;
  final int displayedSegments;

  const MonthSummary({
    required this.services,
    required this.segmentsCount,
    required this.totalWorkedMin,
    required this.dayMin,
    required this.nightMin,
    required this.festDayMin,
    required this.festNightMin,
    required this.regieMin,
    required this.odihnaMin,
    required this.displayedSegments,
  });

  factory MonthSummary.empty() => const MonthSummary(
    services: {},
    segmentsCount: 0,
    totalWorkedMin: 0,
    dayMin: 0,
    nightMin: 0,
    festDayMin: 0,
    festNightMin: 0,
    regieMin: 0,
    odihnaMin: 0,
    displayedSegments: 0,
  );
}

class SumarProgram extends StatefulWidget {
  final MonthSummary data;
  final int selYear;
  final int selMonth;
  final VoidCallback onSelectMonthYear;

  const SumarProgram({
    super.key,
    required this.data,
    required this.selYear,
    required this.selMonth,
    required this.onSelectMonthYear,
  });

  @override
  State<SumarProgram> createState() => _SumarProgramState();
}

class _SumarProgramState extends State<SumarProgram> {
  bool _showOvertimeDetails = false;
  bool _showNormDetails = false;
  String _fmtMin(int m) {
    final h = m ~/ 60;
    final mi = m % 60;
    if (mi == 0) {
      return '$h h';
    } else {
      return '$h h $mi min';
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<double> _loadMonthlyNormHours(int year, int month) async {
    final box = await Hive.openBox('monthly_norms_v1');
    final key = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

    final rawMap = box.get('map', defaultValue: <String, dynamic>{});
    final rawManual = box.get('manual_flags', defaultValue: <String, dynamic>{});

    final Map<String, dynamic> map =
    rawMap is Map ? Map<String, dynamic>.from(rawMap) : <String, dynamic>{};
    final Map<String, dynamic> manualMap =
    rawManual is Map ? Map<String, dynamic>.from(rawManual) : <String, dynamic>{};

    final dynamic manualRaw = manualMap[key];
    final bool isManual = manualRaw == true || manualRaw.toString().toLowerCase() == 'true';

    if (isManual) {
      final dynamic v = map[key];
      if (v is num) return v.toDouble();
      if (v is String) {
        final p = double.tryParse(v);
        if (p != null) return p;
      }
    }

    await loadLegalHolidaysFromDb();

    int workingDays = 0;
    final end = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    for (int day = 1; day <= end.day; day++) {
      final cur = DateTime(year, month, day);
      final wd = cur.weekday;
      final isWeekend = (wd == DateTime.saturday || wd == DateTime.sunday);
      final isHoliday = isLegalHoliday(cur);
      if (!isWeekend && !isHoliday) {
        workingDays++;
      }
    }
    return workingDays * 8.0;
  }

  Map<String, Map<String, int>> computeNormOvertimeBuckets({
    required int year,
    required int month,
    required int normMin,
  }) {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 1);

    bool isWeekend(DateTime d) =>
        d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

    bool isFestive(DateTime d) => isWeekend(d) || isLegalHoliday(d);

    bool isNight(DateTime t) => (t.hour < 6) || (t.hour >= 22);

    String bucketKey(DateTime t) {
      final fest = isFestive(t);
      final night = isNight(t);
      if (fest) return night ? 'festNight' : 'festDay';
      return night ? 'night' : 'day';
    }

    DateTime nextBoundary(DateTime cursor) {
      final baseDay = DateTime(cursor.year, cursor.month, cursor.day);
      final midnightNext =
      DateTime(baseDay.year, baseDay.month, baseDay.day + 1);
      final six = DateTime(cursor.year, cursor.month, cursor.day, 6);
      final twentyTwo = DateTime(cursor.year, cursor.month, cursor.day, 22);

      DateTime next = midnightNext;
      if (cursor.isBefore(six) && six.isBefore(next)) {
        next = six;
      }
      if (cursor.isBefore(twentyTwo) && twentyTwo.isBefore(next)) {
        next = twentyTwo;
      }
      return next;
    }

    final normBuckets = <String, int>{
      'day': 0,
      'night': 0,
      'festDay': 0,
      'festNight': 0,
    };
    final overtimeBuckets = <String, int>{
      'day': 0,
      'night': 0,
      'festDay': 0,
      'festNight': 0,
    };

    final flatSegs = <Map<String, dynamic>>[];
    for (final segs in widget.data.services.values) {
      for (final seg in segs) {
        flatSegs.add(seg);
      }
    }

    flatSegs.sort((a, b) {
      DateTime sa, sb, ea, eb;
      try {
        sa = DateTime.parse(a['start'] as String);
        sb = DateTime.parse(b['start'] as String);
        ea = DateTime.parse(a['end'] as String);
        eb = DateTime.parse(b['end'] as String);
      } catch (_) {
        return 0;
      }
      final c = sa.compareTo(sb);
      if (c != 0) return c;
      return ea.compareTo(eb);
    });

    int remainingNorm = normMin;

    for (final seg in flatSegs) {
      final type = (seg['type'] as String?) ?? '';
      if (type == 'odihna') {
        continue;
      }

      DateTime rawStart, rawEnd;
      try {
        rawStart = DateTime.parse(seg['start'] as String);
        rawEnd = DateTime.parse(seg['end'] as String);
      } catch (_) {
        continue;
      }

      if (!rawEnd.isAfter(rawStart)) {
        continue;
      }

      if (!rawEnd.isAfter(monthStart) || !monthEnd.isAfter(rawStart)) {
        continue;
      }

      final start = rawStart.isBefore(monthStart) ? monthStart : rawStart;
      final end = rawEnd.isAfter(monthEnd) ? monthEnd : rawEnd;

      if (!end.isAfter(start)) {
        continue;
      }

      var cursor = start;
      while (end.isAfter(cursor)) {
        final boundary = nextBoundary(cursor);
        final chunkEnd = boundary.isBefore(end) ? boundary : end;

        final mins = chunkEnd.difference(cursor).inMinutes;
        if (mins <= 0) {
          cursor = chunkEnd;
          continue;
        }

        final key = bucketKey(cursor);

        if (remainingNorm > 0) {
          final take = remainingNorm < mins ? remainingNorm : mins;
          normBuckets[key] = (normBuckets[key] ?? 0) + take;
          remainingNorm -= take;

          final rest = mins - take;
          if (rest > 0) {
            overtimeBuckets[key] = (overtimeBuckets[key] ?? 0) + rest;
          }
        } else {
          overtimeBuckets[key] = (overtimeBuckets[key] ?? 0) + mins;
        }

        cursor = chunkEnd;
      }
    }

    return {
      'norm': normBuckets,
      'overtime': overtimeBuckets,
    };
  }

  @override
  Widget build(BuildContext context) {
    final nowDt = DateTime.now();
    final curPeriod = DateTime(nowDt.year, nowDt.month);
    final selPeriod = DateTime(widget.selYear, widget.selMonth);

    final isFuture = selPeriod.isAfter(curPeriod);
    final isPast = selPeriod.isBefore(curPeriod);
    final hasWorked = widget.data.totalWorkedMin > 0;

    final monthName = _cap(DateFormat('MMMM', 'ro_RO').format(DateTime(widget.selYear, widget.selMonth)));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Total servicii ',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onSelectMonthYear,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: IgnorePointer(
                      ignoring: true,
                      child: DropdownButton<int>(
                        value: widget.selMonth,
                        isDense: true,
                        iconSize: 18,
                        icon: const Icon(Icons.arrow_drop_down),
                        style: Theme.of(context).textTheme.bodyMedium,
                        items: List<int>.generate(12, (i) => i + 1)
                            .map(
                              (mm) => DropdownMenuItem<int>(
                            value: mm,
                            child: Text(
                              _cap(DateFormat('MMMM', 'ro_RO').format(DateTime(2000, mm))),
                            ),
                          ),
                        )
                            .toList(),
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${widget.selYear}', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),

          // Linia 2: Norma lună <luna>: <ore> — mic, italic (bold DOAR pe <ore>), font un pic mai mare; afișată doar când orele lucrate < normă
          FutureBuilder<double>(
            future: _loadMonthlyNormHours(widget.selYear, widget.selMonth),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final double normH = snap.data ?? 0.0;
              final int normMin = (normH * 60.0).floor();
              final int workedMin = widget.data.totalWorkedMin;
              if (normMin <= 0 || workedMin >= normMin) {
                return const SizedBox.shrink();
              }
              final String monthName2 = _cap(DateFormat('MMMM', 'ro_RO').format(DateTime(widget.selYear, widget.selMonth)));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Norma luna ',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                        TextSpan(
                          text: monthName2,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                        const TextSpan(
                          text: ': ',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                        TextSpan(
                          text: _fmtMin(normMin),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    // mărim puțin față de bodySmall
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) + 2,
                    ),
                  ),
                  // spațiu între titluri (Norma mică -> Ore serviciu)
                  const SizedBox(height: 12),
                ],
              );
            },
          ),


          if (isFuture)
            Text(
              'Luna $monthName ${widget.selYear} este în viitor. Nu există prestații înregistrate încă.',
              style: const TextStyle(fontStyle: FontStyle.italic),
            )
          else if (hasWorked)
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Ore serviciu ',
                    style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: monthName,
                    style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: ':   ',
                    style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: _fmtMin(widget.data.totalWorkedMin),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17),
            )
          else if (isPast)
              Text(
                'Nu s-au executat servicii în $monthName ${widget.selYear} sau acestea nu au fost înregistrate în aplicație.',
                style: const TextStyle(fontStyle: FontStyle.italic),
              )
            else
              const Text(
                'Nu există servicii înregistrate pentru luna curentă.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),

          // spațiu între titluri (Ore serviciu -> următorul titlu)
          const SizedBox(height: 12),

          if ((widget.data.dayMin + widget.data.nightMin) > 0)
            Text(
              'Serviciu normal: ${_fmtMin(widget.data.dayMin + widget.data.nightMin)}',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (widget.data.dayMin > 0)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text('Serviciu zi: ${_fmtMin(widget.data.dayMin)}'),
            ),
          if (widget.data.nightMin > 0)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text('Serviciu noapte: ${_fmtMin(widget.data.nightMin)}'),
            ),
          if ((widget.data.festDayMin + widget.data.festNightMin) > 0)
            Text(
              'Serviciu festive: ${_fmtMin(widget.data.festDayMin + widget.data.festNightMin)}',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (widget.data.festDayMin > 0)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text('Serviciu festive zi: ${_fmtMin(widget.data.festDayMin)}'),
            ),
          if (widget.data.festNightMin > 0)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text('Serviciu festive noapte: ${_fmtMin(widget.data.festNightMin)}'),
            ),

          if ((widget.data.dayMin + widget.data.nightMin) > 0 ||
              (widget.data.festDayMin + widget.data.festNightMin) > 0)
            const SizedBox(height: 12),

          if (widget.data.odihnaMin > 0) Text('Odihnă: ${_fmtMin(widget.data.odihnaMin)}'),

          // —— Rând gol înainte de „Normă lună …” (doar deasupra ei) ——
          if ((widget.data.dayMin + widget.data.nightMin) > 0 ||
              (widget.data.festDayMin + widget.data.festNightMin) > 0 ||
              widget.data.odihnaMin > 0)
            const SizedBox(height: 12),

          // Normă lună <luna> (expandabilă), cu total + copii în interior
          FutureBuilder<double>(
            future: _loadMonthlyNormHours(widget.selYear, widget.selMonth),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final double normH = snap.data ?? 0.0;
              final int normMin = (normH * 60.0).floor();
              final int workedMin = widget.data.totalWorkedMin;
              if (workedMin < normMin) {
                return const SizedBox.shrink();
              }
              final String monthName2 = _cap(DateFormat('MMMM', 'ro_RO').format(DateTime(widget.selYear, widget.selMonth)));

              final breakdown = computeNormOvertimeBuckets(
                year: widget.selYear,
                month: widget.selMonth,
                normMin: normMin,
              );

              final normBuckets = breakdown['norm'] ?? const <String, int>{};
              final int nZi = normBuckets['day'] ?? 0;
              final int nNoapte = normBuckets['night'] ?? 0;
              final int nFestZi = normBuckets['festDay'] ?? 0;
              final int nFestNoapte = normBuckets['festNight'] ?? 0;

              final normHeader = InkWell(
                onTap: () => setState(() => _showNormDetails = !_showNormDetails),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Normă luna $monthName2: ',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text: '${normH.truncateToDouble() == normH ? normH.toStringAsFixed(0) : normH.toStringAsFixed(2)} h',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(_showNormDetails ? Icons.expand_less : Icons.expand_more, size: 20),
                  ],
                ),
              );

              final List<Widget> normChildren = [
                normHeader,
              ];

              if (_showNormDetails) {
                normChildren.addAll([
                  const SizedBox(height: 8),
                  if ((nZi + nNoapte) > 0)
                    Text(
                      'Serviciu normă: ${_fmtMin(nZi + nNoapte)}',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (nZi > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text('Normă zi: ${_fmtMin(nZi)}'),
                    ),
                  if (nNoapte > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text('Normă noapte: ${_fmtMin(nNoapte)}'),
                    ),
                  if ((nFestZi + nFestNoapte) > 0)
                    Text(
                      'Serviciu festive normă: ${_fmtMin(nFestZi + nFestNoapte)}',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (nFestZi > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text('Normă festive zi: ${_fmtMin(nFestZi)}'),
                    ),
                  if (nFestNoapte > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text('Normă festive noapte: ${_fmtMin(nFestNoapte)}'),
                    ),
                ]);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: normChildren,
              );
            },
          ),

          // —— Rând gol între **ultima defalcare** a normei lunare și „Ore suplimentare” ——
          const SizedBox(height: 12),

          // Secțiunea „Ore suplimentare” (doar dacă > 0), expandabilă, cu total + copii în interior
          FutureBuilder<double>(
            future: _loadMonthlyNormHours(widget.selYear, widget.selMonth),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final double normH = snap.data ?? 0.0;
              final int normMin = (normH * 60.0).floor();
              final int workedMin = widget.data.totalWorkedMin;
              final int overtimeMin = (workedMin > normMin) ? (workedMin - normMin) : 0;
              if (overtimeMin <= 0) {
                return const SizedBox.shrink();
              }

              final String monthName2 = _cap(DateFormat('MMMM', 'ro_RO').format(DateTime(widget.selYear, widget.selMonth)));

              final breakdown = computeNormOvertimeBuckets(
                year: widget.selYear,
                month: widget.selMonth,
                normMin: normMin,
              );

              final overtimeBuckets = breakdown['overtime'] ?? const <String, int>{};
              final int supDay = overtimeBuckets['day'] ?? 0;
              final int supNight = overtimeBuckets['night'] ?? 0;
              final int supFestDay = overtimeBuckets['festDay'] ?? 0;
              final int supFestNight = overtimeBuckets['festNight'] ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() => _showOvertimeDetails = !_showOvertimeDetails),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Ore suplimentare ',
                                style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: monthName2,
                                style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(
                                text: ':   ',
                                style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: _fmtMin(overtimeMin),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17),
                        ),
                        const SizedBox(width: 6),
                        Icon(_showOvertimeDetails ? Icons.expand_less : Icons.expand_more, size: 20),
                      ],
                    ),
                  ),
                  if (_showOvertimeDetails) ...[
                    const SizedBox(height: 8),
                    if ((supDay + supNight) > 0)
                      Text(
                        'Suplimentare normale: ${_fmtMin(supDay + supNight)}',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (supDay > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Text('Suplimentare zi: ${_fmtMin(supDay)}'),
                      ),
                    if (supNight > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Text('Suplimentare noapte: ${_fmtMin(supNight)}'),
                      ),
                    if ((supFestDay + supFestNight) > 0)
                      Text(
                        'Suplimentare festive: ${_fmtMin(supFestDay + supFestNight)}',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (supFestDay > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Text('Suplimentare festive zi: ${_fmtMin(supFestDay)}'),
                      ),
                    if (supFestNight > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Text('Suplimentare festive noapte: ${_fmtMin(supFestNight)}'),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}