//import 'package:flutter/material.dart';

/// Tipul de înregistrare avansată pentru segment.
enum SegmentAdvancedMode {
  trenAvansat,
  formare,
}

/// Datele completate în fereastra avansată.
class SegmentAdvancedData {
  final SegmentAdvancedMode mode;
  final String? locomotiveType;
  final String? locomotiveClass;
  final String? locomotiveNumber;
  final String? mecFormatorName;
  final String? observations;
  final String? servicePerformedAs;
  final String? assistantMechanicName;
  final String? odihnaDormitor;
  final String? odihnaCamera;
  final List<String>? photoPaths;

  SegmentAdvancedData({
    required this.mode,
    this.locomotiveType,
    this.locomotiveClass,
    this.locomotiveNumber,
    this.mecFormatorName,
    this.observations,
    this.servicePerformedAs,
    this.assistantMechanicName,
    this.odihnaDormitor,
    this.odihnaCamera,
    this.photoPaths,
  });
}