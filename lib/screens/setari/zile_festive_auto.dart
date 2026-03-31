// /lib/screens/setari/zile_festive_auto.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/zile_festive_api_service.dart';

class ZileFestiveAuto {
  final ZileFestiveApiService service;

  ZileFestiveAuto({ZileFestiveApiService? service})
      : service = service ?? ZileFestiveApiService();

  /// Grupează date consecutive în același an/lună: [1,2] -> "1–2 ianuarie",
  /// zi singulară -> "24 ianuarie" etc.
  List<List<DateTime>> _compressConsecutive(List<DateTime> dates) {
    final list = dates.toList()..sort((a, b) => a.compareTo(b));
    final ranges = <List<DateTime>>[];
    if (list.isEmpty) return ranges;
    var start = DateTime(list.first.year, list.first.month, list.first.day);
    var prev = start;
    for (var i = 1; i < list.length; i++) {
      final d = DateTime(list[i].year, list[i].month, list[i].day);
      final consecutive = d.difference(prev).inDays == 1 &&
          d.month == prev.month &&
          d.year == prev.year;
      if (consecutive) {
        prev = d;
      } else {
        ranges.add([start, prev]);
        start = d;
        prev = d;
      }
    }
    ranges.add([start, prev]);
    return ranges;
  }

  String _formatRangeRo(List<DateTime> range) {
    final s = range.first;
    final e = range.last;
    final monthName = DateFormat.MMMM('ro_RO');
    if (s.year != e.year) {
      final ms = monthName.format(s).toLowerCase();
      final me = monthName.format(e).toLowerCase();
      return '${s.day} $ms – ${e.day} $me';
    }
    if (s.month != e.month) {
      final ms = monthName.format(s).toLowerCase();
      final me = monthName.format(e).toLowerCase();
      return '${s.day} $ms – ${e.day} $me';
    }
    final m = monthName.format(s).toLowerCase();
    if (s.isAtSameMomentAs(e)) {
      return '${s.day} $m';
    }
    return '${s.day}–${e.day} $m';
  }

  /// Detectează zilele festive pentru [year], grupează pe surse și cere confirmare.
  /// Dacă [replaceWholeYear] este true, întoarce lista completă detectată pentru anul selectat.
  /// Dacă [replaceWholeYear] este false, întoarce doar zilele care nu există deja în [existing].
  Future<List<DateTime>> getNewDatesAndAskConfirm(
      BuildContext context, {
        required int year,
        required Iterable<DateTime> existing,
        bool replaceWholeYear = false,
      }) async {
    // preluăm cu surse, ca să putem grupa pe surse în dialog
    final items = await service.getZileFestiveWithSources(year);
    if (!context.mounted) return <DateTime>[];

    final existingSet =
    existing.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    final candidateItems = replaceWholeYear
        ? items.where((it) => it.date.year == year).toList()
        : items
        .where((it) =>
    it.date.year == year &&
        !existingSet.contains(
            DateTime(it.date.year, it.date.month, it.date.day)))
        .toList();

    if (candidateItems.isEmpty) {
      return <DateTime>[];
    }

    // Grupăm pe surse majore:
    //  - Codul muncii (art. 139) — zile fixe
    //  - Contractul colectiv de muncă — 16 februarie
    //  - Codul muncii — Paște/Rusalii (Meeus) — toate mobilele
    final byLawFixed = <DateTime>[];
    final byCcmFixed = <DateTime>[];
    final byEaster = <DateTime>[];

    for (final it in candidateItems) {
      final d = DateTime(it.date.year, it.date.month, it.date.day);
      switch (it.category) {
        case 'law_fixed':
          byLawFixed.add(d);
          break;
        case 'ccm_fixed':
          byCcmFixed.add(d);
          break;
        case 'law_good_friday':
        case 'law_easter':
        case 'law_easter_monday':
        case 'law_pentecost':
        case 'law_pentecost_monday':
          byEaster.add(d);
          break;
        default:
          byLawFixed.add(d);
      }
    }

    // Construim secțiunile (doar cele care au conținut)
    final sections = <_SourceSection>[];

    if (byLawFixed.isNotEmpty) {
      final ranges = _compressConsecutive(
          byLawFixed.toSet().toList()..sort((a, b) => a.compareTo(b)));
      sections.add(_SourceSection(
        title: 'Zile legale (Codul muncii)',
        ranges: ranges,
        sourceLines: const ['Sursa: Codul muncii (art. 139)'],
      ));
    }

    if (byCcmFixed.isNotEmpty) {
      final ranges = _compressConsecutive(
          byCcmFixed.toSet().toList()..sort((a, b) => a.compareTo(b)));
      sections.add(_SourceSection(
        title: 'Zile speciale (CCM)',
        ranges: ranges,
        sourceLines: const ['Sursa: Contractul colectiv de muncă — 16 februarie'],
      ));
    }

    if (byEaster.isNotEmpty) {
      final ranges = _compressConsecutive(
          byEaster.toSet().toList()..sort((a, b) => a.compareTo(b)));
      sections.add(_SourceSection(
        title: 'Zile legale (Paște / Rusalii)',
        ranges: ranges,
        sourceLines: const [
          'Sursa: Codul muncii — Paștele/Rusaliile calculate conform algoritmului Meeus (Paștele ortodox)'
        ],
      ));
    }

    // Datele detectate care vor fi aplicate dacă utilizatorul confirmă
    final candidateDates = <DateTime>{}
      ..addAll(byLawFixed)
      ..addAll(byCcmFixed)
      ..addAll(byEaster);
    final sortedDates = candidateDates.toList()..sort((a, b) => a.compareTo(b));

    final String titleYear = DateFormat('yyyy', 'ro_RO').format(DateTime(year));

    final String actionLabel =
    replaceWholeYear ? 'Înlocuiește în aplicație' : 'Adaugă în aplicație';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final screenSize = MediaQuery.of(ctx).size;

        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.04,
            vertical: screenSize.height * 0.015,
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: Text(
            'Zile festive detectate pentru $titleYear',
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenSize.width * 0.92,
              maxHeight: screenSize.height * 0.84,
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final sec in sections) ...[
                      if (sec.title != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            sec.title!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      ...sec.ranges.map(
                            (r) => ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -2),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event),
                          title: Text(_formatRangeRo(r)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...sec.sourceLines.map(
                            (s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            s,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Anulează'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      return sortedDates;
    }
    return <DateTime>[];
  }
}

class _SourceSection {
  final String? title;
  final List<List<DateTime>> ranges;
  final List<String> sourceLines;
  _SourceSection({this.title, required this.ranges, required this.sourceLines});
}
