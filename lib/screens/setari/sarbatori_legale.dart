// /lib/screens/setari/sarbatori_legale.dart

// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../utils/holidays.dart';
import '../../services/recalculator.dart';
import 'zile_festive_auto.dart';

/// Box și cheie pentru persistarea sărbătorilor legale
const String kLegalHolidaysBox = 'legal_holidays_v1';
const String kLegalHolidaysKey = 'dates'; // List<String> ISO (yyyy-MM-dd)

/// Rezultat din dialog: fie o singură zi, fie un interval.
class HolidaySelectionResult {
  final DateTime? day;
  final DateTimeRange? range;
  const HolidaySelectionResult({this.day, this.range});
}

class SarbatoriLegaleScreen extends StatefulWidget {
  final bool requireAtLeastOneDate;
  const SarbatoriLegaleScreen({super.key, this.requireAtLeastOneDate = false});

  @override
  State<SarbatoriLegaleScreen> createState() => _SarbatoriLegaleScreenState();
}

class _SarbatoriLegaleScreenState extends State<SarbatoriLegaleScreen> {
  final ZileFestiveAuto auto = ZileFestiveAuto();

  final DateFormat df = DateFormat('dd.MM.yyyy', 'ro_RO');
  final DateFormat monthName = DateFormat.MMMM('ro_RO');

  final Set<DateTime> selectedDates = <DateTime>{}; // toate datele
  bool loading = true;
  bool saving = false;

  // urmărește modificări nesalvate
  bool _dirty = false;

  int selectedYear = DateTime.now().year;
  bool editMode = false; // editare/ștergere pe intervale în listă

  // cheie pentru a deschide manual meniul anilor
  final GlobalKey<PopupMenuButtonState<int>> _yearMenuKey = GlobalKey<PopupMenuButtonState<int>>();

  @override
  void initState() {
    super.initState();
    loadFromDb();
  }

  Future<void> loadFromDb() async {
    setState(() => loading = true);
    final box = await Hive.openBox(kLegalHolidaysBox);
    final raw = box.get(kLegalHolidaysKey, defaultValue: const <String>[]);
    final list = List<String>.from(raw);
    final dates = list.map((s) => DateTime.parse(s)).toSet();
    if (!mounted) return;
    setState(() {
      selectedDates
        ..clear()
        ..addAll(dates.map((d) => DateTime(d.year, d.month, d.day)));
      loading = false;
      _dirty = false;
    });
  }

  // --------- reguli de editare pe ani ----------
  bool get _isPastYear {
    final now = DateTime.now();
    return selectedYear < now.year; // anii trecuți: doar vizualizare
  }

  bool get _isNextYearLocked {
    final now = DateTime.now();
    final dec1 = DateTime(now.year, 12, 1);
    return selectedYear == now.year + 1 && now.isBefore(dec1); // anul viitor blocat până la 1 decembrie
  }

  bool get _isTooFarFuture {
    final now = DateTime.now();
    return selectedYear > now.year + 1; // orice alt viitor în afara +1 = read-only
  }

  bool get _isReadOnly => _isPastYear || _isNextYearLocked || _isTooFarFuture;

  String _readOnlyReason() {
    final now = DateTime.now();
    if (_isPastYear) {
      return 'Anul selectat este doar pentru vizualizare. Modificările sunt dezactivate.';
    }
    if (_isNextYearLocked) {
      return 'Se vor putea adăuga zile festive pentru $selectedYear începând cu 1 decembrie ${now.year}.';
    }
    return 'Modificările sunt dezactivate pentru anul selectat.';
  }

  void _guardAction(VoidCallback action) {
    if (_isReadOnly) {
      final msg = _readOnlyReason();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    action();
  }
  // ---------------------------------------------

  Iterable<DateTime> _daysInRange(DateTime start, DateTime end) sync* {
    DateTime cur = DateTime(start.year, start.month, start.day);
    final DateTime stop = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(stop)) {
      yield cur;
      cur = DateTime(cur.year, cur.month, cur.day + 1);
    }
  }

  Future<void> _addDate(DateTime day) async {
    setState(() {
      selectedDates.add(DateTime(day.year, day.month, day.day));
      _dirty = true;
    });
  }

  Future<void> _addRange(DateTime start, DateTime end) async {
    setState(() {
      for (final d in _daysInRange(start, end)) {
        selectedDates.add(DateTime(d.year, d.month, d.day));
      }
      _dirty = true;
    });
  }

