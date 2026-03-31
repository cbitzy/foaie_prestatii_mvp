// lib/models/serviciu.dart
import 'package:foaie_prestatii_mvp/models/service_segment.dart';

/// Reprezintă un serviciu complet care grupează mai multe foi/segmente.
/// Numele este generat la salvare, de forma:
/// "Serviciu - <data inițială> - <data finală> / tren1/tren2/... (sau acar / MV Statie etc.)"
class Serviciu {
  String name;
  DateTime start; // începutul primului segment
  DateTime end;   // sfârșitul ultimului segment
  List<ServiceSegment> segments; // segmentele, în ordinea introducerii

  Serviciu({
    required this.name,
    required this.start,
    required this.end,
    required this.segments,
  });
}
