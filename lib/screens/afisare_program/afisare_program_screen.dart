// /lib/screens/afisare_program/afisare_program_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/report_storage_v2.dart';
import 'package:foaie_prestatii_mvp/calcule_ore/api.dart';

import 'ecran_fix.dart';
import 'sumar_program.dart';
import 'show_servicii_detaliate.dart';

class AfisareProgramScreen extends StatefulWidget {
  const AfisareProgramScreen({super.key});

  @override
  State<AfisareProgramScreen> createState() => _AfisareProgramScreenState();
}

class _AfisareProgramScreenState extends State<AfisareProgramScreen> {
  String _name = '';

  late int _selYear;
  late int _selMonth;

  Future<MonthSummary>? _future;

  StreamSubscription<BoxEvent>? _hiveSub;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selYear = now.year;
    _selMonth = now.month;
    _loadName();
    _future = _loadSummary(_selYear, _selMonth);
    _attachHiveWatcher();
  }

  Future<void> _attachHiveWatcher() async {
    final box = await Hive.openBox(ReportStorageV2.boxName);
    _hiveSub?.cancel();
    _hiveSub = box.watch().listen((_) {
      if (!mounted) return;
      setState(() {
        _future = _loadSummary(_selYear, _selMonth);
      });
    });
  }

  @override
  void dispose() {
    _hiveSub?.cancel();
    super.dispose();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('mechanic_name') ?? '';
    });
  }

  /// Unește feliile consecutive tăiate doar la miezul nopții pentru afișare.
  /// Condiții de merge:
  /// - tip identic (type)
  /// - trainNo identic (sau ambele null/șir gol)
  /// - next.start == cur.end (touch)
  List<Map<String, dynamic>> _mergeMidnightSlices(List<Map<String, dynamic>> input) {
    if (input.isEmpty) return const [];

    final out = <Map<String, dynamic>>[];
    Map<String, dynamic> cur = Map<String, dynamic>.from(input.first);

    String norm(dynamic v) => (v == null) ? '' : v.toString().trim();

    bool sameIfPresent(String a, String b) {
      final aHas = a.isNotEmpty;
      final bHas = b.isNotEmpty;
      if (!aHas && !bHas) return true;
      if (aHas != bHas) return false;
      return a == b;
    }

    bool sameTrainNo(Map<String, dynamic> a, Map<String, dynamic> b) {
      return sameIfPresent(norm(a['trainNo']), norm(b['trainNo']));
    }

    bool sameSheet(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aSeries = norm(a['sheetSeries']);
      final aNumber = norm(a['sheetNumber']);
      final bSeries = norm(b['sheetSeries']);
      final bNumber = norm(b['sheetNumber']);

      final aHas = aSeries.isNotEmpty || aNumber.isNotEmpty;
      final bHas = bSeries.isNotEmpty || bNumber.isNotEmpty;
      if (!aHas && !bHas) return true;
      if (aHas != bHas) return false;
      return aSeries == bSeries && aNumber == bNumber;
    }

    bool sameAlteDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
      if (norm(a['type']) != 'alte') return true;
      return sameIfPresent(
        norm(a['desc'] ?? a['description']),
        norm(b['desc'] ?? b['description']),
      );
    }

    bool isExactMidnight(DateTime dt) =>
        dt.hour == 0 &&
            dt.minute == 0 &&
            dt.second == 0 &&
            dt.millisecond == 0 &&
            dt.microsecond == 0;

    for (int i = 1; i < input.length; i++) {
      final next = input[i];
      final curEnd = DateTime.parse(cur['end'] as String);
      final nextStart = DateTime.parse(next['start'] as String);

      final touches = nextStart.isAtSameMomentAs(curEnd);
      final splitAtMidnight = touches && isExactMidnight(curEnd);

      final sameType = norm(cur['type']) == norm(next['type']);
      final sameNo = sameTrainNo(cur, next);
      final sameFoaie = sameSheet(cur, next);
      final sameDesc = sameAlteDesc(cur, next);

      if (splitAtMidnight && sameType && sameNo && sameFoaie && sameDesc) {
        cur['end'] = next['end'];
      } else {
        out.add(cur);
        cur = Map<String, dynamic>.from(next);
      }
    }

    out.add(cur);
    return out;
  }

  // --- PRIORITATE tipuri pentru normalizarea overlap-urilor
  int _typePriority(String t) {
    switch (t) {
      case 'tren':     return 100;
      case 'mvStatie': return 90;
      case 'mvDepou':  return 90;
      case 'revizor':  return 80;
      case 'sefTura':  return 80;
      case 'acar':     return 70;
      case 'regie':    return 60;
      case 'alte':     return 60;
      case 'odihna':   return 10;
      default:         return 0;
    }
  }

  /// Taie timeline-ul la toate bornele (start/end) și pe fiecare bucățică păstrează
  /// doar tipul cu prioritate mai mare. Apoi lipește intervalele adiacente (touch)
  /// cu același tip și același trainNo.
  List<Map<String, dynamic>> _normalizeNonOverlapping(List<Map<String, dynamic>> segs) {
    if (segs.isEmpty) return const [];

    // 1) adunăm toate capetele de interval
    final boundaries = <DateTime>{};
    for (final s in segs) {
      boundaries.add(DateTime.parse(s['start'] as String));
      boundaries.add(DateTime.parse(s['end']   as String));
    }
    final xs = boundaries.toList()..sort();

    // 2) pentru fiecare [xs[i], xs[i+1]) alegem tipul cu prioritate maximă
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < xs.length - 1; i++) {
      final a = xs[i];
      final b = xs[i + 1];
      if (!b.isAfter(a)) continue;

      final active = segs.where((s) {
        final ss = DateTime.parse(s['start'] as String);
        final ee = DateTime.parse(s['end']   as String);
        return !a.isBefore(ss) && a.isBefore(ee);
      }).toList();

      if (active.isEmpty) continue;

      active.sort((x, y) => _typePriority(y['type'] as String)
          .compareTo(_typePriority(x['type'] as String)));
      final top = active.first;

      out.add({
        'type': top['type'],
        'trainNo': (top['type'] == 'tren') ? top['trainNo'] : null,
        'start': a.toIso8601String(),
        'end':   b.toIso8601String(),
      });
    }

    // 3) lipim bucățile adiacente cu același tip/număr tren
    return _mergeMidnightSlices(out);
  }

  /// Încarcă toate serviciile din lună, calculează totalurile (zi/noapte/festiv/regie/odihnă).
  /// Afișarea se face pe servicii (group by serviceId), exact ca la editor, DESC.
  Future<MonthSummary> _loadSummary(int year, int month) async {
    // Harta serviciilor pentru lună: serviceId -> listă de segmente (așa vine din storage)
    final services = await ReportStorageV2.listServicesForMonthWithSegments(year, month);

    // Calcule totale pe întreaga lună
    int combDay = 0, combNight = 0, combFestDay = 0, combFestNight = 0;
    int regieMin = 0, odihnaMin = 0;

    int segmentsCount = 0;

    // 1) doar contorizăm segmentele brute (diagnostic)
    for (final segs in services.values) {
      for (final _ in segs) {
        segmentsCount++;
      }
    }

    // 2) totalurile se calculează pe timeline NORMALIZAT (fără dublări)
    for (final segs in services.values) {
      final norm = _normalizeNonOverlapping(segs);

      for (final s in norm) {
        final type = (s['type'] ?? '') as String;
        final start = DateTime.parse(s['start'] as String);
        final end   = DateTime.parse(s['end']   as String);

        // Buckets de muncă (zi/noapte/festive) – includ: tren, mvStatie, mvDepou, acar, regie, revizor, sefTura, alte
        final wb = workedBucketsForSlice(
          typeKey: type,
          start: start,
          end: end,
          holidays: kRomanianLegalHolidays,
        );
        combDay       += wb['day'] ?? 0;
        combNight     += wb['night'] ?? 0;
        combFestDay   += wb['festDay'] ?? 0;
        combFestNight += wb['festNight'] ?? 0;

        // Minute specifice pentru regie / odihna (din modulul de calcule)
        final sliceTotals = totalsForSlice(
          typeKey: type,
          start: start,
          end: end,
          holidays: kRomanianLegalHolidays,
        );
        regieMin  += sliceTotals['regieMin']  ?? 0;
        odihnaMin += sliceTotals['odihnaMin'] ?? 0;
      }

    }

    final totalWorked = combDay + combNight + combFestDay + combFestNight;

    // total segmente afișate (după lipirea la miezul nopții)
    int displayedSegments = 0;
    for (final segs in services.values) {
      displayedSegments += _mergeMidnightSlices(segs).length;
    }

    return MonthSummary(
      services: services,
      segmentsCount: segmentsCount,
      totalWorkedMin: totalWorked,
      dayMin: combDay,
      nightMin: combNight,
      festDayMin: combFestDay,
      festNightMin: combFestNight,
      regieMin: regieMin,
      odihnaMin: odihnaMin,
      displayedSegments: displayedSegments,
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return EcranFix(
      appTitle: 'Afișare Prestații',
      mechanicName: _name,
      body: FutureBuilder<MonthSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? MonthSummary.empty();

          // Topul devine scrollabil; butonul rămâne fix jos pe ecran.
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: SumarProgram(
                    data: data,
                    selYear: _selYear,
                    selMonth: _selMonth,
                    onSelectMonthYear: _selectMonthYear,
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.view_list),
                      label: const Text('Servicii detaliate'),
                      onPressed: () => showServiciiDetaliateBottomSheet(
                        context: context,
                        services: data.services,
                        mergeMidnightSlices: _mergeMidnightSlices,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectMonthYear() async {
    final now = DateTime.now();
    int y = _selYear;
    int m = _selMonth;

    final picked = await showDialog<DateTime?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            bool isFutureSel() {
              final cur = DateTime(now.year, now.month);
              return DateTime(y, m).isAfter(cur);
            }

            final years = List<int>.generate(8, (i) => now.year - 5 + i);
            final months = List<int>.generate(12, (i) => i + 1);

            if (y > now.year) m = now.month;
            if (y == now.year && m > now.month) m = now.month;

            return AlertDialog(
              title: const Text('Alege luna/anul'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: m,
                            decoration: const InputDecoration(
                              labelText: 'Lună',
                              border: OutlineInputBorder(),
                            ),
                            items: months.map((mm) {
                              final bool disabled =
                                  (y > now.year) || (y == now.year && mm > now.month);
                              return DropdownMenuItem<int>(
                                value: mm,
                                enabled: !disabled,
                                child: Text(
                                  _cap(DateFormat('MMMM', 'ro_RO').format(DateTime(2000, mm))),
                                  style: disabled
                                      ? TextStyle(color: Theme.of(ctx).disabledColor)
                                      : null,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => setSt(() {
                              if (v != null) m = v;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: y,
                            decoration: const InputDecoration(
                              labelText: 'An',
                              border: OutlineInputBorder(),
                            ),
                            items: years.map((yy) {
                              final bool disabled = yy > now.year;
                              return DropdownMenuItem<int>(
                                value: yy,
                                enabled: !disabled,
                                child: Text(
                                  '$yy',
                                  style: disabled
                                      ? TextStyle(color: Theme.of(ctx).disabledColor)
                                      : null,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => setSt(() {
                              if (v == null) return;
                              y = v;
                              if (y > now.year) {
                                m = now.month;
                              } else if (y == now.year && m > now.month) {
                                m = now.month;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (isFutureSel())
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.error.withAlpha((0.08 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Perioada aleasă este în viitor. Nu există prestații înregistrate încă — selectează luna curentă sau o lună anterioară.',
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Anulează'),
                ),
                ElevatedButton(
                  onPressed: isFutureSel() ? null : () => Navigator.pop(ctx, DateTime(y, m)),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked is DateTime && mounted) {
      setState(() {
        _selYear = picked.year;
        _selMonth = picked.month;
        _future = _loadSummary(_selYear, _selMonth);
      });
    }
  }
}
