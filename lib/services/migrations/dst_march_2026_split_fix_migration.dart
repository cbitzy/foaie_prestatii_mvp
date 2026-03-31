// /lib/services/migrations/dst_march_2026_split_fix_migration.dart

import 'package:intl/intl.dart';

import '../../models/service_segment.dart';
import '../../screens/Adauga_modifica_serviciu/nume_serviciu.dart'
    show buildServiceNameFromSegments;
import '../recalculator.dart';
import '../report_storage_v2.dart';

class DstMarch2026SplitFixRepairedService {
  final String serviceId;
  final String serviceName;
  final DateTime start;
  final DateTime end;

  const DstMarch2026SplitFixRepairedService({
    required this.serviceId,
    required this.serviceName,
    required this.start,
    required this.end,
  });
}

class DstMarch2026SplitFixRunResult {
  final int repairedCount;
  final List<DstMarch2026SplitFixRepairedService> repairedServices;

  const DstMarch2026SplitFixRunResult({
    required this.repairedCount,
    required this.repairedServices,
  });

  const DstMarch2026SplitFixRunResult.empty()
      : repairedCount = 0,
        repairedServices = const <DstMarch2026SplitFixRepairedService>[];
}

class DstMarch2026SplitFixMigration {
  static Future<DstMarch2026SplitFixRunResult> repairAffectedServices() async {
    final marchServices =
    await ReportStorageV2.listServicesForMonthWithSegments(2026, 3);
    if (marchServices.isEmpty) {
      return const DstMarch2026SplitFixRunResult.empty();
    }

    int repairedCount = 0;
    final repairedServices = <DstMarch2026SplitFixRepairedService>[];
    final monthsToRecalc = <String>{};

    for (final serviceId in marchServices.keys) {
      final rawSegments = await ReportStorageV2.listAllSegmentsForService(
        serviceId,
      );
      if (rawSegments.isEmpty) {
        continue;
      }

      final repairedSegments = _mergeBrokenDstSplitSegments(rawSegments);
      if (repairedSegments.length == rawSegments.length) {
        continue;
      }

      final canonicalMonth = await ReportStorageV2.getServiceMonth(serviceId);
      final fullSegmentsForName =
      repairedSegments.map(serviceSegmentToStorageMap).toList();
      final computedName = buildServiceNameFromSegments(fullSegmentsForName);

      final sortedSegments = List<ServiceSegment>.from(repairedSegments)
        ..sort((a, b) => a.start.compareTo(b.start));
      final displayStart = sortedSegments.first.start;
      var displayEnd = sortedSegments.first.end;
      for (final seg in sortedSegments.skip(1)) {
        if (seg.end.isAfter(displayEnd)) {
          displayEnd = seg.end;
        }
      }

      await _rewriteService(
        serviceId: serviceId,
        canonicalMonth: canonicalMonth,
        segments: repairedSegments,
      );

      if (canonicalMonth?.trim().isNotEmpty ?? false) {
        monthsToRecalc.add(canonicalMonth!.trim());
      }
      monthsToRecalc.addAll(_extractTouchedMonths(repairedSegments));

      repairedServices.add(
        DstMarch2026SplitFixRepairedService(
          serviceId: serviceId,
          serviceName: computedName,
          start: displayStart,
          end: displayEnd,
        ),
      );

      repairedCount++;
    }

    if (repairedCount > 0 && monthsToRecalc.isNotEmpty) {
      await Recalculator.recalcAllDailyTotalsUsingSegments(
        months: monthsToRecalc,
      );
      await Recalculator.reaggregateAndWriteMonthlyTotals(
        months: monthsToRecalc,
      );
      await Recalculator.recalcMonthlyOvertimeForMonths(monthsToRecalc);
    }

    return DstMarch2026SplitFixRunResult(
      repairedCount: repairedCount,
      repairedServices: repairedServices,
    );
  }

  static Set<String> _extractTouchedMonths(List<ServiceSegment> segments) {
    final out = <String>{};
    final ymFmt = DateFormat('yyyy-MM');

    for (final seg in segments) {
      var cursor = DateTime(seg.start.year, seg.start.month, seg.start.day);
      final lastDay = DateTime(seg.end.year, seg.end.month, seg.end.day);

      while (!cursor.isAfter(lastDay)) {
        out.add(ymFmt.format(cursor));
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }
    }

    return out;
  }

  static List<ServiceSegment> _mergeBrokenDstSplitSegments(
      List<Map<String, dynamic>> rawSegments,
      ) {
    final input = rawSegments.map(serviceSegmentFromStorageMap).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (input.length < 2) {
      return input;
    }

    final out = <ServiceSegment>[];
    var cur = _cloneSegment(input.first);

    for (int i = 1; i < input.length; i++) {
      final next = input[i];
      final touches = next.start.isAtSameMomentAs(cur.end);
      final brokenMarch2026Boundary = _isBrokenMarch2026Boundary(
        segmentStart: cur.start,
        segmentEnd: cur.end,
      );

      if (touches &&
          brokenMarch2026Boundary &&
          _sameSegmentIdentity(cur, next)) {
        cur.end = next.end;
      } else {
        out.add(cur);
        cur = _cloneSegment(next);
      }
    }

    out.add(cur);
    return out;
  }

