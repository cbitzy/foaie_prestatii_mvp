// lib/screens/Adauga_modifica_serviciu/adauga_modifica_serviciu.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/report_storage_v2.dart';
import '../../services/recalculator.dart';
import '../../services/advanced_photo_cleanup_service.dart';
import '../../utils/service_title.dart' show formatServiceTitle;

import '../../models/service_segment.dart';
import 'adauga_serviciu.dart' show AdaugaServiciuScreen;

/// Ecran „Adaugă / Modifică Serviciu”
class AdaugaModificaServiciuScreen extends StatefulWidget {
  const AdaugaModificaServiciuScreen({
    super.key,
    this.initialSuggestedStart,
  });

  final DateTime? initialSuggestedStart;

  @override
  State<AdaugaModificaServiciuScreen> createState() =>
      _AdaugaModificaServiciuScreenState();
}

class _AdaugaModificaServiciuScreenState
    extends State<AdaugaModificaServiciuScreen> {
  late int _selYear;
  late int _selMonth;

  Future<Map<String, List<Map<String, dynamic>>>>? _future;
  final DateFormat _dfRow = DateFormat('dd.MM.yyyy HH:mm', 'ro_RO');

  StreamSubscription<BoxEvent>? _hiveStreamSub;
  StreamSubscription<BoxEvent>? _hiveMetaStreamSub;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selYear = now.year;
    _selMonth = now.month;
    _future = _loadServices(_selYear, _selMonth);
    _attachHiveWatcher();
  }

  Future<void> _attachHiveWatcher() async {
    final box = await Hive.openBox(ReportStorageV2.boxName);
    final meta = await Hive.openBox(ReportStorageV2.metaBoxName);

    await _hiveStreamSub?.cancel();
    await _hiveMetaStreamSub?.cancel();

    _hiveStreamSub = box.watch().listen((_) {
      if (!mounted) return;
      setState(() {
        _future = _loadServices(_selYear, _selMonth);
      });
    });

    _hiveMetaStreamSub = meta.watch().listen((_) {
      if (!mounted) return;
      setState(() {
        _future = _loadServices(_selYear, _selMonth);
      });
    });
  }

  @override
  void dispose() {
    _hiveStreamSub?.cancel();
    _hiveMetaStreamSub?.cancel();
    super.dispose();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadServices(int year, int month) {
    // Pentru ecranul „Adaugă / Modifică Serviciu” vrem să vedem toate serviciile
    // care au segmente în luna selectată (nu doar luna canonică salvată în meta).
    // Folosim direct segmentele din storage pentru luna [year, month].
    return ReportStorageV2.listServicesForMonthWithSegments(year, month);
  }

  // ===== Utils =====

  String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  List<Map<String, dynamic>> _mergeMidnightSlices(
      List<Map<String, dynamic>> input) {
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

      if (splitAtMidnight &&
          sameType &&
          sameNo &&
          sameFoaie &&
          sameDesc) {
        cur['end'] = next['end'];
      } else {
        out.add(cur);
        cur = Map<String, dynamic>.from(next);
      }
    }

    out.add(cur);
    return out;
  }

  // ===== Afișare rând segment — IDENTICĂ cu AfisareServicii =====

  String _segmentTypeOnlyLabelFromMap(Map<String, dynamic> m) {
    final type = (m['type'] as String?) ?? '';
    switch (type) {
      case 'tren':
        final raw = (m['trainNo'] as String?)?.trim();
        final no = (raw != null && raw.isNotEmpty) ? raw : '-';
        return 'Tren $no';
      case 'odihna':  return 'Odihnă';
      case 'regie':   return 'Regie';
      case 'mvStatie':return 'MV Stație';
      case 'mvDepou': return 'MV Depou';
      case 'acar':    return 'Acar';
      case 'revizor': return 'Revizor';
      case 'sefTura': return 'Șef Tura';
      case 'alte':
        final d = ((m['desc'] ?? m['description'] ?? '') as String).trim();
        return d.isEmpty ? 'Alte Activități' : d;
      default:
        return type.isEmpty ? 'Segment' : type;
    }
  }

  String _formatIntervalForRow(DateTime s, DateTime e, DateFormat dfRow) {
    final d = DateFormat('dd.MM.yyyy', 'ro_RO');
    final t = DateFormat('HH:mm', 'ro_RO');

    final isMidnight = e.hour == 0 &&
        e.minute == 0 &&
        e.second == 0 &&
        e.millisecond == 0 &&
        e.microsecond == 0;

    final startDay = DateTime(s.year, s.month, s.day);
    final endDay = DateTime(e.year, e.month, e.day);
    final isNextDay = endDay.difference(startDay).inDays == 1;

    if (isMidnight && isNextDay) {
      return '${d.format(s)} - ${t.format(s)} → ${d.format(s)} - 24:00';
    }

    final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
    if (sameDay) {
      return '${d.format(s)} - ${t.format(s)} → ${t.format(e)}';
    } else {
      return '${dfRow.format(s)} → ${dfRow.format(e)}';
    }
  }

  Widget _segmentTitleRichFromMap(BuildContext context, Map<String, dynamic> seg, DateFormat dfRow) {
    final typeLabel = _segmentTypeOnlyLabelFromMap(seg);
    final s = DateTime.parse(seg['start'] as String);
    final e = DateTime.parse(seg['end'] as String);
    final interval = _formatIntervalForRow(s, e, dfRow);
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: typeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: ' — $interval'),
        ],
      ),
    );
  }

  bool _containsMap(Map<String, dynamic> parent, Map<String, dynamic> child) {
    final ps = DateTime.parse(parent['start'] as String);
    final pe = DateTime.parse(parent['end'] as String);
    final cs = DateTime.parse(child['start'] as String);
    final ce = DateTime.parse(child['end'] as String);
    return !cs.isBefore(ps) && !ce.isAfter(pe) && !identical(parent, child);
  }

  List<_MapNode> _buildTreeForDisplay(List<Map<String, dynamic>> segs) {
    if (segs.isEmpty) return const [];
    final list = [...segs]
      ..sort((a, b) {
        final ad = DateTime.parse(a['end']).difference(DateTime.parse(a['start'])).inMinutes;
        final bd = DateTime.parse(b['end']).difference(DateTime.parse(b['start'])).inMinutes;
        final byDur = bd.compareTo(ad);
        if (byDur != 0) return byDur;
        return DateTime.parse(a['start']).compareTo(DateTime.parse(b['start']));
      });

    final usedAsChild = <Map<String, dynamic>>{};
    final nodes = <_MapNode>[];

    for (final p in list) {
      if (usedAsChild.contains(p)) continue;
      final children = <Map<String, dynamic>>[];
      for (final c in list) {
        if (identical(c, p)) continue;
        if (usedAsChild.contains(c)) continue;
        if (_containsMap(p, c)) {
          children.add(c);
          usedAsChild.add(c);
        }
      }
      children.sort((a, b) => DateTime.parse(a['start'] as String)
          .compareTo(DateTime.parse(b['start'] as String)));
      nodes.add(_MapNode(parent: p, children: children));
    }

    nodes.sort((a, b) =>
        DateTime.parse(b.parent['start'] as String)
            .compareTo(DateTime.parse(a.parent['start'] as String)));
    return nodes;
  }

  List<Widget> _buildRowsForDisplay(List<Map<String, dynamic>> segs) {
    final nodes = _buildTreeForDisplay(segs);
    final rows = <Widget>[];
    for (final n in nodes) {
      rows.add(
        ListTile(
          dense: true,
          title: _segmentTitleRichFromMap(context, n.parent, _dfRow),
        ),
      );
      for (final c in n.children) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: ListTile(
              dense: true,
              title: _segmentTitleRichFromMap(context, c, _dfRow),
            ),
          ),
        );
      }
      rows.add(const Divider(height: 1));
    }

    if (rows.isNotEmpty && rows.last is! Divider) {
      rows.add(const Divider(height: 1));
    }

    if (rows.isEmpty) {
      rows.add(const ListTile(dense: true, title: Text('Niciun segment.')));
    }
    return rows;
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
                              final disabled =
                                  (y > now.year) || (y == now.year && mm > now.month);
                              return DropdownMenuItem<int>(
                                value: mm,
                                enabled: !disabled,
                                child: Text(
                                  cap(DateFormat('MMMM', 'ro_RO')
                                      .format(DateTime(2000, mm))),
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
                              final disabled = yy > now.year;
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
                          'Perioada aleasă este în viitor. Selectează luna curentă sau o lună anterioară.',
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
                    child: const Text('Anulează')),
                ElevatedButton(
                  onPressed: (DateTime(y, m).isAfter(DateTime(now.year, now.month)))
                      ? null
                      : () => Navigator.pop(ctx, DateTime(y, m)),
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
        _future = _loadServices(_selYear, _selMonth);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adauga / Modifica Serviciu'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Text('Servicii efectuate in',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _selectMonthYear,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border:
                      Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: IgnorePointer(
                        ignoring: true,
                        child: DropdownButton<int>(
                          value: _selMonth,
                          isDense: true,
                          iconSize: 18,
                          icon: const Icon(Icons.arrow_drop_down),
                          style: Theme.of(context).textTheme.bodyMedium,
                          items: List<int>.generate(12, (i) => i + 1)
                              .map((mm) => DropdownMenuItem<int>(
                            value: mm,
                            child: Text(cap(DateFormat('MMMM', 'ro_RO')
                                .format(DateTime(2000, mm)))),
                          ))
                              .toList(),
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$_selYear',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final services = snap.data ?? const {};
          final entriesSorted = services.entries
              .where((entry) => entry.value.isNotEmpty)
              .toList()
            ..sort((a, b) {
              DateTime maxStartA = a.value
                  .map((m) => DateTime.parse(m['start'] as String))
                  .reduce((p, c) => p.isAfter(c) ? p : c);
              DateTime maxStartB = b.value
                  .map((m) => DateTime.parse(m['start'] as String))
                  .reduce((p, c) => p.isAfter(c) ? p : c);
              return maxStartB.compareTo(maxStartA);
            });

          if (entriesSorted.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Nu există servicii înregistrate pentru perioada selectată.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: entriesSorted.length,
            itemBuilder: (context, idx) {
              final entry = entriesSorted[idx];
              final serviceId = entry.key;

              // merge + sort desc
              final segsMergedDesc = _mergeMidnightSlices(entry.value)
                ..sort((a, b) => DateTime.parse(b['start'] as String)
                    .compareTo(DateTime.parse(a['start'] as String)));

              // subheader (identic cu AfisareServicii)
              final parts = <String>[];
              final segsAsc = [...segsMergedDesc]
                ..sort((a, b) => DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])));
              for (final m in segsAsc) {
                final type = m['type'] as String;
                if (type == 'odihna') continue;
                switch (type) {
                  case 'tren':
                    final raw = (m['trainNo'] as String?)?.trim();
                    if (raw != null && raw.isNotEmpty) parts.add(raw);
                    break;
                  case 'mvStatie':
                    parts.add('MV Stație'); break;
                  case 'mvDepou':
                    parts.add('MV Depou'); break;
                  case 'acar':
                    parts.add('Acar'); break;
                  case 'regie':
                    parts.add('Regie'); break;
                  case 'revizor':
                    parts.add('Revizor'); break;
                  case 'sefTura':
                    parts.add('Șef Tura'); break;
                  case 'alte':
                    final desc = ((m['desc'] ?? m['description'] ?? '') as String).trim();
                    if (desc.isNotEmpty) parts.add(desc);
                    break;
                  default:
                    break;
                }
              }
              final displaySuffix = parts.join(' / ');

              // titlu principal — identic cu AfisareServicii
              final start = DateTime.parse(segsMergedDesc.last['start']);
              final end = DateTime.parse(segsMergedDesc.first['end']);
              final interval = formatServiceTitle(start, end);

              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),

                leading: IconButton(
                  tooltip: 'Editează serviciul',
                  icon: const Icon(Icons.edit, size: 18),
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  onPressed: () async {
                    // La editare vrem să lucrăm pe tot serviciul (toate zilele),
                    // nu doar pe segmentele din luna curentă afișată.
                    final allSegs = await ReportStorageV2.listAllSegmentsForService(serviceId);
                    if (!context.mounted) return;
                    final mergedForEdit = _mergeMidnightSlices(allSegs);
                    final initialSegments = mergedForEdit
                        .map((m) => serviceSegmentFromStorageMap(m))
                        .toList()
                      ..sort((a, b) => b.start.compareTo(a.start));

                    final changed = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdaugaServiciuScreen(
                          initialSegments: initialSegments,
                          initialServiceId: serviceId,
                          initialSuggestedStart: widget.initialSuggestedStart,
                          selYear: _selYear,
                          selMonth: _selMonth,
                        ),
                      ),
                    );

                    if (!context.mounted) return;
                    setState(() => _future = _loadServices(_selYear, _selMonth));
                    if (changed != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Serviciu actualizat.')),
                      );
                    }
                  },
                ),

                title: Text(
                  interval,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: displaySuffix.isEmpty ? null : Text(
                  displaySuffix,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Șterge serviciul',
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      barrierDismissible: true,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Ștergere serviciu'),
                        content: const Text(
                          'Sigur vrei să ștergi acest serviciu? Această acțiune nu poate fi anulată.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Anulează'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Șterge'),
                          ),
                        ],
                      ),
                    );
                    if (!context.mounted) return;
                    if (confirm != true) return;

                    final monthsBefore = await Recalculator.listMonthsTouchedInDailyReports();
                    final storedPhotoPaths = await AdvancedPhotoCleanupService.collectStoredPhotoPathsForService(serviceId);
                    await ReportStorageV2.deleteServiceEverywhere(serviceId);
                    await AdvancedPhotoCleanupService.deletePhotoFiles(storedPhotoPaths);
                    final monthsAfter = await Recalculator.listMonthsTouchedInDailyReports();
                    final monthsToRecalc = <String>{...monthsBefore, ...monthsAfter};
                    await Recalculator.reaggregateAndWriteMonthlyTotals(months: monthsToRecalc);
                    await Recalculator.recalcMonthlyOvertimeForMonths(monthsToRecalc);
                    if (!context.mounted) return;
                    setState(() => _future = _loadServices(_selYear, _selMonth));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Serviciu șters.')),
                    );
                  },
                ),
                children: [
                  ..._buildRowsForDisplay(entry.value),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final changed = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdaugaServiciuScreen(
                          initialSuggestedStart: widget.initialSuggestedStart,
                          selYear: _selYear,
                          selMonth: _selMonth,
                        ),
                      ),
                    );
                    if (!context.mounted) return;
                    setState(() => _future = _loadServices(_selYear, _selMonth));
                    if (changed != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Serviciu adăugat.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Adaugă Serviciu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ——— helper pt. arbore părinte–copii (afișare)
class _MapNode {
  final Map<String, dynamic> parent;
  final List<Map<String, dynamic>> children;
  const _MapNode({required this.parent, required this.children});
}
