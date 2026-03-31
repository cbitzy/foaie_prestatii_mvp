// lib/models/service_segment.dart

/// Tipurile posibile pentru o foaie/segment de serviciu.
enum SegmentType { tren, odihna, regie, mvStatie, mvDepou, acar, revizor, sefTura, alte }

String segmentTypeToStorage(SegmentType t) {
  switch (t) {
    case SegmentType.tren:
      return 'tren';
    case SegmentType.odihna:
      return 'odihna';
    case SegmentType.regie:
      return 'regie';
    case SegmentType.mvStatie:
      return 'mvStatie';
    case SegmentType.mvDepou:
      return 'mvDepou';
    case SegmentType.acar:
      return 'acar';
    case SegmentType.revizor:
      return 'revizor';
    case SegmentType.sefTura:
      return 'sefTura';
    case SegmentType.alte:
      return 'alte';
  }
}

SegmentType storageToSegmentType(String s) {
  switch (s) {
    case 'tren':
      return SegmentType.tren;
    case 'odihna':
      return SegmentType.odihna;
    case 'regie':
      return SegmentType.regie;
    case 'mvStatie':
      return SegmentType.mvStatie;
    case 'mvDepou':
      return SegmentType.mvDepou;
    case 'acar':
      return SegmentType.acar;
    case 'revizor':
      return SegmentType.revizor;
    case 'sefTura':
      return SegmentType.sefTura;
    case 'alte':
      return SegmentType.alte;
    default:
      return SegmentType.regie;
  }
}

String? _storageStringToNull(Object? value) {
  final text = value as String?;
  return (text?.trim().isEmpty ?? true) ? null : text;
}

String? _trimToNull(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

List<String>? _photoPathsToNull(Object? value) {
  if (value is! List) return null;
  final out = value
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return out.isEmpty ? null : out;
}

ServiceSegment serviceSegmentFromStorageMap(Map<String, dynamic> m) {
  return ServiceSegment(
    type: storageToSegmentType(m['type'] as String),
    start: DateTime.parse(m['start'] as String),
    end: DateTime.parse(m['end'] as String),
    trainNo: _storageStringToNull(m['trainNo']),
    otherDesc: _storageStringToNull(m['desc'] ?? m['description']),
    sheetSeries: _storageStringToNull(m['sheetSeries']),
    sheetNumber: _storageStringToNull(m['sheetNumber']),
    advancedMode: _storageStringToNull(m['advancedMode']),
    locomotiveType: _storageStringToNull(m['locomotiveType']),
    locomotiveClass: _storageStringToNull(m['locomotiveClass']),
    locomotiveNumber: _storageStringToNull(m['locomotiveNumber']),
    mecFormatorName: _storageStringToNull(m['mecFormatorName']),
    advancedObservations: _storageStringToNull(m['advancedObservations']),
    servicePerformedAs: _storageStringToNull(m['servicePerformedAs']),
    assistantMechanicName: _storageStringToNull(m['assistantMechanicName']),
    odihnaDormitor: _storageStringToNull(m['odihnaDormitor']),
    odihnaCamera: _storageStringToNull(m['odihnaCamera']),
    advancedPhotoPaths: _photoPathsToNull(m['advancedPhotoPaths']),
  );
}

Map<String, dynamic> serviceSegmentToStorageMap(
    ServiceSegment seg, {
      DateTime? startOverride,
      DateTime? endOverride,
    }) {
  final start = startOverride ?? seg.start;
  final end = endOverride ?? seg.end;

  return {
    'type': segmentTypeToStorage(seg.type),
    'trainNo': seg.type == SegmentType.tren ? seg.trainNo : null,
    'desc': seg.type == SegmentType.alte ? (seg.otherDesc ?? '').trim() : null,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'sheetSeries': _trimToNull(seg.sheetSeries),
    'sheetNumber': _trimToNull(seg.sheetNumber),
    'advancedMode': _trimToNull(seg.advancedMode),
    'locomotiveType': _trimToNull(seg.locomotiveType),
    'locomotiveClass': _trimToNull(seg.locomotiveClass),
    'locomotiveNumber': _trimToNull(seg.locomotiveNumber),
    'mecFormatorName': _trimToNull(seg.mecFormatorName),
    'advancedObservations': _trimToNull(seg.advancedObservations),
    'servicePerformedAs': _trimToNull(seg.servicePerformedAs),
    'assistantMechanicName': _trimToNull(seg.assistantMechanicName),
    'odihnaDormitor': _trimToNull(seg.odihnaDormitor),
    'odihnaCamera': _trimToNull(seg.odihnaCamera),
    'advancedPhotoPaths': _photoPathsToNull(seg.advancedPhotoPaths),
  };
}

/// Reprezintă o foaie individuală (un segment) din cadrul unui serviciu.
/// Exemple:
///  - tren 1763 de la 10.10.2025 17:00 la 10.10.2025 18:50
///  - odihna de la 11.10.2025 00:40 la 11.10.2025 04:50
class ServiceSegment {
  SegmentType type;
  DateTime start;
  DateTime end;
  /// Doar pentru type == SegmentType.tren
  String? trainNo;
  String? otherDesc; // pentru „Alte Activități”
  String? sheetSeries;
  String? sheetNumber;
  String? advancedMode;
  String? locomotiveType;
  String? locomotiveClass;
  String? locomotiveNumber;
  String? mecFormatorName;
  String? advancedObservations;
  String? servicePerformedAs;
  String? assistantMechanicName;
  String? odihnaDormitor;
  String? odihnaCamera;
  List<String>? advancedPhotoPaths;

  ServiceSegment({
    required this.type,
    required this.start,
    required this.end,
    this.trainNo,
    this.otherDesc,
    this.sheetSeries,
    this.sheetNumber,
    this.advancedMode,
    this.locomotiveType,
    this.locomotiveClass,
    this.locomotiveNumber,
    this.mecFormatorName,
    this.advancedObservations,
    this.servicePerformedAs,
    this.assistantMechanicName,
    this.odihnaDormitor,
    this.odihnaCamera,
    this.advancedPhotoPaths,
  });
}