  static bool _isBrokenMarch2026Boundary({
    required DateTime segmentStart,
    required DateTime segmentEnd,
  }) {
    final legacyBoundary = DateTime(
      segmentStart.year,
      segmentStart.month,
      segmentStart.day,
    ).add(const Duration(days: 1));

    final calendarBoundary = DateTime(
      segmentStart.year,
      segmentStart.month,
      segmentStart.day + 1,
    );

    final isAffectedStartDate =
        segmentStart.year == 2026 &&
            segmentStart.month == 3 &&
            segmentStart.day == 29;

    if (!isAffectedStartDate) {
      return false;
    }

    return segmentEnd.isAtSameMomentAs(legacyBoundary) &&
        !segmentEnd.isAtSameMomentAs(calendarBoundary);
  }

  static bool _sameSegmentIdentity(ServiceSegment a, ServiceSegment b) {
    return a.type == b.type &&
        _sameText(a.trainNo, b.trainNo) &&
        _sameText(a.otherDesc, b.otherDesc) &&
        _sameText(a.sheetSeries, b.sheetSeries) &&
        _sameText(a.sheetNumber, b.sheetNumber) &&
        _sameText(a.advancedMode, b.advancedMode) &&
        _sameText(a.locomotiveType, b.locomotiveType) &&
        _sameText(a.locomotiveClass, b.locomotiveClass) &&
        _sameText(a.locomotiveNumber, b.locomotiveNumber) &&
        _sameText(a.mecFormatorName, b.mecFormatorName) &&
        _sameText(a.advancedObservations, b.advancedObservations) &&
        _sameText(a.servicePerformedAs, b.servicePerformedAs) &&
        _sameText(a.assistantMechanicName, b.assistantMechanicName) &&
        _sameText(a.odihnaDormitor, b.odihnaDormitor) &&
        _sameText(a.odihnaCamera, b.odihnaCamera) &&
        _sameTextList(a.advancedPhotoPaths, b.advancedPhotoPaths);
  }

  static bool _sameText(String? a, String? b) =>
      (a?.trim() ?? '') == (b?.trim() ?? '');

  static bool _sameTextList(List<String>? a, List<String>? b) {
    final aa = (a ?? const <String>[]).map((e) => e.trim()).toList();
    final bb = (b ?? const <String>[]).map((e) => e.trim()).toList();

    if (aa.length != bb.length) {
      return false;
    }

    for (int i = 0; i < aa.length; i++) {
      if (aa[i] != bb[i]) {
        return false;
      }
    }

    return true;
  }

  static ServiceSegment _cloneSegment(ServiceSegment source) {
    return ServiceSegment(
      type: source.type,
      start: source.start,
      end: source.end,
      trainNo: source.trainNo,
      otherDesc: source.otherDesc,
      sheetSeries: source.sheetSeries,
      sheetNumber: source.sheetNumber,
      advancedMode: source.advancedMode,
      locomotiveType: source.locomotiveType,
      locomotiveClass: source.locomotiveClass,
      locomotiveNumber: source.locomotiveNumber,
      mecFormatorName: source.mecFormatorName,
      advancedObservations: source.advancedObservations,
      servicePerformedAs: source.servicePerformedAs,
      assistantMechanicName: source.assistantMechanicName,
      odihnaDormitor: source.odihnaDormitor,
      odihnaCamera: source.odihnaCamera,
      advancedPhotoPaths: source.advancedPhotoPaths == null
          ? null
          : List<String>.from(source.advancedPhotoPaths!),
    );
  }

  static Future<void> _rewriteService({
    required String serviceId,
    required String? canonicalMonth,
    required List<ServiceSegment> segments,
  }) async {
    if (segments.isEmpty) {
      return;
    }

    final dayKeyFmt = DateFormat('yyyy-MM-dd');
    final daySegments = <String, List<Map<String, dynamic>>>{};

    for (final seg in segments) {
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

    await ReportStorageV2.deleteServiceEverywhere(serviceId);

    for (final entry in daySegments.entries) {
      await ReportStorageV2.writeDaySegmentsForService(
        entry.key,
        serviceId,
        entry.value,
      );
    }

    final monthToWrite = (canonicalMonth?.trim().isNotEmpty ?? false)
        ? canonicalMonth!.trim()
        : DateFormat('yyyy-MM').format(segments.first.start);
    await ReportStorageV2.setServiceMonth(serviceId, monthToWrite);

    final fullSegmentsForName = segments.map(serviceSegmentToStorageMap).toList();
    final computedName = buildServiceNameFromSegments(fullSegmentsForName);
    await ReportStorageV2.setServiceName(serviceId, computedName);
  }
}