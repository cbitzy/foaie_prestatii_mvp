//lib/screens/Adauga_modifica_serviciu/nume_serviciu.dart

import '../../utils/service_title.dart' show formatServiceTitle;

// === Utils pentru afișarea unificată a segmentelor, ca în Afisare Servicii ===
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// Reguli interval:
/// - aceeasi zi:         dd.MM.yyyy
/// - zile diferite, aceeasi luna: dd - dd.MM.yyyy
/// - luni diferite:      dd.MM - dd.MM.yyyy
///
/// Reguli nume (suffix):
/// - Cu trenuri:
///   • NU afișăm „Odihnă”
///   • Afișăm (în față): Revizor / Șef Tura / Acar (dacă există, în această ordine)
///   • Afișăm trenurile DOAR ca numere, în ordinea apariției (fără duplicate)
///   • Afișăm „Regie” și „Alte Activități: `desc`” în ordinea introducerii lor față de trenuri
///   • NU afișăm mv*
/// - Fără trenuri:
///   • Listăm tipurile în ordinea apariției (fără duplicate)
///   • „Alte Activități” apare cu descrierea
String buildServiceNameFromSegments(List<Map<String, dynamic>> segs) {
  if (segs.isEmpty) return 'Serviciu';

  // 1) sort pentru interval
  segs.sort((a, b) => DateTime.parse(a['start']).compareTo(DateTime.parse(b['start'])));
  final start = DateTime.parse(segs.first['start'] as String);
  final end   = DateTime.parse(segs.last['end']   as String);

  // 2) interval — delegat la formatterul comun
  final baseTitle = formatServiceTitle(start, end);

  // 3) colectăm informațiile
  bool hasTrain = false;
  bool hasRevizor = false, hasSefTura = false, hasAcar = false;

  // pentru ordinea “cum apar” când există trenuri
  final orderedTrainRelatedForWithTrains = <String>[]; // Trenuri + Regie + Alte Activități: desc

  // pentru cazul fără trenuri
  final otherLabelsNoTrains = <String>[];

  String labelFor(Map<String, dynamic> m) {
    final t = (m['type'] as String?) ?? '';
    switch (t) {
      case 'tren':
        final no = (m['trainNo'] as String?)?.trim() ?? '';
        return no.isEmpty ? '-' : no;
      case 'regie':
        return 'Regie';
      case 'alte':
        final desc = ((m['desc'] ?? m['description'] ?? '') as String).trim();
        return desc.isEmpty ? 'Alte Activități' : 'Alte Activități: $desc';
      case 'mvStatie':
        return 'MV Stație';
      case 'mvDepou':
        return 'MV Depou';
      case 'acar':
        return 'Acar';
      case 'revizor':
        return 'Revizor';
      case 'sefTura':
        return 'Șef Tura';
      case 'odihna':
        return 'Odihnă';
      default:
        return 'Segment';
    }
  }

  void addOnce(List<String> list, String label) {
    if (label.isEmpty) return;
    if (!list.contains(label)) list.add(label);
  }

  // parcurgem în ordine
  for (final m in segs) {
    final t = (m['type'] as String?) ?? '';
    switch (t) {
      case 'tren':
        hasTrain = true;
        final no = (m['trainNo'] as String?)?.trim() ?? '';
        addOnce(orderedTrainRelatedForWithTrains, no);
        break;

      case 'revizor':
        hasRevizor = true;
        break;
      case 'sefTura':
        hasSefTura = true;
        break;
      case 'acar':
        hasAcar = true;
        break;

      case 'regie':
        addOnce(orderedTrainRelatedForWithTrains, 'Regie');
        if (!hasTrain) {
          addOnce(otherLabelsNoTrains, 'Regie');
        }
        break;

      case 'alte':
        final label = labelFor(m); // “Alte Activități: desc”
        addOnce(orderedTrainRelatedForWithTrains, label);
        if (!hasTrain) {
          addOnce(otherLabelsNoTrains, label);
        }
        break;

      case 'mvStatie':
      case 'mvDepou':
        if (!hasTrain) addOnce(otherLabelsNoTrains, labelFor(m));
        break;

      case 'odihna':
        if (!hasTrain) addOnce(otherLabelsNoTrains, 'Odihnă');
        break;

      default:
        if (!hasTrain) addOnce(otherLabelsNoTrains, labelFor(m));
        break;
    }
  }

  // 4) construim suffix
  final parts = <String>[];
  if (hasTrain) {
    // roluri în față, indiferent de ordine
    if (hasRevizor) parts.add('Revizor');
    if (hasSefTura) parts.add('Șef Tura');
    if (hasAcar) parts.add('Acar');

    // păstrăm ordinea introducerii pentru Trenuri + Regie + Alte Activități
    parts.addAll(orderedTrainRelatedForWithTrains);
  } else {
    parts.addAll(otherLabelsNoTrains);
  }

  final suffix = parts.isEmpty ? '' : ' — ${parts.join(' / ')}';
  return baseTitle + suffix;
}

String segmentTypeOnlyLabelFromMap(Map<String, dynamic> m) {
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
      return d.isEmpty ? 'Alte Activități' : 'Alte Activități: $d';
    default:
      return type.isEmpty ? 'Segment' : type;
  }
}

String formatIntervalForRow(DateTime s, DateTime e, DateFormat dfRow) {
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
    return '${dfRow.format(s)} → ${d.format(s)} - 24:00';
  }

  if (s.year != e.year || s.month != e.month || s.day != e.day) {
    return '${dfRow.format(s)} → ${dfRow.format(e)}';
  } else {
    return '${d.format(s)} - ${t.format(s)} → ${t.format(e)}';
  }
}

/// Construiește exact același RichText ca în Afisare Servicii pentru un segment.
/// Folosește bodyMedium cu culoarea bodyLarge și bold pe tip, apoi ' — ' + interval.
Widget segmentTitleRichFromMap(BuildContext context, Map<String, dynamic> seg, DateFormat dfRow) {
  final typeLabel = segmentTypeOnlyLabelFromMap(seg);
  final s = DateTime.parse(seg['start'] as String);
  final e = DateTime.parse(seg['end'] as String);
  final interval = formatIntervalForRow(s, e, dfRow);
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
