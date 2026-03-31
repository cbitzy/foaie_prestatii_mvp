// /lib/screens/afisare_program/afisare_servicii.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../calcule_ore/api.dart' show workedBucketsForSlice, kRomanianLegalHolidays;
import '../../utils/service_title.dart' show formatServiceTitle;

typedef MergeSlicesFn = List<Map<String, dynamic>> Function(List<Map<String, dynamic>> input);

class AfisareServicii extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> services;
  final MergeSlicesFn mergeMidnightSlices;
  final bool groupBySheet;
  final bool showAdvancedServiceAction;
  final void Function(String serviceTitle)? onOpenAdvancedService;

  const AfisareServicii({
    super.key,
    required this.services,
    required this.mergeMidnightSlices,
    this.groupBySheet = false,
    this.showAdvancedServiceAction = false,
    this.onOpenAdvancedService,
  });

  // ==== Helpers pentru defalcate ====

  String _fmtMins(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  Map<String, int> _bucketsFor(Map<String, dynamic> m) {
    final type = (m['type'] as String?) ?? '';
    final s = DateTime.parse(m['start'] as String);
    final e = DateTime.parse(m['end'] as String);
    return workedBucketsForSlice(typeKey: type, start: s, end: e, holidays: kRomanianLegalHolidays);
  }

  Map<String, int> _sumBuckets(Iterable<Map<String, dynamic>> segs) {
    final out = <String, int>{'day': 0, 'night': 0, 'festDay': 0, 'festNight': 0};
    for (final m in segs) {
      final b = _bucketsFor(m);
      out['day'] = (out['day'] ?? 0) + (b['day'] ?? 0);
      out['night'] = (out['night'] ?? 0) + (b['night'] ?? 0);
      out['festDay'] = (out['festDay'] ?? 0) + (b['festDay'] ?? 0);
      out['festNight'] = (out['festNight'] ?? 0) + (b['festNight'] ?? 0);
    }
    return out;
  }

  String _joinNonEmpty(List<String> parts) =>
      parts.where((e) => e.trim().isNotEmpty).join(', ');

  bool _hasAdvancedFieldValue(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is List) {
      for (final item in value) {
        if ((item?.toString() ?? '').trim().isNotEmpty) {
          return true;
        }
      }
      return false;
    }
    return true;
  }

  bool _serviceHasAdvancedData(Iterable<Map<String, dynamic>> segs) {
    for (final seg in segs) {
      if (_hasAdvancedFieldValue(seg['advancedMode']) ||
          _hasAdvancedFieldValue(seg['locomotiveType']) ||
          _hasAdvancedFieldValue(seg['locomotiveClass']) ||
          _hasAdvancedFieldValue(seg['locomotiveNumber']) ||
          _hasAdvancedFieldValue(seg['mecFormatorName']) ||
          _hasAdvancedFieldValue(seg['advancedObservations']) ||
          _hasAdvancedFieldValue(seg['servicePerformedAs']) ||
          _hasAdvancedFieldValue(seg['assistantMechanicName']) ||
          _hasAdvancedFieldValue(seg['odihnaDormitor']) ||
          _hasAdvancedFieldValue(seg['odihnaCamera']) ||
          _hasAdvancedFieldValue(seg['advancedPhotoPaths'])) {
        return true;
      }
    }
    return false;
  }

  Widget? _buildAdvancedServiceButton(
      BuildContext context,
      List<Map<String, dynamic>> segs,
      String serviceTitle,
      ) {
    if (!showAdvancedServiceAction ||
        onOpenAdvancedService == null ||
        !_serviceHasAdvancedData(segs)) {
      return null;
    }

    return OutlinedButton(
      onPressed: () => onOpenAdvancedService!(serviceTitle),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -2),
        alignment: Alignment.center,
        side: BorderSide(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        'Afisare Avansata',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }

  // Pentru "alte": doar denumirea, fără prefixul "Alte Activități:"
  String _otherLabel(Map<String, dynamic> m) {
    final desc = ((m['desc'] ?? m['description'] ?? '') as String).trim();
    return desc.isEmpty ? '' : desc;
  }

  // Interval pentru etichetele de segment:
  // - aceeași zi: "dd.MM.yyyy HH:mm → HH:mm"
  // - zile diferite: "dd.MM.yyyy HH:mm → dd.MM.yyyy HH:mm"
  String _formatInterval(DateTime s, DateTime e, DateFormat dfRow) {
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
      // 24:00 pentru ziua de start
      return '${d.format(s)} - ${t.format(s)} → ${d.format(s)} - 24:00';
    }

    final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
    if (sameDay) {
      return '${d.format(s)} - ${t.format(s)} → ${t.format(e)}';
    } else {
      return '${dfRow.format(s)} → ${dfRow.format(e)}';
    }
  }

  // Doar denumirea tipului pentru titlurile rândurilor de segmente (fără interval)
  String _typeOnlyLabel(Map<String, dynamic> m) {
    final type = (m['type'] as String?) ?? '';
    switch (type) {
      case 'tren': {
        final raw = (m['trainNo'] as String?)?.trim();
        final no = (raw != null && raw.isNotEmpty) ? raw : '-';
        return 'Tren $no';
      }
      case 'mvStatie':
        return 'MV Stație';
      case 'mvDepou':
        return 'MV Depou';
      case 'acar':
        return 'Acar';
      case 'regie':
        return 'Regie';
      case 'odihna':
        return 'Odihnă';
      case 'revizor':
        return 'Revizor';
      case 'sefTura':
        return 'Șef Tura';
      case 'alte': {
        final name = _otherLabel(m);
        return name.isEmpty ? 'Alte Activități' : name;
      }
      default:
        return 'Segment';
    }
  }

  // Subtitle pentru UN segment:
  // - Odihnă/Regie: doar eticheta + durata brută (dacă > 0)
  // - Altele: "Ore lucrate segment:" normal, doar timpul bold, iar defalcatele dedesubt
  Widget? _segmentSubtitle(Map<String, dynamic> seg, BuildContext context, {bool showWorked = true}) {
    final type = (seg['type'] as String?) ?? '';
    final s = DateTime.parse(seg['start'] as String);
    final e = DateTime.parse(seg['end'] as String);

    if (type == 'odihna') {
      final mins = e.difference(s).inMinutes;
      if (mins <= 0) {
        return null;
      }
      return Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Odihnă: '),
            TextSpan(
              text: _fmtMins(mins),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (!showWorked) {
      return null;
    }

    final b = _bucketsFor(seg);
    final tot = (b['day'] ?? 0) + (b['night'] ?? 0) + (b['festDay'] ?? 0) + (b['festNight'] ?? 0);
    if (tot <= 0) {
      return null;
    }

    final spans = <TextSpan>[
      const TextSpan(text: 'Ore lucrate segment: '),
      TextSpan(
        text: _fmtMins(tot),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ];

    if ((b['day'] ?? 0) > 0) {
      spans.add(TextSpan(text: '\nZi: ${_fmtMins(b['day']!)}'));
    }
    if ((b['night'] ?? 0) > 0) {
      spans.add(TextSpan(text: '\nNoapte: ${_fmtMins(b['night']!)}'));
    }
    if ((b['festDay'] ?? 0) > 0) {
      spans.add(TextSpan(text: '\nFestive zi: ${_fmtMins(b['festDay']!)}'));
    }
    if ((b['festNight'] ?? 0) > 0) {
      spans.add(TextSpan(text: '\nFestive noapte: ${_fmtMins(b['festNight']!)}'));
    }

    return Text.rich(
      TextSpan(
        children: spans,
      ),
    );
  }

  Map<String, dynamic> _serviceTotalInfo(Iterable<Map<String, dynamic>> segs) {
    final b = _sumBuckets(segs);
    final total = (b['day'] ?? 0) + (b['night'] ?? 0) + (b['festDay'] ?? 0) + (b['festNight'] ?? 0);

    final details = <String>[];
    if ((b['day'] ?? 0) > 0) {
      details.add('Zi: ${_fmtMins(b['day']!)}');
    }
    if ((b['night'] ?? 0) > 0) {
      details.add('Noapte: ${_fmtMins(b['night']!)}');
    }
    if ((b['festDay'] ?? 0) > 0) {
      details.add('Festive zi: ${_fmtMins(b['festDay']!)}');
    }
    if ((b['festNight'] ?? 0) > 0) {
      details.add('Festive noapte: ${_fmtMins(b['festNight']!)}');
    }

    // Durate brute cumulative pentru Odihnă
    int restMins = 0;

    for (final m in segs) {
      final t = (m['type'] as String?) ?? '';
      final s = DateTime.parse(m['start'] as String);
      final e = DateTime.parse(m['end'] as String);
      final dur = e.difference(s).inMinutes;
      if (dur <= 0) {
        continue;
      }

      if (t == 'odihna') {
        restMins += dur;
      }
    }

    if (restMins > 0) {
      details.add('Odihnă: ${_fmtMins(restMins)}');
    }

    return {'total': total, 'details': details};
  }

  RichText _serviceTotalRichText(BuildContext context, Iterable<Map<String, dynamic>> segs, {String label = 'serviciu'}) {
    final info = _serviceTotalInfo(segs);
    final int total = (info['total'] as int?) ?? 0;
    final List<String> details = (info['details'] as List<String>?) ?? const [];

    final bool isZero = total <= 0 && details.isEmpty;
    final String totalText = isZero ? '0h 00m' : _fmtMins(total);

    final baseStyle = DefaultTextStyle.of(context)
        .style
        .copyWith(color: Theme.of(context).textTheme.bodyLarge?.color);

    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final firstLineStyle = (titleStyle ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );

    final spans = <TextSpan>[
      TextSpan(
        text: 'Ore lucrate $label: $totalText',
        style: firstLineStyle,
      ),
    ];

    for (final d in details) {
      spans.add(
        TextSpan(
          text: '\n$d',
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.normal,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }

  Widget _buildServiceTotalRow(
      BuildContext context,
      List<Map<String, dynamic>> segs, {
        String serviceTitle = '',
        bool showAdvancedButton = false,
      }) {
    final advancedButton = showAdvancedButton
        ? _buildAdvancedServiceButton(context, segs, serviceTitle)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _serviceTotalRichText(context, segs),
        ),
        if (advancedButton != null) ...[
          const SizedBox(width: 8),
          advancedButton,
        ],
      ],
    );
  }

  // Subtitle pentru TOTALUL unui serviciu
  String _serviceTotalSubtitle(Iterable<Map<String, dynamic>> segs, {String label = 'serviciu'}) {
    final b = _sumBuckets(segs);
    final total = (b['day'] ?? 0) + (b['night'] ?? 0) + (b['festDay'] ?? 0) + (b['festNight'] ?? 0);

    final details = <String>[];
    if ((b['day'] ?? 0) > 0) {
      details.add('Zi: ${_fmtMins(b['day']!)}');
    }
    if ((b['night'] ?? 0) > 0) {
      details.add('Noapte: ${_fmtMins(b['night']!)}');
    }
    if ((b['festDay'] ?? 0) > 0) {
      details.add('Festive zi: ${_fmtMins(b['festDay']!)}');
    }
    if ((b['festNight'] ?? 0) > 0) {
      details.add('Festive noapte: ${_fmtMins(b['festNight']!)}');
    }

    // Durate brute cumulative pentru Odihnă
    int restMins = 0;

    for (final m in segs) {
      final t = (m['type'] as String?) ?? '';
      final s = DateTime.parse(m['start'] as String);
      final e = DateTime.parse(m['end'] as String);
      final dur = e.difference(s).inMinutes;
      if (dur <= 0) {
        continue;
      }

      if (t == 'odihna') {
        restMins += dur;
      }
    }

    if (restMins > 0) {
      details.add('Odihnă: ${_fmtMins(restMins)}');
    }

    final tail = _joinNonEmpty(details);
    if (total <= 0 && tail.isEmpty) {
      return 'Ore lucrate $label: 0h 00m';
    }
    return tail.isEmpty
        ? 'Ore lucrate $label: ${_fmtMins(total)}'
        : 'Ore lucrate $label: ${_fmtMins(total)} — $tail';
  }
  String _sheetTotalSubtitle(Iterable<Map<String, dynamic>> segs) {
    final b = _sumBuckets(segs);
    final total = (b['day'] ?? 0) + (b['night'] ?? 0) + (b['festDay'] ?? 0) + (b['festNight'] ?? 0);

    String series = '';
    String number = '';
    if (segs.isNotEmpty) {
      final first = segs.first;
      series = ((first['sheetSeries'] as String?) ?? '').trim();
      number = ((first['sheetNumber'] as String?) ?? '').trim();
    }

    final seriesPart = series.isNotEmpty ? series : '-';
    final numberPart = number.isNotEmpty ? number : '-';
    return 'Ore lucrate foaie ${seriesPart}_$numberPart: ${_fmtMins(total)}';
  }


  bool _containsMap(Map<String, dynamic> parent, Map<String, dynamic> child) {
    final ps = DateTime.parse(parent['start'] as String);
    final pe = DateTime.parse(parent['end'] as String);
    final cs = DateTime.parse(child['start'] as String);
    final ce = DateTime.parse(child['end'] as String);

    return !cs.isBefore(ps) && !ce.isAfter(pe) && !identical(parent, child);
  }

  List<_MapNode> _buildTreeForDisplay(List<Map<String, dynamic>> segs) {
    if (segs.isEmpty) {
      return const [];
    }

    final list = [...segs]
      ..sort((a, b) {
        final ad = DateTime.parse(a['end']).difference(DateTime.parse(a['start'])).inMinutes;
        final bd = DateTime.parse(b['end']).difference(DateTime.parse(b['start'])).inMinutes;
        final byDur = bd.compareTo(ad);
        if (byDur != 0) {
          return byDur;
        }
        return DateTime.parse(a['start']).compareTo(DateTime.parse(b['start']));
      });

    final usedAsChild = <Map<String, dynamic>>{};
    final nodes = <_MapNode>[];

    for (final p in list) {
      if (usedAsChild.contains(p)) {
        continue;
      }
      final children = <Map<String, dynamic>>[];
      for (final c in list) {
        if (identical(c, p)) {
          continue;
        }
        if (usedAsChild.contains(c)) {
          continue;
        }
        if (_containsMap(p, c)) {
          children.add(c);
          usedAsChild.add(c);
        }
      }
      children.sort((a, b) => DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])));
      nodes.add(_MapNode(parent: p, children: children));
    }

    nodes.sort((a, b) =>
        DateTime.parse(a.parent['start']).compareTo(DateTime.parse(b.parent['start'])));
    return nodes;
  }

  List<Widget> _buildRowsForDisplay(
      BuildContext context,
      List<Map<String, dynamic>> segs,
      DateFormat dfRow, {
        String serviceTitle = '',
        bool showAdvancedButton = false,
      }) {
    final nodes = _buildTreeForDisplay(segs);
    final rows = <Widget>[];

    final bool showWorkedForSegments = true;

    for (final n in nodes) {
      final subParent = _segmentSubtitle(n.parent, context, showWorked: showWorkedForSegments);
      rows.add(
        ListTile(
          dense: true,
          title: RichText(
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),
              children: [
                TextSpan(
                  text: _typeOnlyLabel(n.parent),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' — ${_formatInterval(
                    DateTime.parse(n.parent['start'] as String),
                    DateTime.parse(n.parent['end'] as String),
                    dfRow,
                  )}',
                ),
              ],
            ),
          ),
          subtitle: subParent,
        ),
      );
      for (final c in n.children) {
        final subChild = _segmentSubtitle(c, context, showWorked: showWorkedForSegments);
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: ListTile(
              dense: true,
              title: RichText(
                text: TextSpan(
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),
                  children: [
                    TextSpan(
                      text: _typeOnlyLabel(c),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ' — ${_formatInterval(
                        DateTime.parse(c['start'] as String),
                        DateTime.parse(c['end'] as String),
                        dfRow,
                      )}',
                    ),
                  ],
                ),
              ),
              subtitle: subChild,
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
      rows.add(
        const ListTile(
          dense: true,
          title: Text('Niciun segment.'),
        ),
      );
    } else {
      rows.add(const SizedBox(height: 6));
      rows.add(
        ListTile(
          dense: true,
          title: _buildServiceTotalRow(
            context,
            segs,
            serviceTitle: serviceTitle,
            showAdvancedButton: showAdvancedButton,
          ),
        ),
      );
      rows.add(const Divider(height: 1));
    }

    return rows;
  }


  List<Widget> _buildRowsForDisplayChrono(
      BuildContext context,
      List<Map<String, dynamic>> segs,
      DateFormat dfRow, {
        bool showTotal = true,
        String label = 'serviciu',
        bool showWorkedForSegments = true,
      }) {
    final rows = <Widget>[];

    final segsChrono = [...segs]
      ..sort((a, b) => DateTime.parse(a['start'] as String)
          .compareTo(DateTime.parse(b['start'] as String)));

    for (final m in segsChrono) {
      final sub = _segmentSubtitle(m, context, showWorked: showWorkedForSegments);
      rows.add(
        ListTile(
          dense: true,
          minVerticalPadding: 0,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          title: RichText(
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color),
              children: [
                TextSpan(
                  text: _typeOnlyLabel(m),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' — ${_formatInterval(
                    DateTime.parse(m['start'] as String),
                    DateTime.parse(m['end'] as String),
                    dfRow,
                  )}',
                ),
              ],
            ),
          ),
          subtitle: sub,
        ),
      );
      rows.add(const Divider(height: 1));
    }

    if (rows.isEmpty) {
      rows.add(
        const ListTile(
          dense: true,
          minVerticalPadding: 0,
          visualDensity: VisualDensity(horizontal: 0, vertical: -4),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          title: Text('Niciun segment.'),
        ),
      );
    } else if (showTotal) {
      final String titleText;
      if (label.startsWith('foaie ')) {
        titleText = _sheetTotalSubtitle(segsChrono);
      } else {
        titleText = _serviceTotalSubtitle(segsChrono, label: label);
      }
      rows.add(
        ListTile(
          dense: true,
          minVerticalPadding: 0,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          title: Text(
            titleText,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
      rows.add(const Divider(height: 1));
    }

    return rows;
  }

  List<Widget> _buildServiceChildren(
      BuildContext context,
      List<Map<String, dynamic>> segsMerged,
      DateFormat dfRow, {
        String serviceTitle = '',
      }) {
    if (!groupBySheet) {
      return [
        ..._buildRowsForDisplay(
          context,
          segsMerged,
          dfRow,
          serviceTitle: serviceTitle,
          showAdvancedButton: true,
        ),
        const SizedBox(height: 8),
      ];
    }

    if (segsMerged.isEmpty) {
      return [
        ..._buildRowsForDisplay(
          context,
          segsMerged,
          dfRow,
          serviceTitle: serviceTitle,
          showAdvancedButton: true,
        ),
        const SizedBox(height: 8),
      ];
    }

    final segsChrono = [...segsMerged]
      ..sort((a, b) => DateTime.parse(a['start'] as String)
          .compareTo(DateTime.parse(b['start'] as String)));


    final children = <Widget>[];

    int i = 0;
    bool isFirstBlock = true;
    while (i < segsChrono.length) {
      if (!isFirstBlock) {
        children.add(const SizedBox(height: 16));
      }

      final seg = segsChrono[i];
      final String sheetSeries = ((seg['sheetSeries'] as String?) ?? '').trim();
      final String sheetNumber = ((seg['sheetNumber'] as String?) ?? '').trim();
      final bool hasSheet = sheetSeries.isNotEmpty && sheetNumber.isNotEmpty;

      int j = i;
      if (hasSheet) {
        while (j < segsChrono.length) {
          final s = segsChrono[j];
          final String ss = ((s['sheetSeries'] as String?) ?? '').trim();
          final String sn = ((s['sheetNumber'] as String?) ?? '').trim();
          if (ss != sheetSeries || sn != sheetNumber) {
            break;
          }
          j++;
        }
        final blockSegs = segsChrono.sublist(i, j);

        children.add(
          ListTile(
            dense: true,
            minVerticalPadding: 0,
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            title: Text(
              'Foaie - $sheetSeries $sheetNumber',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );

        children.addAll(
          _buildRowsForDisplayChrono(
            context,
            blockSegs,
            dfRow,
            showTotal: true,
            label: 'foaie $sheetNumber',
            showWorkedForSegments: true,
          ),
        );
      } else {
        while (j < segsChrono.length) {
          final s = segsChrono[j];
          final String ss = ((s['sheetSeries'] as String?) ?? '').trim();
          final String sn = ((s['sheetNumber'] as String?) ?? '').trim();
          if (ss.isNotEmpty && sn.isNotEmpty) {
            break;
          }
          j++;
        }
        final blockSegs = segsChrono.sublist(i, j);

        children.addAll(
          _buildRowsForDisplayChrono(context, blockSegs, dfRow, showTotal: true, label: 'segment', showWorkedForSegments: true),
        );
      }

      isFirstBlock = false;
      i = j;
    }

    children.add(const SizedBox(height: 6));
    children.add(
      ListTile(
        dense: true,
        minVerticalPadding: 0,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        title: _buildServiceTotalRow(
          context,
          segsChrono,
          serviceTitle: serviceTitle,
          showAdvancedButton: true,
        ),
      ),
    );
    children.add(const Divider(height: 1));
    children.add(const SizedBox(height: 8));

    return children;
  }

  @override
  Widget build(BuildContext context) {
    final dfRow = DateFormat('dd.MM.yyyy HH:mm', 'ro_RO');

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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: entriesSorted.length,
      itemBuilder: (context, idx) {
        final entry = entriesSorted[idx];

        final segsMergedDesc = mergeMidnightSlices(entry.value)
          ..sort((a, b) => DateTime.parse(b['start'] as String)
              .compareTo(DateTime.parse(a['start'] as String)));

        final start = DateTime.parse(segsMergedDesc.last['start']);
        final end = DateTime.parse(segsMergedDesc.first['end']);

        // TITLU: folosim formatterul unificat cerut de tine
        final interval = formatServiceTitle(start, end);

        // Elimină prefixul "Serviciu " dacă vine deja din formatServiceTitle,
        // ca să evităm dublarea ("Serviciu - Serviciu ...").
        final intervalClean = interval.startsWith('Serviciu ')
            ? interval.substring('Serviciu '.length)
            : interval;

        // === SUBTITLU / TITLU-SUFIX: în ordinea cronologică ASC a segmentelor (fără 'odihna') ===
        final parts = <String>[];
        final segsAsc = [...segsMergedDesc]
          ..sort((a, b) => DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])));

        for (final m in segsAsc) {
          final type = m['type'] as String;
          if (type == 'odihna') {
            continue; // exclude "odihna" din suffix
          }
          switch (type) {
            case 'tren':
              {
                final raw = (m['trainNo'] as String?)?.trim();
                if (raw != null && raw.isNotEmpty) {
                  parts.add(raw);
                }
                break;
              }
            case 'mvStatie':
              parts.add('MV Stație');
              break;
            case 'mvDepou':
              parts.add('MV Depou');
              break;
            case 'acar':
              parts.add('Acar');
              break;
            case 'regie':
              parts.add('Regie');
              break;
            case 'revizor':
              parts.add('Revizor');
              break;
            case 'sefTura':
              parts.add('Șef Tura');
              break;
            case 'alte':
              {
                final name = _otherLabel(m);
                if (name.isNotEmpty) {
                  parts.add(name);
                }
                break;
              }
            default:
              {
                final desc = (m['typeDesc'] as String? ?? '').trim();
                if (desc.isNotEmpty) {
                  parts.add(desc);
                }
                break;
              }
          }
        }
        final displaySuffix = parts.join(' / ');
        final serviceTitleText = 'Serviciu - $intervalClean';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (idx > 0) const SizedBox(height: 8),
            ExpansionTile(
              title: Text(
                serviceTitleText,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: displaySuffix.isEmpty
                  ? null
                  : Text(
                displaySuffix,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              children: groupBySheet
                  ? _buildServiceChildren(
                context,
                mergeMidnightSlices(entry.value),
                dfRow,
                serviceTitle: serviceTitleText,
              )
                  : [
                ..._buildRowsForDisplay(
                  context,
                  mergeMidnightSlices(entry.value),
                  dfRow,
                  serviceTitle: serviceTitleText,
                  showAdvancedButton: true,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MapNode {
  final Map<String, dynamic> parent;
  final List<Map<String, dynamic>> children;
  const _MapNode({required this.parent, required this.children});
}
