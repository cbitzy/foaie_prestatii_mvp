// /lib/screens/utils/service_title.dart

import 'package:intl/intl.dart';

/// Format unified service title with the required prefixes.
/// Rules:
/// - 1 day:                 Serviciu dd.MM.yyyy
/// - multiple days same mo: Serviciu dd - dd.MM.yyyy
/// - multiple days same yr: Serviciu dd.MM - dd.MM.yyyy
/// - multiple days diff yr: Serviciu dd.MM.yyyy - dd.MM.yyyy
String formatServiceTitle(DateTime start, DateTime end) {
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  final spanDays = e.difference(s).inDays;

  if (sameDay) {
    return 'Serviciu ${DateFormat('dd.MM.yyyy').format(start)}';
  }

  if (spanDays == 1) {
    if (s.year != e.year) {
      final left = DateFormat('dd.MM.yyyy').format(start);
      final right = DateFormat('dd.MM.yyyy').format(end);
      return 'Serviciu $left - $right';
    }
    if (s.month == e.month) {
      final left = DateFormat('dd').format(start);
      final right = DateFormat('dd.MM.yyyy').format(end);
      return 'Serviciu $left - $right';
    } else {
      final left = DateFormat('dd.MM').format(start);
      final right = DateFormat('dd.MM.yyyy').format(end);
      return 'Serviciu $left - $right';
    }
  }

  if (s.year != e.year) {
    final left = DateFormat('dd.MM.yyyy').format(start);
    final right = DateFormat('dd.MM.yyyy').format(end);
    return 'Serviciu $left - $right';
  }

  if (s.month == e.month) {
    final left = DateFormat('dd').format(start);
    final right = DateFormat('dd.MM.yyyy').format(end);
    return 'Serviciu $left - $right';
  }

  final left = DateFormat('dd.MM').format(start);
  final right = DateFormat('dd.MM.yyyy').format(end);
  return 'Serviciu $left - $right';
}