  Future<void> _persistAll() async {
    final box = await Hive.openBox(kLegalHolidaysBox);
    final sorted = selectedDates.toList()..sort((a, b) => a.compareTo(b));
    final payload = sorted
        .map((d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
        .toList();
    await box.put(kLegalHolidaysKey, payload);
    await loadLegalHolidaysFromDb();
  }

  Future<void> _copyFromPreviousYear() async {
    final prevYear = selectedYear - 1;
    final prev = selectedDates.where((d) => d.year == prevYear).toList()..sort((a, b) => a.compareTo(b));

    if (prev.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu există zile în $prevYear de copiat.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copiază din anul precedent?'),
        content: Text(
          'Vrei să copiezi sărbătorile legale din $prevYear în $selectedYear?\n'
              'TOATE zilele existente în $selectedYear vor fi suprascrise.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anulează')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Copiază')),
        ],
      ),
    );
    if (confirm != true) return;

    if (!mounted) return;
    setState(() {
      selectedDates.removeWhere((d) => d.year == selectedYear);
      for (final d in prev) {
        selectedDates.add(DateTime(selectedYear, d.month, d.day));
      }
      _dirty = true;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Am copiat sărbătorile din $prevYear în $selectedYear.')),
    );
  }

  /// Dialog de selecție cu highlight vizual: 1 tap = START, 2nd tap = END.
  Future<HolidaySelectionResult?> _openSelectionDialog({
    DateTime? initialDate,
    DateTime? initialStart,
    DateTime? initialEnd,
    bool allowRange = true,
  }) async {
    final now = DateTime.now();
    final currentYear = now.year;
    final nextYear = now.year + 1;
    final dec1 = DateTime(now.year, 12, 1);

    DateTime? rangeStart = initialStart ?? initialDate;
    DateTime? rangeEnd = initialEnd;
    final DateTime init = initialStart ?? initialDate ?? DateTime(currentYear, now.month, now.day);

    // înainte de 1 decembrie: nu permitem navigarea în anul viitor
    final DateTime effectiveLastDate =
    now.isBefore(dec1) ? DateTime(currentYear, 12, 31) : DateTime(nextYear, 12, 31);

    String statusText() {
      if (rangeStart != null && rangeEnd != null) {
        final s = rangeStart!;
        final e = rangeEnd!;
        final sameMonth = (s.month == e.month);
        final nameS = monthName.format(s).toLowerCase();
        final nameE = monthName.format(e).toLowerCase();
        return sameMonth ? 'Interval: ${s.day}–${e.day} $nameS' : 'Interval: ${s.day} $nameS – ${e.day} $nameE';
      }
      if (rangeStart != null) return 'Selectat: ${df.format(rangeStart!)}';
      return '';
    }

    return showDialog<HolidaySelectionResult?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // dimensiuni elastice bazate pe ecran
        final size = MediaQuery.of(ctx).size;
        final maxHeight = size.height * 0.8; // max 80% din înălțime

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              title: Row(
                children: [
                  // X stânga
                  IconButton(
                    tooltip: 'Închide',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(null),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Adăugare Zi Liberă'),
                    ),
                  ),
                  // OK dreapta
                  TextButton(
                    onPressed: () {
                      if (rangeStart != null && rangeEnd != null) {
                        Navigator.of(ctx).pop(
                            HolidaySelectionResult(range: DateTimeRange(start: rangeStart!, end: rangeEnd!)));
                      } else if (rangeStart != null) {
                        Navigator.of(ctx).pop(HolidaySelectionResult(day: rangeStart!));
                      } else {
                        Navigator.of(ctx).pop(null);
                      }
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
              // FIX: dimensiuni finite pentru a evita intrinsic dimensions pe viewport shrink-wrapping
              content: SizedBox(
                height: maxHeight,
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // linia cu selecția + icon stânga copy
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Copiază din anul precedent',
                            icon: const Icon(Icons.content_copy),
                            onPressed: _copyFromPreviousYear,
                          ),
                          Expanded(
                            child: Text(
                              statusText(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _InlineRangeCalendar(
                        initialMonth: DateTime(init.year, init.month),
                        firstDate: DateTime(currentYear, 1, 1),
                        lastDate: effectiveLastDate,
                        start: rangeStart,
                        end: rangeEnd,
                        onDayTap: (d) {
                          if (!allowRange) {
                            setStateDialog(() {
                              rangeStart = d;
                              rangeEnd = null;
                            });
                            return;
                          }
                          setStateDialog(() {
                            if (rangeStart == null || (rangeStart != null && rangeEnd != null)) {
                              rangeStart = d;
                              rangeEnd = null;
                            } else {
                              if (d.isBefore(rangeStart!)) {
                                rangeStart = d;
                                rangeEnd = null;
                              } else if (d.isAtSameMomentAs(rangeStart!)) {
                                rangeEnd = null; // single
                              } else {
                                rangeEnd = d;
                              }
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAddDialog() async {
    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_readOnlyReason())));
      return;
    }
    final result = await _openSelectionDialog(initialDate: null, allowRange: true);
    if (result == null) return;
    if (result.range != null) {
      await _addRange(result.range!.start, result.range!.end);
    } else if (result.day != null) {
      await _addDate(result.day!);
    }
  }

  Future<void> _deleteRange(List<DateTime> range) async {
    final s = range.first;
    final e = range.last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ștergi intervalul?'),
        content: Text('Ești sigur că vrei să ștergi intervalul ${df.format(s)} – ${df.format(e)} din zilele libere?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anulează')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Șterge')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() {
      selectedDates.removeWhere((d) => !d.isBefore(s) && !d.isAfter(e));
      _dirty = true;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interval șters.')));
  }

  Future<void> _editRange(List<DateTime> range) async {
    final s = range.first;
    final e = range.last;
    final res = await _openSelectionDialog(initialStart: s, initialEnd: e, allowRange: true);
    if (res == null) return;
    final toAdd = <DateTime>[];
    if (res.range != null) {
      DateTime cur = DateTime(res.range!.start.year, res.range!.start.month, res.range!.start.day);
      final end = DateTime(res.range!.end.year, res.range!.end.month, res.range!.end.day);
      while (!cur.isAfter(end)) {
        toAdd.add(cur);
        cur = DateTime(cur.year, cur.month, cur.day + 1);
      }
    } else if (res.day != null) {
      final d = res.day!;
      toAdd.add(DateTime(d.year, d.month, d.day));
    } else {
      return;
    }
    if (!mounted) return;
    setState(() {
      selectedDates.removeWhere((d) => !d.isBefore(s) && !d.isAfter(e));
      for (final d in toAdd) {
        selectedDates.add(d);
      }
      _dirty = true;
    });
  }

  Future<void> save() async {
    if (saving) return;
    if (!mounted) return;

    if (editMode) {
      setState(() => editMode = false);
    }

    setState(() => saving = true);
    try {
      await _persistAll();

      final reportMonths = await Recalculator.listMonthsTouchedInDailyReports();
      final selectedYearPrefix = '${selectedYear.toString().padLeft(4, '0')}-';
      final monthsInSelectedYear =
      reportMonths.where((ym) => ym.startsWith(selectedYearPrefix)).toSet();

      await Recalculator.recalcAllDailyTotalsUsingSegments(months: monthsInSelectedYear);
      await Recalculator.reaggregateAndWriteMonthlyTotals(months: monthsInSelectedYear);

      final monthsToResetNorms = _allMonthsForYear(selectedYear);
      await _resetMonthlyNormsForMonths(monthsToResetNorms);

      await Recalculator.recalcMonthlyOvertimeForMonths(monthsInSelectedYear);
      _dirty = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sărbători legale salvate.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }



  Set<String> _allMonthsForYear(int year) {
    final yy = year.toString().padLeft(4, '0');
    return <String>{
      for (int month = 1; month <= 12; month++)
        '$yy-${month.toString().padLeft(2, '0')}'
    };
  }

  Future<void> _resetMonthlyNormsForMonths(Set<String> months) async {
    if (months.isEmpty) return;
    // Încarcă din DB setul global de sărbători legale
    await loadLegalHolidaysFromDb();

    final box = await Hive.openBox('monthly_norms_v1');
    final rawMap = box.get('map', defaultValue: <String, dynamic>{});
    final rawManual = box.get('manual_flags', defaultValue: <String, dynamic>{});

    final Map<String, double> stored = {
      for (final e in Map<String, dynamic>.from(rawMap).entries)
        e.key: (e.value is num ? (e.value as num).toDouble() : double.tryParse('${e.value}') ?? 0.0),
    };

    final Map<String, bool> manual = {
      for (final e in Map<String, dynamic>.from(rawManual).entries)
        e.key: e.value == true,
    };

    for (final ym in months) {
      if (ym.length < 7) continue;
      final int? year = int.tryParse(ym.substring(0, 4));
      final int? month = int.tryParse(ym.substring(5, 7));
      if (year == null || month == null) continue;
      final def = _defaultHoursForMonthUsingGlobalHolidays(year, month);
      stored[ym] = def;
      manual[ym] = false;
    }

    await box.put('map', stored);
    await box.put('manual_flags', manual);
  }

  int _workingDaysInMonthUsingGlobalHolidays(int year, int month) {
    final DateTime end;
    if (month == 12) {
      end = DateTime(year + 1, 1, 1).subtract(const Duration(days: 1));
    } else {
      end = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    }

    int count = 0;
    for (int day = 1; day <= end.day; day++) {
      final cur = DateTime(year, month, day);
      final weekday = cur.weekday; // 1=Mon ... 7=Sun
      if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
        continue;
      }
      final d = DateTime(cur.year, cur.month, cur.day);
      if (kRomanianLegalHolidays.contains(d)) {
        continue;
      }
      count++;
    }
    return count;
  }

  double _defaultHoursForMonthUsingGlobalHolidays(int year, int month) {
    final wd = _workingDaysInMonthUsingGlobalHolidays(year, month);
    return wd * 8.0;
  }
  /// confirmă ieșirea dacă există modificări nesalvate
  Future<bool> _confirmDiscardChanges() async {
    if (!_dirty) return true;
    final cont = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modificări nesalvate'),
        content: const Text('Ai modificări care nu sunt salvate. Dacă continui, acestea vor fi pierdute.'),
        actions: [
          TextButton(
            onPressed: () async {
              await save();
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            },
            child: const Text('Salvează'),
          ),
          if (!widget.requireAtLeastOneDate)
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continuă fără salvare'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
        ],
      ),
    );
    return cont ?? false;
  }

  Future<bool> _confirmExitWithoutLegalHolidays() async {
    if (selectedDates.isNotEmpty) return true;

    final cont = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atenție'),
        content: const Text(
          'Nu este setată nicio zi festivă legală.\n\n'
              'Această secțiune influențează calculul normei lunare de ore și diferențierea dintre zilele festive și cele regulate.\n\n'
              'Dacă nu introduci nicio zi festivă, aplicația va considera ca zile nelucrătoare doar sâmbăta și duminica.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Înapoi'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuă'),
          ),
        ],
      ),
    );

    return cont ?? false;
  }

  Future<void> _handleBackNavigation() async {
    final ok = await _confirmDiscardChanges();
    if (!context.mounted || !ok) return;

    final canExit = await _confirmExitWithoutLegalHolidays();
    if (!context.mounted || !canExit) return;

    // ignore: use_build_context_synchronously
    Navigator.of(context).pop();
  }

  List<int> availableYears() {
    final now = DateTime.now();
    final base = <int>[];
    for (int y = now.year - 5; y <= now.year + 1; y++) {
      base.add(y);
    }
    return base;
  }

  List<DateTime> datesForSelectedYear() {
    final list = selectedDates.where((d) => d.year == selectedYear).toList()
      ..sort((a, b) => a.compareTo(b));
    return list;
  }

  /// compactează date consecutive într-o listă de intervale [start, end]
  List<List<DateTime>> compressConsecutive(List<DateTime> dates) {
    final List<List<DateTime>> ranges = [];
    if (dates.isEmpty) return ranges;
    DateTime start = dates.first;
    DateTime prev = dates.first;
    for (int i = 1; i < dates.length; i++) {
      final d = dates[i];
      final nextCalendarDay = DateTime(prev.year, prev.month, prev.day + 1);
      final bool isNextDay =
          d.year == nextCalendarDay.year &&
              d.month == nextCalendarDay.month &&
              d.day == nextCalendarDay.day;
      final bool sameMonth = d.month == prev.month && d.year == prev.year;
      if (isNextDay && sameMonth) {
        prev = d;
        continue;
      } else {
        // închide intervalul curent la 'prev' și pornește unul nou de la 'd'
        ranges.add([start, prev]);
        start = d;
        prev = d;
      }
    }
    ranges.add([start, prev]);
    return ranges;
  }

  /// "25–27 decembrie" sau "30 noiembrie" sau "1–2 ianuarie"
  String formatRange(List<DateTime> range) {
    final s = range[0];
    final e = range[1];
    final String monthS = monthName.format(s);
    final String monthE = monthName.format(e);
    if (s.isAtSameMomentAs(e)) {
      return '${s.day} ${monthS.toLowerCase()}';
    }
    if (s.month == e.month) {
      return '${s.day}–${e.day} ${monthS.toLowerCase()}';
    }
    return '${s.day} ${monthS.toLowerCase()} – ${e.day} ${monthE.toLowerCase()}';
  }

  void _onSelectYear(int y) {
    final now = DateTime.now();
    final dec1 = DateTime(now.year, 12, 1);

    // Regula: anul viitor este greied (ne-selectabil) până la 1 decembrie.
    if (y == now.year + 1 && now.isBefore(dec1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anul $y este blocat până la 1 decembrie ${now.year}.')),
      );
      return; // nu schimbăm anul
    }

    setState(() {
      selectedYear = y;
      editMode = false;
    });
  }

  Future<String?> _showAutoFetchExistingExtrasDialog(
      int year,
      Set<DateTime> extraExistingDates,
      ) async {
    final sorted = extraExistingDates.toList()..sort((a, b) => a.compareTo(b));
    final preview = sorted.take(6).map((d) => df.format(d)).join(', ');
    final suffix = sorted.length > 6 ? '…' : '';

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Există zile deja introduse'),
        content: Text(
          'În anul $year există ${extraExistingDates.length} zile deja introduse în aplicație care nu fac parte din lista detectată automat.'
              '${preview.isNotEmpty ? '\n\nExemple: $preview$suffix' : ''}'
              '\n\nVrei să le păstrezi și să adaugi doar zilele lipsă sau să le ștergi și să rămână doar lista detectată automat?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: const Text('Păstrează-le'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('replace'),
            child: const Text('Doar lista automată'),
          ),
        ],
      ),
    );
  }

  Future<void> autoFetch() async {
    if (!mounted) return;
    final year = selectedYear;

    final existingYearDates = datesForSelectedYear()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    final detectedYearDates = (await auto.service.getZileFestive(year))
        .where((d) => d.year == year)
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    if (detectedYearDates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu au fost detectate zile festive pentru anul selectat.')),
        );
      }
      return;
    }

