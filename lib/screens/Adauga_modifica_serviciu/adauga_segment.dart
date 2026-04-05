// /lib/screens/Adauga_modifica_serviciu/adauga_segment.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/service_segment.dart';
import '../../services/advanced_photo_cleanup_service.dart';
import 'segment_avansat.dart';

/// Deschide dialogul „Adaugă/Editază segment”.
Future<ServiceSegment?> showAdaugaSegmentDialog(
    BuildContext context, {
      ServiceSegment? initial,
      ServiceSegment? previous,
      bool isFirstInService = true,
      DateTime? suggestedStart,
      DateTime? nowCap,
      DateTime? monthFirst,
      DateTime? monthLast,
    }) {
  return showDialog<ServiceSegment>(
    context: context,
    builder: (_) => _AdaugaSegmentDialog(
      initial: initial,
      previous: previous,
      isFirstInService: isFirstInService,
      initialSuggestedStart: suggestedStart,
      nowCap: nowCap,
      monthFirst: monthFirst,
      monthLast: monthLast,
    ),
  );
}

class _AdaugaSegmentDialog extends StatefulWidget {
  final ServiceSegment? initial;
  final ServiceSegment? previous;
  final bool isFirstInService;
  final DateTime? initialSuggestedStart;
  final DateTime? nowCap;
  final DateTime? monthFirst;
  final DateTime? monthLast;

  const _AdaugaSegmentDialog({
    this.initial,
    this.previous,
    required this.isFirstInService,
    this.initialSuggestedStart,
    this.nowCap,
    this.monthFirst,
    this.monthLast,
  });

  @override
  State<_AdaugaSegmentDialog> createState() => _AdaugaSegmentDialogState();
}

class _AdaugaSegmentDialogState extends State<_AdaugaSegmentDialog> {
  late SegmentType _type;
  late DateTime _start;
  late DateTime _end;

  final _trainCtrl = TextEditingController();
  final _trainFocus = FocusNode();

  final _otherCtrl = TextEditingController();
  final _otherFocus = FocusNode();

  final _sheetSeriesCtrl = TextEditingController();
  final _sheetSeriesFocus = FocusNode();

  final _sheetNumberCtrl = TextEditingController();
  final _sheetNumberFocus = FocusNode();

  bool _openingEndAfterStart = false;
  bool _sheetEnabled = false;
  bool _segmentCommitted = false;
  final Set<String> _initialPhotoPaths = <String>{};
  SegmentAdvancedData? _segmentAdvancedData;

  final df = DateFormat('dd.MM.yyyy');
  final tf = DateFormat('HH:mm');

  DateTime get _nowCap => widget.nowCap ?? DateTime.now();
  DateTime get _futureCap => _nowCap.add(const Duration(hours: 2));

  String _endLabelForDisplay() {
    final isMidnight = _end.hour == 0 &&
        _end.minute == 0 &&
        _end.second == 0 &&
        _end.millisecond == 0 &&
        _end.microsecond == 0;

    final startDay = DateTime(_start.year, _start.month, _start.day);
    final endDay = DateTime(_end.year, _end.month, _end.day);
    final isNextDay = endDay.difference(startDay).inDays == 1;

    if (isMidnight && isNextDay) {
      return '${df.format(_start)} 24:00';
    }

    return '${df.format(_end)} ${tf.format(_end)}';
  }

  bool get _isFixed12h =>
      _type == SegmentType.revizor ||
          _type == SegmentType.sefTura ||
          _type == SegmentType.mvStatie ||
          _type == SegmentType.mvDepou;
  // Prin design, butonul „Avansat” se activează doar după completarea
  // numărului foii și a unui interval orar valid; pentru Tren este obligatoriu
  // și numărul trenului.
  bool get canOpenAdvanced {
    final isTren = _type == SegmentType.tren;

    if (_sheetNumberCtrl.text.trim().isEmpty) {
      return false;
    }

    if (!_end.isAfter(_start)) {
      return false;
    }

    if (isTren && _trainCtrl.text.trim().isEmpty) {
      return false;
    }

    return true;
  }

