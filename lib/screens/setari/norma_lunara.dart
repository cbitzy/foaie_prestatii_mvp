// /lib/screens/setari/norma_lunara.dart

// ignore_for_file: unnecessary_underscores, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../utils/holidays.dart'; // pentru încărcarea setului global de sărbători
import '../../services/recalculator.dart';
import '../../services/monthly_norms_events.dart';

/// Persistență pentru norme lunare
const String kMonthlyNormBox = 'monthly_norms_v1';
const String kMonthlyNormKey = 'map'; // Map<String yyyy-MM, double hours>
/// Flag: dacă o lună e setată manual (true) sau automat (false)
const String kMonthlyNormManualKey = 'manual_flags'; // Map<String yyyy-MM, bool isManual>

/// Persistență sărbători legale (aceeași ca în ecranul de sărbători)
const String kLegalHolidaysBox = 'legal_holidays_v1';
const String kLegalHolidaysKey = 'dates'; // List<String> ISO (yyyy-MM-dd)

String _keyYearMonth(int year, int month) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

class NormaLunaraScreen extends StatefulWidget {
  const NormaLunaraScreen({super.key});

  @override
  State<NormaLunaraScreen> createState() => _NormaLunaraScreenState();
}

class _NormaLunaraScreenState extends State<NormaLunaraScreen> {
  final Map<String, TextEditingController> _controllers = {}; // key yyyy-MM -> controller
  Map<String, double> _stored = {}; // valori salvate (DB)
  Map<String, bool> _manual = {};   // flag manual/auto per lună
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  // anul selectat
  int _selectedYear = DateTime.now().year;
  bool _editMode = false;

  // set local cu sărbători legale (din DB), pentru calcule implicite
  final Set<DateTime> _holidaySet = <DateTime>{};

  // cheie pentru meniul de ani
  final GlobalKey<PopupMenuButtonState<int>> _yearMenuKey = GlobalKey<PopupMenuButtonState<int>>();

  // luni atinse în sesiunea curentă (pentru evenimente)
  final Set<int> _monthsChangedSinceEdit = <int>{};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await _loadHolidaySetFromDb();
    await _loadNormsFromDb();
    // setează automat (și persistă) lunile fără override manual
    final autoMonths = await _ensureAutoSetAndPersistCurrentYear();
    if (autoMonths.isNotEmpty) {
      MonthlyNormsEvents().notify(
        year: _selectedYear,
        months: autoMonths,
        reason: 'auto',
      );
    }
    if (!mounted) return;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadHolidaySetFromDb() async {
    try {
      await loadLegalHolidaysFromDb();
    } catch (_) {
      // dacă utilitarul nu există, citim direct din Hive (mai jos)
    }
    final box = await Hive.openBox(kLegalHolidaysBox);
    final raw = box.get(kLegalHolidaysKey, defaultValue: const <String>[]);
    final list = List<String>.from(raw);
    _holidaySet
      ..clear()
      ..addAll(list.map((s) {
        final d = DateTime.parse(s);
        return DateTime(d.year, d.month, d.day);
      }));
  }

  Future<void> _loadNormsFromDb() async {
    final box = await Hive.openBox(kMonthlyNormBox);

    // orele
    final raw = box.get(kMonthlyNormKey, defaultValue: <String, dynamic>{});
    final map = Map<String, dynamic>.from(raw);
    _stored = {
      for (final e in map.entries)
        e.key: (e.value is num ? (e.value as num).toDouble() : double.tryParse('${e.value}') ?? 0.0)
    };

    // flag-urile manual/auto
    final rawManual = box.get(kMonthlyNormManualKey, defaultValue: <String, dynamic>{});
    final mapManual = Map<String, dynamic>.from(rawManual);
    _manual = {
      for (final e in mapManual.entries)
        e.key: (e.value is bool ? e.value as bool : (e.value.toString().toLowerCase() == 'true'))
    };

    _prepareControllersForYear(_selectedYear);
    _dirty = false;
  }

  void _prepareControllersForYear(int year) {
    for (int m = 1; m <= 12; m++) {
      final key = _keyYearMonth(year, m);
      final c = _controllers.putIfAbsent(key, () => TextEditingController());
      final def = _defaultHoursForMonth(year, m);
      final isManual = _manual[key] == true;

      if (isManual) {
        final stored = _stored[key];
        c.text = _formatHours(stored ?? def);
        continue;
      }

      if (_stored[key] == null || !_closeTo(_stored[key]!, def)) {
        _stored[key] = def;
      }
      if (_manual[key] != false) {
        _manual[key] = false;
      }

      c.text = _formatHours(def);
    }
  }

  // ---------- reguli an (ca la sărbători) ----------
  bool get _isPastYear {
    final now = DateTime.now();
    return _selectedYear < now.year;
  }

