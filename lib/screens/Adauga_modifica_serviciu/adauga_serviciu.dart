// lib/screens/Adauga_modifica_serviciu/adauga_serviciu.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:foaie_prestatii_mvp/calcule_ore/api.dart';
import 'nume_serviciu.dart' show buildServiceNameFromSegments, segmentTitleRichFromMap;

import '../../models/service_segment.dart';
import '../../services/report_storage_v2.dart';
import '../../services/advanced_photo_cleanup_service.dart';
import 'adauga_segment.dart'; // B → C
import '../../services/recalculator.dart';

/// Ecran editor pentru UN serviciu:
/// - Listă ierarhică (segmente NORMAL; copii indentați)
/// - Butoane: „Adaugă segment” + „Salvează serviciul”
class AdaugaServiciuScreen extends StatefulWidget {
  final List<ServiceSegment>? initialSegments;
  final String? initialServiceId;
  final DateTime? initialSuggestedStart;

  /// limitări pentru pickere (luna selectată din ecranul A)
  final int selYear;
  final int selMonth;

  const AdaugaServiciuScreen({
    super.key,
    this.initialSegments,
    this.initialServiceId,
    this.initialSuggestedStart,
    required this.selYear,
    required this.selMonth,
  });

  @override
  State<AdaugaServiciuScreen> createState() => _AdaugaServiciuScreenState();
}

class _AdaugaServiciuScreenState extends State<AdaugaServiciuScreen> {
  DateTime get _nowCap => DateTime.now();
  DateTime get _futureCap => _nowCap.add(const Duration(hours: 2));

  bool _saving = false;
  final List<ServiceSegment> _segments = [];

  bool _serviceCommitted = false;
  final Set<String> _initialServicePhotoPaths = <String>{};

