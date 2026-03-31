// ignore_for_file: unnecessary_underscores

import 'dart:async';

/// Eveniment emis când se schimbă normele lunare.
class MonthlyNormChange {
  final int year;
  final Set<int> months; // 1..12 afectate; poate fi gol dacă nu se cunoaște exact
  final String reason;   // 'save' | 'auto' | alt tag informativ
  final DateTime at;

  MonthlyNormChange({
    required this.year,
    required this.months,
    required this.reason,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  @override
  String toString() =>
      'MonthlyNormChange(year=$year, months=${months.toList()..sort()}, reason=$reason, at=$at)';
}

/// Bus simplu (broadcast) pentru a notifica ecranele/serviciile
/// interesate că s-au schimbat normele lunare.
class MonthlyNormsEvents {
  MonthlyNormsEvents._internal();
  static final MonthlyNormsEvents _inst = MonthlyNormsEvents._internal();
  factory MonthlyNormsEvents() => _inst;

  final StreamController<MonthlyNormChange> _ctrl =
  StreamController<MonthlyNormChange>.broadcast();

  /// Stream pe care se pot abona ecranele/serviciile.
  Stream<MonthlyNormChange> get stream => _ctrl.stream;

  /// Trimite un eveniment.
  void notify({
    required int year,
    required Set<int> months,
    required String reason,
  }) {
    _ctrl.add(MonthlyNormChange(year: year, months: months, reason: reason));
  }

  /// Închide stream-ul (de regulă nu e nevoie).
  void dispose() {
    _ctrl.close();
  }
}
