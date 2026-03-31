// /lib/screens/monthly_report_by_train_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/report_storage_v2.dart';
// Refolosim exact renderer-ul din ecranul "Servicii detaliate"
// (ajustează importul dacă fișierul e în altă locație în proiectul tău)
import '../screens/afisare_program/afisare_servicii.dart' show AfisareServicii, MergeSlicesFn;

class MonthlyReportByTrainScreen extends StatefulWidget {
  final int year;
  final int month;
  const MonthlyReportByTrainScreen({super.key, required this.year, required this.month});

  @override
  State<MonthlyReportByTrainScreen> createState() => _MonthlyReportByTrainScreenState();
}

class _MonthlyReportByTrainScreenState extends State<MonthlyReportByTrainScreen> {
  late int _y;
  late int _m;

  Future<Map<String, List<Map<String, dynamic>>>>? _future;

  @override
  void initState() {
    super.initState();
    _y = widget.year;
    _m = widget.month;
    _future = _load(_y, _m);
  }

  Future<Map<String, List<Map<String, dynamic>>>> _load(int year, int month) {
    return ReportStorageV2.listServicesForMonthWithSegments(year, month);
  }

  // Aceeași logică de coalescere a fâșiilor la miezul nopții ca în celelalte ecrane
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

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    int yy = _y;
    int mm = _m;

    final picked = await showDialog<DateTime?>(
      context: context,
      builder: (ctx) {
        final years = List<int>.generate(8, (i) => now.year - 5 + i);
        final months = List<int>.generate(12, (i) => i + 1);
        return AlertDialog(
          title: const Text('Alege luna'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: mm,
                  decoration: const InputDecoration(labelText: 'Lună', border: OutlineInputBorder()),
                  items: months.map((m) {
                    final name = DateFormat('MMMM', 'ro_RO').format(DateTime(2000, m));
                    return DropdownMenuItem(value: m, child: Text('${name[0].toUpperCase()}${name.substring(1)}'));
                  }).toList(),
                  onChanged: (v) => mm = v ?? mm,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: yy,
                  decoration: const InputDecoration(labelText: 'An', border: OutlineInputBorder()),
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                  onChanged: (v) => yy = v ?? yy,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx, null), child: const Text('Anulează')),
            ElevatedButton(onPressed: ()=>Navigator.pop(ctx, DateTime(yy, mm)), child: const Text('OK')),
          ],
        );
      },
    );

    if (!mounted || picked == null) return;

    if (DateTime(picked.year, picked.month).isAfter(current)) {
      // Nu permitem viitorul
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Lună în viitor'),
          content: Text('Nu poți vizualiza prestații pentru o lună viitoare — nu au fost încă efectuate.'),
        ),
      );
      return;
    }

    setState(() {
      _y = picked.year;
      _m = picked.month;
      _future = _load(_y, _m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = DateFormat('MMMM yyyy', 'ro_RO').format(DateTime(_y, _m));
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Raport lunar — '),
            InkWell(
              onTap: _pickMonth,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? const <String, List<Map<String, dynamic>>>{};
          if (data.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nu există servicii înregistrate pentru luna selectată.'),
              ),
            );
          }

          // Render exact ca în ecranul "Servicii detaliate"
          final MergeSlicesFn mergeFn = _mergeMidnightSlices;
          return AfisareServicii(
            services: data,
            mergeMidnightSlices: mergeFn,
            groupBySheet: true,
          );
        },
      ),
    );
  }
}