  bool get _isNextYearLocked {
    final now = DateTime.now();
    final dec1 = DateTime(now.year, 12, 1);
    return _selectedYear == now.year + 1 && now.isBefore(dec1);
  }

  bool get _isTooFarFuture {
    final now = DateTime.now();
    return _selectedYear > now.year + 1;
  }

  bool get _isReadOnly => _isPastYear || _isNextYearLocked || _isTooFarFuture;

  String _readOnlyReason() {
    final now = DateTime.now();
    if (_isPastYear) return 'Anul selectat este doar pentru vizualizare. Modificările sunt dezactivate.';
    if (_isNextYearLocked) return 'Anul viitor este blocat până la 1 decembrie ${now.year}.';
    return 'Modificările sunt dezactivate pentru anul selectat.';
  }

  List<int> _availableYears() {
    final now = DateTime.now();
    final years = <int>[];
    for (int y = now.year - 5; y <= now.year + 1; y++) {
      years.add(y);
    }
    return years;
  }

  void _onSelectYear(int y) async {
    final now = DateTime.now();
    final dec1 = DateTime(now.year, 12, 1);

    if (y == now.year + 1 && now.isBefore(dec1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anul $y este blocat până la 1 decembrie ${now.year}.')),
      );
      return;
    }

    final ok = await _confirmDiscardChanges();
    if (!mounted) return;
    if (!ok) return;

    setState(() {
      _selectedYear = y;
      _editMode = false;
      _dirty = false;
      _prepareControllersForYear(y);
      _monthsChangedSinceEdit.clear();
    });

    final autoMonths = await _ensureAutoSetAndPersistCurrentYear();
    if (autoMonths.isNotEmpty) {
      MonthlyNormsEvents().notify(
        year: _selectedYear,
        months: autoMonths,
        reason: 'auto',
      );
    }
  }

  // ---------- calcule implicite ----------

  bool _isHoliday(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _holidaySet.contains(d);
  }

  int _workingDaysInMonth(int year, int month) {
    final end = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    int count = 0;
    for (int day = 1; day <= end.day; day++) {
      final cur = DateTime(year, month, day);
      final weekday = cur.weekday; // 1=Mon ... 7=Sun
      if (weekday != DateTime.saturday &&
          weekday != DateTime.sunday &&
          !_isHoliday(cur)) {
        count++;
      }
    }
    return count;
  }

  double _defaultHoursForMonth(int year, int month) {
    return _workingDaysInMonth(year, month) * 8.0;
  }