    final missingDates = detectedYearDates.difference(existingYearDates);
    final extraExistingDates = existingYearDates.difference(detectedYearDates);

    bool keepExtraExistingDates = true;
    if (extraExistingDates.isNotEmpty) {
      final decision = await _showAutoFetchExistingExtrasDialog(year, extraExistingDates);
      if (!mounted) return;
      if (decision == null) return;
      keepExtraExistingDates = decision == 'keep';
    }

    if (!mounted) return;
    final detectedDates = await auto.getNewDatesAndAskConfirm(
      context,
      year: year,
      existing: keepExtraExistingDates ? existingYearDates : const <DateTime>[],
      replaceWholeYear: !keepExtraExistingDates,
    );

    bool shouldShowFinalWarning = false;

    if (detectedDates.isEmpty) {
      if (mounted && keepExtraExistingDates && missingDates.isEmpty) {
        final text = extraExistingDates.isNotEmpty
            ? 'Nu există zile automate noi de adăugat. Zilele existente în plus au fost păstrate.'
            : 'Toate zilele detectate automat există deja în aplicație.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
        shouldShowFinalWarning = true;
      } else {
        return;
      }
    } else {
      if (!mounted) return;
      setState(() {
        if (!keepExtraExistingDates) {
          selectedDates.removeWhere((d) => d.year == year);
        }
        for (final d in detectedDates) {
          selectedDates.add(DateTime(d.year, d.month, d.day));
        }
        _dirty = true;
      });
      shouldShowFinalWarning = true;
    }