  DateTime? _lastPickedTrainDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialSegments != null && widget.initialSegments!.isNotEmpty) {
      _segments
        ..clear()
        ..addAll(widget.initialSegments!)
        ..sort((a, b) => b.start.compareTo(a.start));
      _initialServicePhotoPaths
        ..clear()
        ..addAll(
          AdvancedPhotoCleanupService.collectPhotoPathsFromServiceSegments(
            widget.initialSegments!,
          ),
        );
    }
  }

  @override
  void dispose() {
    if (!_serviceCommitted) {
      final currentPhotoPaths = AdvancedPhotoCleanupService
          .collectPhotoPathsFromServiceSegments(_segments);
      final toDelete = currentPhotoPaths.difference(_initialServicePhotoPaths);
      if (toDelete.isNotEmpty) {
        AdvancedPhotoCleanupService.deletePhotoFiles(toDelete);
      }
    }
    super.dispose();
  }

  DateTime get _monthFirst {
    // Dacă avem deja segmente, limităm intervalul la ziua de început a serviciului,
    // ca să permitem editarea corectă a serviciilor care trec peste lună.
    if (_segments.isNotEmpty) {
      final minStart = _segments.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
      return DateTime(minStart.year, minStart.month, minStart.day);
    }
    // Pentru servicii noi, permitem și ultima zi din luna precedentă,
    // ca să poată fi introdus un serviciu început înainte de miezul nopții
    // și continuat în luna selectată.
    return DateTime(widget.selYear, widget.selMonth, 0);
  }

  DateTime get _monthLast {
    // Pentru servicii existente, permitem editarea până la sfârșitul **zilei următoare**
    // față de ultima zi în care există deja segmente — ca să poți adăuga segmente
    // care trec de la 23:xx în ziua următoare (ex. 23:50 → 04:50).
    if (_segments.isNotEmpty) {
      final maxEnd =
      _segments.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);
      final nextDay = DateTime(maxEnd.year, maxEnd.month, maxEnd.day)
          .add(const Duration(days: 1));
      return DateTime(nextDay.year, nextDay.month, nextDay.day, 23, 59);
    }
    // Pentru servicii noi, permitem intervale care pot trece în prima zi a lunii următoare.
    return DateTime(widget.selYear, widget.selMonth + 1, 1, 23, 59);
  }

  String _newServiceId() {
    final n = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(1 << 32);
    return 'svc_${n}_$r';
  }

  Set<String> _photoPathsForSegment(ServiceSegment segment) {
    final raw = segment.advancedPhotoPaths;
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }

    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> _deleteSessionOnlyPhotoPaths(Iterable<String> paths) async {
    final toDelete = paths
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !_initialServicePhotoPaths.contains(e))
        .toSet();

    if (toDelete.isEmpty) {
      return;
    }

    await AdvancedPhotoCleanupService.deletePhotoFiles(toDelete);
  }

  Map<String, int> _emptyTotals() => emptyTotals();

  Map<String, int> _totalsForSlice({
    required SegmentType type,
    required DateTime start,
    required DateTime end,
  }) {
    final typeKey = segmentTypeToStorage(type);
    return totalsForSlice(
      typeKey: typeKey,
      start: start,
      end: end,
      holidays: kRomanianLegalHolidays,
    );
  }

  int _storageTypePriority(String t) {
    switch (t) {
      case 'tren':
        return 100;
      case 'mvStatie':
        return 90;
      case 'mvDepou':
        return 90;
      case 'revizor':
        return 80;
      case 'sefTura':
        return 80;
      case 'acar':
        return 70;
      case 'regie':
        return 60;
      case 'alte':
        return 60;
      case 'odihna':
        return 10;
      default:
        return 0;
    }
  }

  List<Map<String, dynamic>> _normalizeNonOverlappingStorageSlices(
      List<Map<String, dynamic>> segs) {
    if (segs.isEmpty) return const [];

    final boundaries = <DateTime>{};
    for (final s in segs) {
      boundaries.add(DateTime.parse(s['start'] as String));
      boundaries.add(DateTime.parse(s['end'] as String));
    }
    final xs = boundaries.toList()..sort();

    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < xs.length - 1; i++) {
      final a = xs[i], b = xs[i + 1];
      if (!b.isAfter(a)) continue;

      final active = segs.where((s) {
        final ss = DateTime.parse(s['start'] as String);
        final ee = DateTime.parse(s['end'] as String);
        return !a.isBefore(ss) && a.isBefore(ee);
      }).toList();
      if (active.isEmpty) continue;

      active.sort((x, y) =>
          _storageTypePriority(y['type'] as String).compareTo(_storageTypePriority(x['type'] as String)));
      final top = active.first;

      out.add({
        'type': top['type'],
        'trainNo': (top['type'] == 'tren') ? top['trainNo'] : null,
        'desc': (top['type'] == 'alte') ? (top['desc'] ?? top['description']) : null,
        'start': a.toIso8601String(),
        'end': b.toIso8601String(),
      });
    }

    // merge bucăți adiacente
    List<Map<String, dynamic>> mergeMidnight(List<Map<String, dynamic>> input) {
      if (input.isEmpty) return const [];
      final sorted = [...input]
        ..sort((a, b) =>
            DateTime.parse(a['start'] as String).compareTo(DateTime.parse(b['start'] as String)));
      final out = <Map<String, dynamic>>[];
      Map<String, dynamic> cur = Map<String, dynamic>.from(sorted.first);

      bool sameTrain(String? a, String? b) => (a ?? '').trim() == (b ?? '').trim();
      bool sameDesc(String? a, String? b) => (a ?? '').trim() == (b ?? '').trim();

      for (int i = 1; i < sorted.length; i++) {
        final next = sorted[i];
        final curEnd = DateTime.parse(cur['end'] as String);
        final nextStart = DateTime.parse(next['start'] as String);
        final touches = nextStart.isAtSameMomentAs(curEnd);

        final sameType = (cur['type'] as String) == (next['type'] as String);
        final sameNo = sameTrain(cur['trainNo'] as String?, next['trainNo'] as String?);
        final sameDescription = sameDesc(cur['desc'] as String?, next['desc'] as String?);

        final canMerge = sameType &&
            touches &&
            ((cur['type'] == 'tren' && sameNo) ||
                (cur['type'] == 'alte' && sameDescription) ||
                (cur['type'] != 'tren' && cur['type'] != 'alte'));

        if (canMerge) {
          cur['end'] = next['end'];
        } else {
          out.add(cur);
          cur = Map<String, dynamic>.from(next);
        }
      }
      out.add(cur);
      return out;
    }

    return mergeMidnight(out);
  }

  DateTime _clampToBounds(DateTime dt) {
    var out = dt;
    if (out.isBefore(_monthFirst)) out = _monthFirst;
    if (out.isAfter(_monthLast)) out = _monthLast;
    if (out.isAfter(_futureCap)) out = _futureCap;
    return out;
  }

  DateTime _suggestStartForAdd() {
    if (_segments.isNotEmpty) {
      final latestEnd = _segments.map((s) => s.end).reduce((p, c) => p.isAfter(c) ? p : c);
      return _clampToBounds(latestEnd);
    }
    if (_lastPickedTrainDate != null) {
      final d = _lastPickedTrainDate!;
      final reuse = DateTime(d.year, d.month, d.day, 7, 0);
      return _clampToBounds(reuse);
    }
    final base = DateTime(_monthFirst.year, _monthFirst.month, _monthFirst.day, 7, 0);
    final today07 = DateTime(_nowCap.year, _nowCap.month, _nowCap.day, 7, 0);
    final candidate = base.isBefore(today07) ? today07 : base;
    return _clampToBounds(candidate);
  }

  bool _intervalsOverlap(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
  }

  String _formatDateTimeInterval(DateTime start, DateTime end) {
    final df = DateFormat('dd.MM.yyyy HH:mm', 'ro_RO');
    return '${df.format(start)} - ${df.format(end)}';
  }

  String _segmentLabel(ServiceSegment s) {
    if (s.type == SegmentType.tren) {
      final no = (s.trainNo ?? '').trim();
      return no.isEmpty ? 'tren' : 'tren $no';
    }
    if (s.type == SegmentType.alte) {
      final d = (s.otherDesc ?? '').trim();
      return d.isEmpty ? 'alte activități' : 'alte activități: $d';
    }
    return _typeShort(s.type);
  }

  String? _findOverlapWithCurrentSegments(ServiceSegment candidate, {int? ignoreIndex}) {
    final segStart = candidate.start;
    final segEnd = candidate.end;
    if (!segEnd.isAfter(segStart)) {
      return 'Interval invalid: ora de final trebuie să fie după ora de început.';
    }

    for (int i = 0; i < _segments.length; i++) {
      if (ignoreIndex != null && i == ignoreIndex) continue;
      final other = _segments[i];

      final overlaps = _intervalsOverlap(segStart, segEnd, other.start, other.end);
      if (!overlaps) continue;

      final otherLabel = _segmentLabel(other);
      final otherInterval = _formatDateTimeInterval(other.start, other.end);
      return 'Nu pot adăuga/edita segmentul "${_segmentLabel(candidate)}" (${_formatDateTimeInterval(segStart, segEnd)}) deoarece se suprapune cu segmentul existent "$otherLabel" ($otherInterval). Segmentele din același serviciu nu au voie să se intersecteze; pot doar să se atingă la limită (ex. 10:00–12:00 și 12:00–13:00).';
    }

    return null;
  }

  String? _findAnyOverlapInCurrentService() {
    for (int i = 0; i < _segments.length; i++) {
      final a = _segments[i];
      if (!a.end.isAfter(a.start)) {
        final aLabel = _segmentLabel(a);
        final aInterval = _formatDateTimeInterval(a.start, a.end);
        return 'Există un segment cu interval invalid: $aLabel ($aInterval). Nu poți salva serviciul.';
      }
      for (int j = i + 1; j < _segments.length; j++) {
        final b = _segments[j];
        if (!b.end.isAfter(b.start)) {
          final bLabel = _segmentLabel(b);
          final bInterval = _formatDateTimeInterval(b.start, b.end);
          return 'Există un segment cu interval invalid: $bLabel ($bInterval). Nu poți salva serviciul.';
        }

        final overlaps = _intervalsOverlap(a.start, a.end, b.start, b.end);
        if (!overlaps) continue;

        final aLabel = _segmentLabel(a);
        final bLabel = _segmentLabel(b);
        final aInterval = _formatDateTimeInterval(a.start, a.end);
        final bInterval = _formatDateTimeInterval(b.start, b.end);

        return 'Nu poți salva serviciul: există suprapunere între segmentele:\n\n- $aLabel ($aInterval)\n- $bLabel ($bInterval)\n\nSegmentele trebuie să fie disjuncte (se pot atinge doar la limită). Editează orele astfel încât sfârșitul unuia să fie <= începutul celuilalt, sau șterge segmentul conflictual.';
      }
    }
    return null;
  }

  Future<String?> findOverlapWithExistingServices(ServiceSegment seg) async {
    final DateTime segStart = seg.start;
    final DateTime segEnd = seg.end;
    if (!segEnd.isAfter(segStart)) {
      return null;
    }

    final List<Map<String, int>> months = <Map<String, int>>[];
    int year = segStart.year;
    int month = segStart.month;
    while (true) {
      months.add({'year': year, 'month': month});
      if (year == segEnd.year && month == segEnd.month) {
        break;
      }
      if (month == 12) {
        year += 1;
        month = 1;
      } else {
        month += 1;
      }
      if (months.length > 24) {
        break;
      }
    }

    final Map<String, List<Map<String, dynamic>>> byService =
    <String, List<Map<String, dynamic>>>{};

    for (final Map<String, int> ym in months) {
      final int y = ym['year']!;
      final int m = ym['month']!;
      final monthServices =
      await ReportStorageV2.listServicesForMonthWithSegments(y, m);
      monthServices.forEach((String serviceId, List<Map<String, dynamic>> segs) {
        if (widget.initialServiceId != null &&
            serviceId == widget.initialServiceId) {
          return;
        }
        final list =
        byService.putIfAbsent(serviceId, () => <Map<String, dynamic>>[]);
        list.addAll(segs);
      });
    }

    String? conflictServiceId;
    DateTime? conflictStart;
    bool found = false;

    for (final entry in byService.entries) {
      final String serviceId = entry.key;
      final List<Map<String, dynamic>> segs = entry.value;
      for (final s in segs) {
        final dynamic startValue = s['start'];
        final dynamic endValue = s['end'];
        if (startValue is! String || endValue is! String) {
          continue;
        }
        final DateTime otherStart = DateTime.parse(startValue);
        final DateTime otherEnd = DateTime.parse(endValue);
        if (!otherEnd.isAfter(otherStart)) {
          continue;
        }
        final bool overlaps =
            segStart.isBefore(otherEnd) && segEnd.isAfter(otherStart);
        if (overlaps) {
          conflictServiceId = serviceId;
          conflictStart = otherStart;
          found = true;
          break;
        }
      }
      if (found) {
        break;
      }
    }

    if (!found || conflictServiceId == null) {
      return null;
    }

    final String? name =
    await ReportStorageV2.getServiceName(conflictServiceId);
    final String serviceLabel;
    if (name != null && name.trim().isNotEmpty) {
      serviceLabel = name.trim();
    } else {
      serviceLabel = 'serviciul $conflictServiceId';
    }

    final DateTime labelDate = conflictStart ?? segStart;
    final String dateLabel = DateFormat('dd.MM.yyyy').format(labelDate);

    return 'Nu pot adăuga/edita segmentul "${_segmentLabel(seg)}" (${_formatDateTimeInterval(segStart, segEnd)}) deoarece se suprapune cu $serviceLabel deja înregistrat (există cel puțin un segment în acel serviciu pe data de $dateLabel care intersectează intervalul propus). Nu sunt permise suprapuneri peste servicii existente.';
  }

  Future<void> _addSegment() async {
    ServiceSegment? previous;
    if (_segments.isNotEmpty) {
      // Considerăm „anterior” segmentul care se termină cel mai târziu,
      // adică ultimul din serviciu din punct de vedere cronologic.
      previous = _segments.reduce(
            (a, b) => a.end.isAfter(b.end) ? a : b,
      );
    }

    final seg = await showAdaugaSegmentDialog(
      context,
      previous: previous,
      suggestedStart: _suggestStartForAdd(),
      isFirstInService: _segments.isEmpty, // <<< NOU: informăm dialogul dacă acesta e primul segment din serviciu
      nowCap: _nowCap,
      monthFirst: _monthFirst,
      monthLast: _monthLast,
    );
    if (seg == null) return;

    final segPhotoPaths = _photoPathsForSegment(seg);

    final String? overlapInService = _findOverlapWithCurrentSegments(seg);
    if (!mounted) {
      await _deleteSessionOnlyPhotoPaths(segPhotoPaths);
      return;
    }
    if (overlapInService != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Suprapunere segmente'),
          content: Text(overlapInService),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await _deleteSessionOnlyPhotoPaths(segPhotoPaths);
      return;
    }
    final String? overlapWarning = await findOverlapWithExistingServices(seg);
    if (!mounted) {
      await _deleteSessionOnlyPhotoPaths(segPhotoPaths);
      return;
    }
    if (overlapWarning != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Suprapunere servicii'),
          content: Text(overlapWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await _deleteSessionOnlyPhotoPaths(segPhotoPaths);
      return;
    }

    setState(() {
      if (seg.type == SegmentType.tren) _lastPickedTrainDate = seg.start;
      _segments.add(seg);
      _segments.sort((a, b) => b.start.compareTo(a.start));
    });
  }

  Future<void> _editSegment(int index) async {
    final seg = _segments[index];
    final oldPhotoPaths = _photoPathsForSegment(seg);
    final edited = await showAdaugaSegmentDialog(
      context,
      initial: seg,
      suggestedStart: seg.start,
      isFirstInService: false, // <<< NOU: la editare nu e „primul”
      nowCap: _nowCap,
      monthFirst: _monthFirst,
      monthLast: _monthLast,
    );
    if (edited == null) return;

    final editedPhotoPaths = _photoPathsForSegment(edited);
    final rejectedNewPhotoPaths = editedPhotoPaths.difference(oldPhotoPaths);

    final String? overlapInService = _findOverlapWithCurrentSegments(edited, ignoreIndex: index);
    if (!mounted) {
      await _deleteSessionOnlyPhotoPaths(rejectedNewPhotoPaths);
      return;
    }
    if (overlapInService != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Suprapunere segmente'),
          content: Text(overlapInService),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await _deleteSessionOnlyPhotoPaths(rejectedNewPhotoPaths);
      return;
    }

    final String? overlapWarning = await findOverlapWithExistingServices(edited);
    if (!mounted) {
      await _deleteSessionOnlyPhotoPaths(rejectedNewPhotoPaths);
      return;
    }
    if (overlapWarning != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Suprapunere servicii'),
          content: Text(overlapWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await _deleteSessionOnlyPhotoPaths(rejectedNewPhotoPaths);
      return;
    }

    final newPhotoPaths = _photoPathsForSegment(edited);
    final removedPhotoPaths = oldPhotoPaths.difference(newPhotoPaths);
    await _deleteSessionOnlyPhotoPaths(removedPhotoPaths);

    setState(() {
      if (edited.type == SegmentType.tren) _lastPickedTrainDate = edited.start;
      _segments[index] = edited;
      _segments.sort((a, b) => b.start.compareTo(a.start));
    });
  }

  Future<void> _deleteSegment(int index) async {
    final removedSegment = _segments[index];
    final removedPhotoPaths = _photoPathsForSegment(removedSegment);

    setState(() {
      _segments.removeAt(index);
    });

    await _deleteSessionOnlyPhotoPaths(removedPhotoPaths);
  }

  Future<void> _saveService() async {
    if (_saving) return;

    final bool isEdit = widget.initialServiceId != null;

    // Flux separat pentru cazurile fără segmente, înainte de a porni salvarea propriu-zisă.
    if (isEdit) {
      // MODIFICARE serviciu
      if (_segments.isEmpty) {
        // Toate foile/segmentele au fost șterse în editor.
        // Avertizăm clar că salvarea fără segmente va duce la ștergerea serviciului.
        final deleteConfirm = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Text('Ștergere serviciu'),
            content: const Text(
              'Nu ai niciun segment/foaie în acest serviciu. Dacă continui, întregul serviciu va fi șters. Vrei să continui?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Anulează'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Șterge serviciul'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (deleteConfirm != true) return;

        // Ștergem efectiv serviciul din Hive.
        setState(() => _saving = true);
        try {
          final String serviceId = widget.initialServiceId!;
          final monthsBefore = await Recalculator.listMonthsTouchedInDailyReports();
          final storedPhotoPaths = await AdvancedPhotoCleanupService.collectStoredPhotoPathsForService(serviceId);
          await ReportStorageV2.deleteServiceEverywhere(serviceId);
          await AdvancedPhotoCleanupService.deletePhotoFiles(storedPhotoPaths);
          final monthsAfter = await Recalculator.listMonthsTouchedInDailyReports();
          final monthsToRecalc = <String>{...monthsBefore, ...monthsAfter};
          await Recalculator.reaggregateAndWriteMonthlyTotals(months: monthsToRecalc);
          await Recalculator.recalcMonthlyOvertimeForMonths(monthsToRecalc);
          _serviceCommitted = true;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Serviciu șters.')),
          );
          Navigator.pop(context, null);
        } finally {
          if (mounted) setState(() => _saving = false);
        }
        return;
      } else {
        // MODIFICARE cu segmente prezente → confirmăm salvarea modificărilor.
        final confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmă salvarea'),
            content: const Text('Modificările acestui serviciu vor fi salvate. Continui?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Renunță'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Salvează'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirm != true) return;
        // Dacă s-a confirmat, continuăm mai jos cu salvarea standard.
      }
    } else {
      // ADĂUGARE serviciu nou
      if (_segments.isEmpty) {
        // Nu s-a adăugat niciun segment: ieșim direct fără să atingem Hive.
        if (mounted) {
          Navigator.pop(context, null);
        }
        return;
      }
      // Dacă există segmente, continuăm mai jos cu salvarea standard, fără confirmare.
    }

    // De aici în jos avem întotdeauna cel puțin un segment,
    // iar confirmările (unde era cazul) au fost deja acceptate.

    final String? overlapInService = _findAnyOverlapInCurrentService();
    if (!mounted) return;
    if (overlapInService != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Suprapunere segmente'),
          content: Text(overlapInService),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    for (final seg in _segments) {
      final String? overlapWarning = await findOverlapWithExistingServices(seg);
      if (!mounted) return;
      if (overlapWarning != null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Suprapunere servicii'),
            content: Text(overlapWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final writeList = [..._segments]..sort((a, b) => a.start.compareTo(b.start));
      final String serviceId = widget.initialServiceId ?? _newServiceId();
      final newPhotoPaths = AdvancedPhotoCleanupService.collectPhotoPathsFromServiceSegments(writeList);
      Set<String> oldStoredPhotoPaths = <String>{};
      // ——— PĂSTRĂM luna canonică la editare
      String? prevCanonicalMonth;
      final monthsBeforeDelete = <String>{};
      if (widget.initialServiceId != null) {
        prevCanonicalMonth = await ReportStorageV2.getServiceMonth(serviceId);
        final oldSegs = await ReportStorageV2.listAllSegmentsForService(serviceId);
        oldStoredPhotoPaths = AdvancedPhotoCleanupService.collectPhotoPathsFromStorageSegments(oldSegs);
        for (final s in oldSegs) {
          final start = (s['start'] as String);
          monthsBeforeDelete.add(start.substring(0, 7));
        }
        await ReportStorageV2.deleteServiceEverywhere(serviceId);
      }

      final Map<String, List<Map<String, dynamic>>> daySegments = {};
      final dayKeyFmt = DateFormat('yyyy-MM-dd');

      for (final seg in writeList) {
        DateTime curStart = seg.start;
        final segEnd = seg.end;

        while (curStart.isBefore(segEnd)) {
          final nextMidnight =
          DateTime(curStart.year, curStart.month, curStart.day + 1);
          final curEnd = segEnd.isBefore(nextMidnight) ? segEnd : nextMidnight;
          final dayKey = dayKeyFmt.format(curStart);

          daySegments.putIfAbsent(dayKey, () => <Map<String, dynamic>>[]);
          daySegments[dayKey]!.add(
            serviceSegmentToStorageMap(
              seg,
              startOverride: curStart,
              endOverride: curEnd,
            ),
          );

          curStart = curEnd;
        }
      }

      for (final entry in daySegments.entries) {
        final dayKey = entry.key;

        final norm = _normalizeNonOverlappingStorageSlices(entry.value);

        final totals = _emptyTotals();
        for (final m in norm) {
          final t = storageToSegmentType(m['type'] as String);
          final s = DateTime.parse(m['start'] as String);
          final e = DateTime.parse(m['end'] as String);
          final sliceTotals = _totalsForSlice(type: t, start: s, end: e);
          sliceTotals.forEach((k, v) {
            totals[k] = (totals[k] ?? 0) + v;
          });
        }

        await ReportStorageV2.writeDaySegmentsForService(dayKey, serviceId, entry.value);
        await ReportStorageV2.writeDayForService(dayKey, serviceId, totals);
      }

      // Agregare lunară + recalcul suplimentare pentru lunile atinse de acest serviciu
      final monthsAffected = daySegments.keys.map((d) => d.substring(0, 7)).toSet();
      final monthsToRecalc = <String>{...monthsBeforeDelete, ...monthsAffected};
      if (monthsToRecalc.isNotEmpty) {
        await Recalculator.reaggregateAndWriteMonthlyTotals(months: monthsToRecalc);
        await Recalculator.recalcMonthlyOvertimeForMonths(monthsToRecalc);
      }
      final removedStoredPhotoPaths = oldStoredPhotoPaths.difference(newPhotoPaths);
      if (removedStoredPhotoPaths.isNotEmpty) {
        await AdvancedPhotoCleanupService.deletePhotoFiles(removedStoredPhotoPaths);
      }
      // --- CALCUL NUME DE SERVICIU & SALVARE META -----------------
      final segMapsForName = [..._segments]..sort((a, b) => a.start.compareTo(b.start));
      final computedName = buildServiceNameFromSegments(segMapsForName.map((s) => {
        'type': segmentTypeToStorage(s.type),
        'start': s.start.toIso8601String(),
        'end': s.end.toIso8601String(),
        if (s.type == SegmentType.tren) 'trainNo': (s.trainNo ?? '').trim(),
        if (s.type == SegmentType.alte) 'desc': (s.otherDesc ?? '').trim(),
      }).toList());
      await ReportStorageV2.setServiceName(serviceId, computedName);
      // --------------------------------------------------------------

      /// ——— SETĂM luna canonică în meta (păstrează la editare, setează la creare)
      // IMPORTANT: la editare, după deleteServiceEverywhere() meta a fost ștearsă,
      // deci trebuie să re-scriem luna canonică (altfel serviciul dispare din listă).
      final canonicalMonth = (prevCanonicalMonth != null && prevCanonicalMonth.isNotEmpty)
          ? prevCanonicalMonth
          : DateFormat('yyyy-MM').format(DateTime(widget.selYear, widget.selMonth, 1));
      await ReportStorageV2.setServiceMonth(serviceId, canonicalMonth);
      _serviceCommitted = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviciu salvat.')),
        );
      }
      if (!mounted) return;
      // Întoarcem lista actualizată către A
      Navigator.pop(context, _segments);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Construiește RichText „tip — interval” identic cu Afisare Servicii, pentru un segment.
  Widget segmentTitleRichForSegment(BuildContext context, ServiceSegment s) {
    final dfRow = DateFormat('dd.MM.yyyy - HH:mm', 'ro_RO');
    final map = {
      'type': segmentTypeToStorage(s.type),
      'trainNo': s.type == SegmentType.tren ? (s.trainNo ?? '').trim() : null,
      'desc': s.type == SegmentType.alte ? (s.otherDesc ?? '').trim() : null,
      'start': s.start.toIso8601String(),
      'end': s.end.toIso8601String(),
    };
    return segmentTitleRichFromMap(context, map, dfRow);
  }

  String _typeShort(SegmentType t) {
    switch (t) {
      case SegmentType.tren:
        return 'tren';
      case SegmentType.odihna:
        return 'odihnă';
      case SegmentType.regie:
        return 'regie';
      case SegmentType.mvStatie:
        return 'mv stație';
      case SegmentType.mvDepou:
        return 'mv depou';
      case SegmentType.acar:
        return 'acar';
      case SegmentType.revizor:
        return 'revizor';
      case SegmentType.sefTura:
        return 'șef tura';
      case SegmentType.alte:
        return 'alte activități';
    }
  }

  bool _contains(ServiceSegment parent, ServiceSegment child) {
    return !child.start.isBefore(parent.start) && !child.end.isAfter(parent.end) && (parent != child);
  }

  List<_SegNode> _buildTreeFor(List<ServiceSegment> segs) {
    if (segs.isEmpty) return const [];
    final list = [...segs]
      ..sort((a, b) {
        final durB = b.end.difference(b.start).inMinutes;
        final durA = a.end.difference(a.start).inMinutes;
        final byDur = durB.compareTo(durA);
        if (byDur != 0) return byDur;
        return a.start.compareTo(b.start);
      });

    final usedAsChild = <ServiceSegment>{};
    final nodes = <_SegNode>[];

    for (final p in list) {
      if (usedAsChild.contains(p)) continue;
      final children = <ServiceSegment>[];
      for (final c in list) {
        if (c == p) continue;
        if (usedAsChild.contains(c)) continue;
        if (_contains(p, c)) {
          children.add(c);
          usedAsChild.add(c);
        }
      }
      children.sort((a, b) => a.start.compareTo(b.start));
      nodes.add(_SegNode(parent: p, children: children));
    }

    nodes.sort((a, b) => b.parent.start.compareTo(a.parent.start));
    return nodes;
  }

  List<Widget> _buildEditorRows(BuildContext context) {
    if (_segments.isEmpty) {
      return const [
        ListTile(
          title: Text('Nicio foaie adăugată încă.'),
          subtitle: Text('Apasă „Adaugă segment” pentru a începe.'),
        ),
      ];
    }
    final nodes = _buildTreeFor(_segments);
    final rows = <Widget>[];

    for (final n in nodes) {
      // Părinte — NORMAL
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: segmentTitleRichForSegment(context, n.parent)),
              IconButton(
                tooltip: 'Editează ${_typeShort(n.parent.type)}',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editSegment(_segments.indexOf(n.parent)),
              ),
              IconButton(
                tooltip: 'Șterge ${_typeShort(n.parent.type)}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteSegment(_segments.indexOf(n.parent)),
              ),
            ],
          ),
        ),
      );

      // Copii — NORMAL + indentare
      for (final c in n.children) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: segmentTitleRichForSegment(context, c)),
                  IconButton(
                    tooltip: 'Editează ${_typeShort(c.type)}',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editSegment(_segments.indexOf(c)),
                  ),
                  IconButton(
                    tooltip: 'Șterge ${_typeShort(c.type)}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteSegment(_segments.indexOf(c)),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      rows.add(const Divider(height: 1));
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
    DateFormat('MMMM yyyy', 'ro_RO').format(DateTime(widget.selYear, widget.selMonth));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaugă Serviciu'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Servicii efectuate in luna: ${monthLabel[0].toUpperCase()}${monthLabel.substring(1)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: _buildEditorRows(context),
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
                child: OutlinedButton.icon(
                  onPressed: _addSegment,
                  icon: const Icon(Icons.add),
                  label: const Text('Adaugă segment'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveService,
                  icon: _saving
                      ? const SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Se salvează...' : 'Salvează serviciul'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegNode {
  final ServiceSegment parent;
  final List<ServiceSegment> children;
  const _SegNode({required this.parent, required this.children});
}