  String _advancedDisabledMessage() {
    if (_type == SegmentType.tren) {
      return 'Butonul „Avansat” se activează după ce completezi numărul foii, numărul trenului și setezi un interval orar valid.';
    }

    return 'Butonul „Avansat” se activează după ce completezi numărul foii și setezi un interval orar valid.';
  }

  Future<void> _showAdvancedInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Informații Avansat - ${_segmentTypeLabel(_type)}'),
        content: Text(_advancedDisabledMessage()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  String _segmentTypeLabel(SegmentType type) {
    switch (type) {
      case SegmentType.tren:
        return 'Tren';
      case SegmentType.odihna:
        return 'Odihnă';
      case SegmentType.regie:
        return 'Regie';
      case SegmentType.revizor:
        return 'Revizor';
      case SegmentType.sefTura:
        return 'Șef Tura';
      case SegmentType.acar:
        return 'Acar';
      case SegmentType.mvStatie:
        return 'MV Stație';
      case SegmentType.mvDepou:
        return 'MV Depou';
      case SegmentType.alte:
        return 'Alte Activități';
    }
  }

  TimeOfDay _defaultTimeFor({required bool isStart}) {
    if (_type == SegmentType.acar) {
      if (isStart) return const TimeOfDay(hour: 7, minute: 0);
      return const TimeOfDay(hour: 15, minute: 0);
    }
    if (_isFixed12h) {
      if (isStart) {
        return TimeOfDay(hour: _start.hour, minute: _start.minute);
      } else {
        final startHour = _start.hour;
        final isNight = startHour >= 19;
        return isNight
            ? const TimeOfDay(hour: 7, minute: 0)
            : const TimeOfDay(hour: 19, minute: 0);
      }
    }
    final base = isStart ? _start : _end;
    return TimeOfDay(hour: base.hour, minute: base.minute);
  }

  DateTime _defaultDateFor({required bool isStart}) {
    if (isStart) return DateTime(_start.year, _start.month, _start.day);
    if (_type == SegmentType.acar) {
      return DateTime(_start.year, _start.month, _start.day);
    }
    if (_isFixed12h) {
      final isNight = _start.hour >= 19;
      if (isNight) {
        final next = DateTime(_start.year, _start.month, _start.day + 1);
        return next;
      } else {
        return DateTime(_start.year, _start.month, _start.day);
      }
    }
    // pentru tipurile obișnuite (ex. Tren), data pentru IEȘIRE
    // pornește din ziua START-ului
    return DateTime(_start.year, _start.month, _start.day);
  }

  Duration _minDurForType(SegmentType t) => Duration.zero;

  DateTime _clampToBounds(DateTime dt) {
    var out = dt;
    final mf = widget.monthFirst;
    final ml = widget.monthLast;
    if (mf != null && out.isBefore(mf)) out = mf;
    if (ml != null && out.isAfter(ml)) out = ml;
    if (out.isAfter(_futureCap)) out = _futureCap;
    return out;
  }

  void _presetEndFromStart() {
    if (_type == SegmentType.acar) {
      final baseDay = DateTime(_start.year, _start.month, _start.day);
      _end = _clampToBounds(
        DateTime(baseDay.year, baseDay.month, baseDay.day, 15, 0),
      );
      return;
    }
    if (_isFixed12h) {
      final isNight = _start.hour >= 19;
      final endDay = isNight
          ? DateTime(_start.year, _start.month, _start.day + 1)
          : DateTime(_start.year, _start.month, _start.day);
      final endHour = isNight ? 7 : 19;
      _end = _clampToBounds(
        DateTime(endDay.year, endDay.month, endDay.day, endHour, 0),
      );
      return;
    }
    _end = _clampToBounds(_start.add(const Duration(hours: 1)));
  }

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _type = widget.initial!.type;
      _start = _clampToBounds(widget.initial!.start);
      _end = _clampToBounds(widget.initial!.end);
      if (!_end.isAfter(_start)) {
        _end = _clampToBounds(_start.add(_minDurForType(_type)));
      }
      _trainCtrl.text = widget.initial!.trainNo ?? '';
      _otherCtrl.text = widget.initial!.otherDesc ?? '';
      _sheetSeriesCtrl.text = widget.initial!.sheetSeries ?? '';
      _sheetNumberCtrl.text = widget.initial!.sheetNumber ?? '';
      _sheetEnabled =
          _sheetSeriesCtrl.text.isNotEmpty || _sheetNumberCtrl.text.isNotEmpty;

      final advancedModeRaw = (widget.initial!.advancedMode ?? '').trim();
      final hasAdvancedData =
          advancedModeRaw.isNotEmpty ||
              (widget.initial!.locomotiveType ?? '').trim().isNotEmpty ||
              (widget.initial!.locomotiveClass ?? '').trim().isNotEmpty ||
              (widget.initial!.locomotiveNumber ?? '').trim().isNotEmpty ||
              (widget.initial!.mecFormatorName ?? '').trim().isNotEmpty ||
              (widget.initial!.advancedObservations ?? '').trim().isNotEmpty ||
              (widget.initial!.servicePerformedAs ?? '').trim().isNotEmpty ||
              (widget.initial!.assistantMechanicName ?? '').trim().isNotEmpty ||
              (widget.initial!.odihnaDormitor ?? '').trim().isNotEmpty ||
              (widget.initial!.odihnaCamera ?? '').trim().isNotEmpty ||
              (widget.initial!.advancedPhotoPaths != null &&
                  widget.initial!.advancedPhotoPaths!.isNotEmpty);

      if (hasAdvancedData) {
        _segmentAdvancedData = SegmentAdvancedData(
          mode: advancedModeRaw == 'formare'
              ? SegmentAdvancedMode.formare
              : SegmentAdvancedMode.trenAvansat,
          locomotiveType: widget.initial!.locomotiveType,
          locomotiveClass: widget.initial!.locomotiveClass,
          locomotiveNumber: widget.initial!.locomotiveNumber,
          mecFormatorName: widget.initial!.mecFormatorName,
          observations: widget.initial!.advancedObservations,
          servicePerformedAs: widget.initial!.servicePerformedAs,
          assistantMechanicName: widget.initial!.assistantMechanicName,
          odihnaDormitor: widget.initial!.odihnaDormitor,
          odihnaCamera: widget.initial!.odihnaCamera,
          photoPaths: widget.initial!.advancedPhotoPaths,
        );
      } else {
        _segmentAdvancedData = null;
      }
      final initialPhotoPaths =
          widget.initial!.advancedPhotoPaths ?? const <String>[];
      _initialPhotoPaths
        ..clear()
        ..addAll(
          initialPhotoPaths.map((e) => e.trim()).where((e) => e.isNotEmpty),
        );
    } else {
      _type = SegmentType.tren;
      final base = _clampToBounds(
        widget.initialSuggestedStart ??
            DateTime(_nowCap.year, _nowCap.month, _nowCap.day, 7, 0),
      );
      _start = base;
      _end = _clampToBounds(_start.add(const Duration(hours: 1)));
      if (!_end.isAfter(_start)) {
        _end = _clampToBounds(_start.add(_minDurForType(_type)));
      }
      _sheetEnabled = false;
      _segmentAdvancedData = null;
    }
  }

  @override
  void dispose() {
    if (!_segmentCommitted) {
      final currentPhotoPaths = (_segmentAdvancedData?.photoPaths ?? const <String>[])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      final toDelete = currentPhotoPaths.difference(_initialPhotoPaths);
      if (toDelete.isNotEmpty) {
        AdvancedPhotoCleanupService.deletePhotoFiles(toDelete);
      }
    }

    _trainCtrl.dispose();
    _trainFocus.dispose();
    _otherCtrl.dispose();
    _otherFocus.dispose();
    _sheetSeriesCtrl.dispose();
    _sheetSeriesFocus.dispose();
    _sheetNumberCtrl.dispose();
    _sheetNumberFocus.dispose();
    super.dispose();
  }

  void _clearAdvancedDataForTypeChange() {
    final currentPhotoPaths =
    (_segmentAdvancedData?.photoPaths ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final toDelete = currentPhotoPaths.difference(_initialPhotoPaths);
    if (toDelete.isNotEmpty) {
      AdvancedPhotoCleanupService.deletePhotoFiles(toDelete);
    }
    _segmentAdvancedData = null;
  }

  void _handleTypeSelected(SegmentType newType) {
    if (_type == newType) return;
    _clearAdvancedDataForTypeChange();
    _type = newType;
    _applyTypePreset();
  }

  void _applyTypePreset() {
    // Dacă adăugăm un segment nou de tip Odihnă imediat după un Tren,
    // vrem ca foaia să fie setată automat:
    //  - bifa "Foaie" să fie activată
    //  - seria și numărul foii să fie copiate de la Tren,
    // indiferent dacă utilizatorul a bifat deja manual foaia înainte.
    if (widget.initial == null &&
        widget.previous != null &&
        _type == SegmentType.odihna &&
        widget.previous!.type == SegmentType.tren) {
      final prevSeries = (widget.previous!.sheetSeries ?? '').trim();
      final prevNumber = (widget.previous!.sheetNumber ?? '').trim();
      if (prevSeries.isNotEmpty || prevNumber.isNotEmpty) {
        _sheetSeriesCtrl.text = prevSeries;
        _sheetNumberCtrl.text = prevNumber;
        _sheetEnabled = true;
      }
    }

    if (_type == SegmentType.acar || _isFixed12h) {
      _presetEndFromStart();
    }

    setState(() {});
  }

  Future<void> _showOverPickerWarning(DateTime cap) async {
    final capText = '${df.format(cap)} ${tf.format(cap)}';
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text('Dată din viitor nepermisă'),
        content: Text(
          'Nu poți alege o dată/oră din viitor. Asta inseamna ca serviciul nu a fost executat. '
              'Poți selecta cel mult până la $capText.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showMidnightAs24Warning(DateTime startDay, DateTime pickedDay) async {
    final startLabel = df.format(startDay);
    final pickedLabel = df.format(pickedDay);

    final isSameDay = startDay.year == pickedDay.year &&
        startDay.month == pickedDay.month &&
        startDay.day == pickedDay.day;

    final selectedText = isSameDay
        ? 'Ai ales ora 00:00 pe data $pickedLabel.'
        : 'Ai ales ora 00:00 pe data $pickedLabel (ziua următoare).';

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmare Nu / 24:00'),
        content: Text(
          '$selectedText\n\n00:00 este începutul zilei. Din motive tehnice, aplicatia nu poate afisa 24:00. Dacă ai intenționat sa introduci ora 24:00 pentru data $startLabel, apasă „24:00”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nu'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('24:00'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime({
    required bool isStart,
    bool autoChainToEnd = false,
  }) async {
    final firstDate = widget.monthFirst ?? DateTime(2020);
    final effectiveLast = (widget.monthLast != null && widget.monthLast!.isBefore(_futureCap)) ? widget.monthLast! : _futureCap;
    final lastDate = DateTime(effectiveLast.year, effectiveLast.month, effectiveLast.day);

    final bool isChainedEnd = (!isStart && _openingEndAfterStart);
    final DateTime initialDateForPickerRaw =
    isChainedEnd ? _defaultDateFor(isStart: false) : _defaultDateFor(isStart: isStart);

    DateTime initialDateForPicker = initialDateForPickerRaw;
    if (initialDateForPicker.isBefore(firstDate)) initialDateForPicker = firstDate;
    if (initialDateForPicker.isAfter(lastDate)) initialDateForPicker = lastDate;
    final d = await showDatePicker(
      context: context,
      initialDate: initialDateForPicker,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (d == null || !mounted) return;

    final t = await showTimePicker(
      context: context,
      initialTime: _defaultTimeFor(isStart: isStart),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null || !mounted) return;

    final rawPicked = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    final overCap = rawPicked.isAfter(_futureCap);
    var picked = _clampToBounds(rawPicked);

    if (overCap) {
      await _showOverPickerWarning(_futureCap);
    }

    if (!mounted) return;

    if (!isStart && picked.hour == 0 && picked.minute == 0) {
      final startDay = DateTime(_start.year, _start.month, _start.day);
      final pickedDay = DateTime(picked.year, picked.month, picked.day);
      final dayDiff = pickedDay.difference(startDay).inDays;

      if (dayDiff == 0 || dayDiff == 1) {
        final confirm24 = await _showMidnightAs24Warning(startDay, pickedDay);
        if (!mounted) return;
        if (confirm24 == true) {
          picked = DateTime(startDay.year, startDay.month, startDay.day + 1);
        }
      }
    }

    if (!mounted) return;

    setState(() {
      if (isStart) {
        _start = picked;
        if (autoChainToEnd) {
          _presetEndFromStart();
        }
      } else {
        _end = picked;
      }
    });

    if (isStart && autoChainToEnd && !_openingEndAfterStart) {
      _openingEndAfterStart = true;
      await _pickDateTime(isStart: false);
      _openingEndAfterStart = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final dialogWidth = (screenWidth * 0.95).clamp(320.0, 700.0).toDouble();

          final bool canOpenAdvanced = this.canOpenAdvanced;

          return SizedBox(
            width: dialogWidth,
            child: AlertDialog(
              insetPadding: EdgeInsets.zero,
              // titlul cât mai sus
              titlePadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              title: const Text('Adaugă segment'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foaie + checkbox + Seria
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('Foaie:'),
                        const SizedBox(width: 4),
                        Checkbox(
                          value: _sheetEnabled,
                          onChanged: (v) {
                            if (!mounted) return;
                            setState(() {
                              _sheetEnabled = v ?? false;
                              if (_sheetEnabled &&
                                  _sheetSeriesCtrl.text.trim().isEmpty) {
                                _sheetSeriesCtrl.text = 'S';
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        if (_sheetEnabled)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: 48,
                                      child: TextField(
                                        focusNode: _sheetSeriesFocus,
                                        controller: _sheetSeriesCtrl,
                                        textInputAction: TextInputAction.next,
                                        textAlign: TextAlign.right,
                                        textCapitalization:
                                        TextCapitalization.characters,
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(2),
                                          TextInputFormatter.withFunction(
                                                (oldValue, newValue) =>
                                                newValue.copyWith(
                                                  text:
                                                  newValue.text.toUpperCase(),
                                                  selection: newValue.selection,
                                                ),
                                          ),
                                        ],
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 8,
                                          ),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('Seria:'),
                                  ],
                                ),
                                const SizedBox(width: 32),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: 72,
                                      child: TextField(
                                        focusNode: _sheetNumberFocus,
                                        controller: _sheetNumberCtrl,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.right,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 8,
                                          ),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('Număr:'),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          const Flexible(
                            child: Text(
                              '(optional - seria și nr. foaie)',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    const Text('Tip segment'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Tren'),
                          selected: _type == SegmentType.tren,
                          onSelected: (_) {
                            if (!mounted) return;
                            _handleTypeSelected(SegmentType.tren);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Odihnă'),
                          selected: _type == SegmentType.odihna,
                          onSelected: (_) {
                            if (!mounted) return;
                            _handleTypeSelected(SegmentType.odihna);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Regie'),
                          selected: _type == SegmentType.regie,
                          onSelected: (_) {
                            if (!mounted) return;
                            _handleTypeSelected(SegmentType.regie);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Revizor'),
                          selected: _type == SegmentType.revizor,
                          onSelected: (_) {
                            if (!mounted) return;
                            _handleTypeSelected(SegmentType.revizor);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Șef Tura'),
                          selected: _type == SegmentType.sefTura,
                          onSelected: (_) {
                            if (!mounted) return;
                            _handleTypeSelected(SegmentType.sefTura);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Acar'),
                          selected: _type == SegmentType.acar,
                          onSelected: (_) {
                            if (!mounted) return;
                            _handleTypeSelected(SegmentType.acar);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('MV Stație'),
                          selected: _type == SegmentType.mvStatie,
                          onSelected: (_) {
                            if (!mounted) return;
                            _handleTypeSelected(SegmentType.mvStatie);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('MV Depou'),
                          selected: _type == SegmentType.mvDepou,
                          onSelected: (_) {
                            if (!mounted) return;
                            _handleTypeSelected(SegmentType.mvDepou);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Alte Activități'),
                          selected: _type == SegmentType.alte,
                          onSelected: (_) {
                            if (!mounted) return;
                            _handleTypeSelected(SegmentType.alte);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_type == SegmentType.tren)
                      TextField(
                        focusNode: _trainFocus,
                        controller: _trainCtrl,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) async =>
                            _pickDateTime(isStart: true, autoChainToEnd: true),
                        decoration: const InputDecoration(
                          labelText: 'Număr tren',
                          hintText: 'introdu numărul trenului',
                          hintStyle: TextStyle(fontStyle: FontStyle.italic),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (_type == SegmentType.tren) const SizedBox(height: 4),
                    if (_type == SegmentType.alte) const SizedBox(height: 12),
                    if (_type == SegmentType.alte)
                      TextField(
                        focusNode: _otherFocus,
                        controller: _otherCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Descriere activitate',
                          hintText: 'ex: școală, analiză SC, alte activități...',
                          hintStyle: TextStyle(fontStyle: FontStyle.italic),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          _pickDateTime(isStart: true, autoChainToEnd: true),
                      child: Text(
                        'Intrare serviciu: ${df.format(_start)} ${tf.format(_start)}',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickDateTime(isStart: false),
                      child: Text(
                        'Iesire serviciu: ${_endLabelForDisplay()}',
                      ),
                    ),

                    const SizedBox(height: 4),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: canOpenAdvanced
                          ? OutlinedButton(
                        onPressed: () async {
                          final result = await showSegmentAdvancedDialog(
                            context,
                            segmentTypeLabel: _segmentTypeLabel(_type),
                            dateLabel: df.format(_start),
                            trainNumber: _type == SegmentType.tren
                                ? _trainCtrl.text.trim()
                                : null,
                            initialData: _segmentAdvancedData,
                          );
                          if (!mounted || result == null) return;
                          setState(() {
                            _segmentAdvancedData = result;
                          });
                        },
                        child: const Text('Avansat'),
                      )
                          : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          await _showAdvancedInfoDialog();
                        },
                        child: AbsorbPointer(
                          child: OutlinedButton(
                            onPressed: null,
                            child: const Text('Avansat'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anulează'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!_end.isAfter(_start)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ieșirea trebuie să fie după Intrarea.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (_type == SegmentType.tren &&
                        _trainCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Introdu numărul trenului.'),
                        ),
                      );
                      return;
                    }
                    if (_type == SegmentType.alte &&
                        _otherCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Introdu descrierea pentru „Alte Activități”.',
                          ),
                        ),
                      );
                      return;
                    }

                    _segmentCommitted = true;
                    Navigator.pop(
                      context,
                      ServiceSegment(
                        type: _type,
                        start: _start,
                        end: _end,
                        trainNo: _type == SegmentType.tren
                            ? _trainCtrl.text.trim()
                            : null,
                        otherDesc: _type == SegmentType.alte
                            ? _otherCtrl.text.trim()
                            : null,
                        sheetSeries: _sheetSeriesCtrl.text.trim().isEmpty
                            ? null
                            : _sheetSeriesCtrl.text.trim(),
                        sheetNumber: _sheetNumberCtrl.text.trim().isEmpty
                            ? null
                            : _sheetNumberCtrl.text.trim(),
                        advancedMode: (_type == SegmentType.odihna ||
                            _segmentAdvancedData == null)
                            ? null
                            : (_segmentAdvancedData!.mode ==
                            SegmentAdvancedMode.formare
                            ? 'formare'
                            : 'trenAvansat'),
                        locomotiveType: _segmentAdvancedData?.locomotiveType,
                        locomotiveClass: _segmentAdvancedData?.locomotiveClass,
                        locomotiveNumber: _segmentAdvancedData?.locomotiveNumber,
                        mecFormatorName: _segmentAdvancedData?.mecFormatorName,
                        advancedObservations: _segmentAdvancedData?.observations,
                        servicePerformedAs:
                        _segmentAdvancedData?.servicePerformedAs,
                        assistantMechanicName:
                        _segmentAdvancedData?.assistantMechanicName,
                        odihnaDormitor: _segmentAdvancedData?.odihnaDormitor,
                        odihnaCamera: _segmentAdvancedData?.odihnaCamera,
                        advancedPhotoPaths: _segmentAdvancedData?.photoPaths,
                      ),
                    );
                  },
                  child: const Text('Salvează'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