    if (mounted && shouldShowFinalWarning) {
      if (detectedDates.isNotEmpty) {
        final snackText = keepExtraExistingDates
            ? (extraExistingDates.isNotEmpty
            ? '${detectedDates.length} zile detectate automat au fost adăugate. ${extraExistingDates.length} zile existente în plus au fost păstrate.'
            : '${detectedDates.length} zile detectate automat au fost adăugate.')
            : 'Zilele festive pentru $year au fost înlocuite cu lista detectată automat.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snackText)),
        );
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ATENȚIE !!'),
          content: Text(
            'Lista zilelor festive pentru anul $year au fost introduse pe baza Codului Muncii și a regulilor existente la data creării aplicație (2026).  '
                'Pot apărea erori la introducere sau discrepante față de perioada actuală. '
                'Se recomandă VERIFICARE/CONFIRMARE manuală, '
                'deoarece aceste date influențează calculul normei lunare și al orelor de serviciu în zilele de sărbătoare.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Am înțeles'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = availableYears();
    if (!years.contains(selectedYear)) {
      selectedYear = DateTime.now().year;
    }
    final dates = datesForSelectedYear();
    final compactRanges = compressConsecutive(dates);

    // opacitate la acțiuni când anul e read-only (vizual „greyed”)
    final actionOpacity = _isReadOnly ? 0.45 : 1.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _handleBackNavigation();
            },
          ),
          title: const Text('Setare Zile Sarbatoare Legala'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          bottom: true,
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Linia 2: stânga "Adaugă zi festivă", dreapta "Salvează"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Opacity(
                      opacity: actionOpacity,
                      child: ElevatedButton.icon(
                        onPressed: () => _guardAction(_openAddDialog),
                        icon: const Icon(Icons.event),
                        label: const Text('Adăugă Zi Liberă'),
                      ),
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: actionOpacity,
                      child: ElevatedButton.icon(
                        onPressed: () => _guardAction(save),
                        icon: const Icon(Icons.save),
                        label: const Text('Salvează'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Linia 3: stânga buton An (dropdown), dreapta buton Edit
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Buton vizual activ care deschide meniul
                    OutlinedButton.icon(
                      onPressed: () => _yearMenuKey.currentState?.showButtonMenu(),
                      icon: const Icon(Icons.expand_more),
                      label: Text('$selectedYear'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                    // PopupMenuButton invizibil, doar pentru meniu
                    PopupMenuButton<int>(
                      key: _yearMenuKey,
                      tooltip: 'Alege anul',
                      onSelected: _onSelectYear,
                      itemBuilder: (ctx) {
                        final now = DateTime.now();
                        final dec1 = DateTime(now.year, 12, 1);
                        return years.map((y) {
                          // doar anul viitor e disabled înainte de 1 decembrie
                          final disabled = (y == now.year + 1 && now.isBefore(dec1));
                          return PopupMenuItem<int>(
                            value: y,
                            enabled: !disabled,
                            child: Row(
                              children: [
                                if (y == selectedYear) const Icon(Icons.check, size: 18),
                                if (y == selectedYear) const SizedBox(width: 6),
                                Text(
                                  '$y',
                                  style: TextStyle(
                                    color: disabled ? Theme.of(context).disabledColor : null,
                                  ),
                                ),
                                if (disabled) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.lock_clock, size: 16),
                                ],
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: const SizedBox.shrink(), // invizibil
                    ),

                    const SizedBox(width: 10),
                    // Caută automat — respectă regulile de read-only
                    Opacity(
                      opacity: 1.0,
                      child: ElevatedButton.icon(
                        onPressed: () => _guardAction(autoFetch),
                        icon: const Icon(Icons.search),
                        label: const Text('Caută automat'),
                      ),
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: actionOpacity,
                      child: IconButton(
                        tooltip: editMode ? 'Termină editarea' : 'Editează zilele',
                        icon: Icon(editMode ? Icons.done : Icons.edit),
                        onPressed: () => _guardAction(() {
                          setState(() => editMode = !editMode);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: compactRanges.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Încă nu s-a adăugat nicio zi festivă pentru anul selectat. Daca nu se introduce nici o zi festiva legala, norma lunara va fi calculata doar pentru zilele nelucratoare de sambata si duminica. ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
                    : (editMode
                    ? ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    8,
                    8,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  itemCount: compactRanges.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = compactRanges[i];
                    final title = formatRange(r);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.event_available),
                      title: Text(title),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editează intervalul',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _guardAction(() => _editRange(r)),
                          ),
                          IconButton(
                            tooltip: 'Șterge intervalul',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _guardAction(() => _deleteRange(r)),
                          ),
                        ],
                      ),
                    );
                  },
                )
                    : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    8,
                    8,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  itemCount: compactRanges.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final range = compactRanges[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.calendar_month),
                      title: Text(formatRange(range)),
                    );
                  },
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calendar inline cu highlight pentru interval (start/end și interior).
class _InlineRangeCalendar extends StatefulWidget {
  final DateTime initialMonth; // prima zi a lunii afișate
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onDayTap;

  const _InlineRangeCalendar({
    required this.initialMonth,
    required this.firstDate,
    required this.lastDate,
    required this.onDayTap,
    this.start,
    this.end,
  });

  @override
  State<_InlineRangeCalendar> createState() => _InlineRangeCalendarState();
}

class _InlineRangeCalendarState extends State<_InlineRangeCalendar> {
  late DateTime _visibleMonth; // 1st of month

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);

  void _nextMonth() {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    if (next.isAfter(widget.lastDate)) return;
    setState(() => _visibleMonth = next);
  }

  void _prevMonth() {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    if (prev.isBefore(widget.firstDate)) return;
    setState(() => _visibleMonth = prev);
  }

  bool _isDisabled(DateTime day) {
    return day.isBefore(widget.firstDate) || day.isAfter(widget.lastDate);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _inRange(DateTime day) {
    final s = widget.start;
    final e = widget.end;
    if (s == null) return false;
    if (e == null) return _isSameDay(day, s);
    return !day.isBefore(DateTime(s.year, s.month, s.day)) &&
        !day.isAfter(DateTime(e.year, e.month, e.day));
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = _monthStart(_visibleMonth);
    final monthEnd = _monthEnd(_visibleMonth);
    final int daysInMonth = monthEnd.day;

    // Header
    final String header = DateFormat.yMMMM('ro_RO').format(_visibleMonth);

    // Build grid (Mon..Sun)
    final int firstWeekday = (monthStart.weekday + 6) % 7; // Monday=0
    final cells = <Widget>[];

    // Weekday labels
    const weekdays = ['Lu', 'Ma', 'Mi', 'Jo', 'Vi', 'Sâ', 'Du'];
    cells.addAll(weekdays.map((w) =>
        Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(w, style: const TextStyle(fontWeight: FontWeight.w600))))));

    // Empty leading cells
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      final disabled = _isDisabled(date);
      final selected = _inRange(date);
      final isStart = widget.start != null && _isSameDay(date, widget.start!);
      final isEnd = widget.end != null && _isSameDay(date, widget.end!);

      BoxDecoration? deco;
      if (selected) {
        // in-range background
        deco = BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withAlpha((0.12 * 255).round()),
          borderRadius: BorderRadius.circular(6),
        );
      }
      if (isStart || isEnd) {
        deco = BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withAlpha((0.22 * 255).round()),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1),
        );
      }

      final child = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: (deco?.borderRadius as BorderRadius?) ?? BorderRadius.circular(6),
          onTap: disabled ? null : () => widget.onDayTap(date),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: deco,
            alignment: Alignment.center,
            height: 40,
            child: Text(
              '$day',
              style: TextStyle(
                color: disabled
                    ? Theme.of(context).disabledColor
                    : selected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
                fontWeight: (isStart || isEnd) ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );

      cells.add(child);
    }

    // trailing cells to complete rows to 7
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Luna anterioară',
              icon: const Icon(Icons.chevron_left),
              onPressed: _prevMonth,
            ),
            Expanded(
              child: Center(
                child: Text(header, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            IconButton(
              tooltip: 'Luna următoare',
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Material wrapping grid ensures InkWell gets painted & hit-tested immediately
        Material(
          type: MaterialType.transparency,
          child: GridView.count(
            crossAxisCount: 7,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: cells,
          ),
        ),
      ],
    );
  }
}

/// Dialog „Alege anul” — folosit dacă vrem varianta cu dialog (nefolosit acum)
class _YearPickerDialog extends StatefulWidget {
  final int initial;
  final List<int> years;
  const _YearPickerDialog({required this.initial, required this.years});

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _y;

  @override
  void initState() {
    super.initState();
    _y = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alege anul'),
      content: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _y,
              decoration: const InputDecoration(labelText: 'An', border: OutlineInputBorder()),
              items: widget.years
                  .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y')))
                  .toList(),
              onChanged: (v) => setState(() => _y = v ?? _y),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulează')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _y),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