  String _formatHours(double v) {
    return v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  bool _closeTo(double a, double b) => (a - b).abs() < 1e-9;

  // ---------- persist helpers ----------

  Future<void> _persistAllMaps() async {
    final box = await Hive.openBox(kMonthlyNormBox);
    await box.put(kMonthlyNormKey, _stored);
    await box.put(kMonthlyNormManualKey, _manual);
  }

  /// Returnează setul cu lunile (1..12) care au fost modificate AUTO și persistate.
  Future<Set<int>> _ensureAutoSetAndPersistCurrentYear() async {
    bool changed = false;
    final Set<int> monthsChanged = <int>{};
    for (int m = 1; m <= 12; m++) {
      final key = _keyYearMonth(_selectedYear, m);
      final isManual = _manual[key] == true;
      if (isManual) {
        final v = _stored[key];
        if (v != null) {
          final txt = _formatHours(v);
          if (_controllers[key]!.text != txt) {
            _controllers[key]!.text = txt;
          }
        }
        continue;
      }
      final def = _defaultHoursForMonth(_selectedYear, m);
      if (_stored[key] == null || !_closeTo(_stored[key]!, def)) {
        _stored[key] = def;
        changed = true;
        monthsChanged.add(m);
      }
      if (_manual[key] != false) {
        _manual[key] = false;
        changed = true;
      }
      final txt = _formatHours(def);
      if (_controllers[key]!.text != txt) {
        _controllers[key]!.text = txt;
      }
    }
    if (changed) {
      await _persistAllMaps();
    }
    if (!mounted) return monthsChanged;
    setState(() {});
    return monthsChanged;
  }

  /// Aplică modificările la „check” în memorie (fără persist) și marchează lunile atinse.
  void _applyEditsWithoutPersist() {
    for (int m = 1; m <= 12; m++) {
      final key = _keyYearMonth(_selectedYear, m);
      final text = _controllers[key]!.text.trim();

      if (text.isEmpty) {
        final def = _defaultHoursForMonth(_selectedYear, m);
        if (_stored[key] == null || !_closeTo(_stored[key]!, def) || _manual[key] != false) {
          _stored[key] = def;
          _manual[key] = false;
          _monthsChangedSinceEdit.add(m);
        }
        continue;
      }

      final parsed = double.tryParse(text.replaceAll(',', '.'));
      if (parsed == null) {
        continue;
      }

      final def = _defaultHoursForMonth(_selectedYear, m);
      if (_closeTo(parsed, def)) {
        if (_stored[key] == null || !_closeTo(_stored[key]!, def) || _manual[key] != false) {
          _stored[key] = def;
          _manual[key] = false;
          _monthsChangedSinceEdit.add(m);
        }
      } else {
        if (_stored[key] == null || !_closeTo(_stored[key]!, parsed) || _manual[key] != true) {
          _stored[key] = parsed;
          _manual[key] = true;
          _monthsChangedSinceEdit.add(m);
        }
      }
    }
    _dirty = _monthsChangedSinceEdit.isNotEmpty;
    if (!mounted) return;
    setState(() {});
  }

  // ---------- salvare ----------

  int? _firstInvalidEditedMonth() {
    for (int m = 1; m <= 12; m++) {
      final key = _keyYearMonth(_selectedYear, m);
      final text = _controllers[key]!.text.trim();
      if (text.isEmpty) continue;

      final parsed = double.tryParse(text.replaceAll(',', '.'));
      if (parsed == null) {
        return m;
      }
    }
    return null;
  }
  Future<bool> _save({
    bool showToast = true,
    bool applyPendingEdits = true,
    bool closeEditMode = true,
  }) async {
    if (_saving) return false;
    if (!mounted) return false;

    final invalidMonth = _firstInvalidEditedMonth();
    if (invalidMonth != null) {
      final monthName = DateFormat.MMMM('ro_RO').format(DateTime(2000, invalidMonth, 1));
      final label = '${monthName[0].toUpperCase()}${monthName.substring(1)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Valoare invalidă la $label. Corectează câmpul înainte de salvare.'),
        ),
      );
      return false;
    }

    if (_editMode && applyPendingEdits) {
      _applyEditsWithoutPersist();
      if (!mounted) return false;
      if (closeEditMode) {
        setState(() => _editMode = false);
      }
    }

    setState(() => _saving = true);
    try {
      await _persistAllMaps();

      // Emit eveniment pentru lunile atinse în această sesiune
      if (_monthsChangedSinceEdit.isNotEmpty) {
        MonthlyNormsEvents().notify(
          year: _selectedYear,
          months: Set<int>.from(_monthsChangedSinceEdit),
          reason: 'save',
        );
      }

      // În plus, recalculăm orele suplimentare pentru lunile din anul curent care au rapoarte
      final allMonths = await Recalculator.listMonthsTouchedInDailyReports();
      final affected = allMonths.where((ym) => ym.startsWith('${_selectedYear.toString()}-')).toSet();
      if (affected.isNotEmpty) {
        await Recalculator.recalcMonthlyOvertimeForMonths(affected);
      }

      _dirty = false;
      _monthsChangedSinceEdit.clear();

      if (!mounted) return false;
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Norme lunare salvate.')),
        );
      }
      if (!mounted) return false;
      setState(() {});
      return true;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
              final saved = await _save(showToast: false);
              if (!ctx.mounted) return;
              if (saved) Navigator.of(ctx).pop(true);
            },
            child: const Text('Salvează'),
          ),
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

  // ---------- UI helpers ----------

  /// Etichetă explicativă „după chenar” care arată dacă valoarea e automată sau manuală.
  Widget _inlineFlagLabel({required int year, required int month, required String key}) {
    final base = Theme.of(context).textTheme.bodySmall;
    final style = base?.copyWith(
      fontStyle: FontStyle.italic,
      color: (base.color ?? Colors.black).withAlpha((0.70 * 255).round()),
    );

    String label;
    if (_editMode) {
      final txt = _controllers[key]!.text.trim();
      if (txt.isEmpty) {
        label = '— setată automat (după zile lucrătoare și sărbători)';
      } else {
        final parsed = double.tryParse(txt.replaceAll(',', '.'));
        if (parsed == null) {
          label = (_manual[key] == true)
              ? '— setată manual'
              : '— setată automat (după zile lucrătoare și sărbători)';
        } else {
          final def = _defaultHoursForMonth(year, month);
          label = _closeTo(parsed, def)
              ? '— setată automat (după zile lucrătoare și sărbători)'
              : '— setată manual';
        }
      }
    } else {
      final txt = _controllers[key]!.text.trim();
      final parsed = txt.isEmpty ? null : double.tryParse(txt.replaceAll(',', '.'));
      final def = _defaultHoursForMonth(year, month);

      final isManualValue =
          _manual[key] == true ||
              (parsed != null && !_closeTo(parsed, def));

      label = isManualValue
          ? '— setată manual'
          : '— setată automat (după zile lucrătoare și sărbători)';
    }

    return Text(label, style: style, overflow: TextOverflow.ellipsis, maxLines: 2);
  }

  Widget _monthRow(int year, int month) {
    final monthName = DateFormat.MMMM('ro_RO').format(DateTime(2000, month, 1));
    final key = _keyYearMonth(year, month);
    final ctrl = _controllers[key]!;

    final bool isEditable = _editMode && !_isReadOnly;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${monthName[0].toUpperCase()}${monthName.substring(1)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.45,
                child: IgnorePointer(
                  ignoring: !isEditable, // blochează interacțiunea când nu edităm
                  child: TextField(
                    controller: ctrl,
                    readOnly: !isEditable,
                    showCursor: isEditable,
                    enableInteractiveSelection: isEditable,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {
                      if (!isEditable) return;
                      _monthsChangedSinceEdit.add(month);
                      setState(() => _dirty = true);
                    },
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: null,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((0.20 * 255).round()),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      disabledBorder: const OutlineInputBorder(), // păstrează conturul
                      enabledBorder: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              if (_editMode) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Șterge valoarea (revine pe auto imediat)',
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    // reset IMEDIAT la AUTO doar pentru luna curentă și persistă doar această lună
                    final pendingOtherMonths = Set<int>.from(_monthsChangedSinceEdit)
                      ..remove(month);

                    final def = _defaultHoursForMonth(year, month);
                    ctrl.text = _formatHours(def);
                    final keyYm = _keyYearMonth(year, month);
                    _stored[keyYm] = def;
                    _manual[keyYm] = false;

                    _monthsChangedSinceEdit
                      ..clear()
                      ..add(month);
                    _dirty = true;
                    setState(() {});

                    await _save(
                      showToast: false,
                      applyPendingEdits: false,
                      closeEditMode: false,
                    );
                    if (!mounted) return;

                    setState(() {
                      _monthsChangedSinceEdit
                        ..clear()
                        ..addAll(pendingOtherMonths);
                      _dirty = pendingOtherMonths.isNotEmpty;
                    });
                  },
                ),
              ],
              const SizedBox(width: 12),
              Expanded(child: _inlineFlagLabel(year: year, month: month, key: key)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // acțiuni greyed dacă read-only
    final actionOpacity = _isReadOnly ? 0.45 : 1.0;

    final years = _availableYears();
    if (!years.contains(_selectedYear)) {
      _selectedYear = DateTime.now().year;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await _confirmDiscardChanges();
        if (!mounted) return;
        if (ok) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await _confirmDiscardChanges();
              if (!mounted) return;
              if (ok) Navigator.of(context).pop();
            },
          ),
          title: const Text('Normă lunară'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            const SizedBox(height: 8),
            // Linia 1: buton anul (ca la sărbători) + buton edit + Salvează
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Trigger vizual pentru meniul anilor
                  OutlinedButton.icon(
                    onPressed: () => _yearMenuKey.currentState?.showButtonMenu(),
                    icon: const Icon(Icons.expand_more),
                    label: Text('An: $_selectedYear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                  // Meniul invizibil propriu-zis
                  PopupMenuButton<int>(
                    key: _yearMenuKey,
                    tooltip: 'Alege anul',
                    onSelected: _onSelectYear,
                    itemBuilder: (ctx) {
                      final now = DateTime.now();
                      final dec1 = DateTime(now.year, 12, 1);
                      return years.map((y) {
                        final disabled = (y == now.year + 1 && now.isBefore(dec1));
                        return PopupMenuItem<int>(
                          value: y,
                          enabled: !disabled,
                          child: Row(
                            children: [
                              if (y == _selectedYear) const Icon(Icons.check, size: 18),
                              if (y == _selectedYear) const SizedBox(width: 6),
                              Text(
                                '$y',
                                style: TextStyle(color: disabled ? Theme.of(context).disabledColor : null),
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
                    child: const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: actionOpacity,
                    child: IconButton(
                      tooltip: _editMode ? 'Termină editarea' : 'Editează',
                      icon: Icon(_editMode ? Icons.check : Icons.edit),
                      onPressed: () {
                        if (_isReadOnly) {
                          final msg = _readOnlyReason();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          return;
                        }
                        if (_editMode) {
                          _applyEditsWithoutPersist();
                          setState(() => _editMode = false);
                        } else {
                          setState(() => _editMode = true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Opacity(
                    opacity: actionOpacity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_isReadOnly) {
                          final msg = _readOnlyReason();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          return;
                        }
                        _save();
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Salvează'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Doar anul selectat
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 24),
                itemCount: 12,
                itemBuilder: (_, idx) => _monthRow(_selectedYear, idx + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
