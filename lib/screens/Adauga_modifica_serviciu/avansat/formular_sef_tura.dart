// /lib/screens/Adauga_modifica_serviciu/avansat/formular_sef_tura.dart

import 'package:flutter/material.dart';

class FormularSefTuraAvansat extends StatelessWidget {
  final String selectedServicePerformedAs;
  final TextEditingController assistantMechanicCtrl;
  final String? selectedLocomotiveType;
  final List<String> locomotiveTypeItems;
  final TextEditingController locoNumberCtrl;
  final Future<void> Function(String value) onLocomotiveTypeSelected;
  final ValueChanged<String> onServicePerformedAsChanged;

  const FormularSefTuraAvansat({
    super.key,
    required this.selectedServicePerformedAs,
    required this.assistantMechanicCtrl,
    required this.selectedLocomotiveType,
    required this.locomotiveTypeItems,
    required this.locoNumberCtrl,
    required this.onLocomotiveTypeSelected,
    required this.onServicePerformedAsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return const Text('ACEASTA ZONA ESTE INCA IN LUCRU');
  }
}

class FormularSefTuraFormare extends StatelessWidget {
  final String? selectedLocomotiveType;
  final List<String> locomotiveTypeItems;
  final String? selectedClassValue;
  final List<String> availableClasses;
  final TextEditingController locoNumberCtrl;
  final TextEditingController customLocoClassCtrl;
  final String selectedMecOption;
  final List<String> mecNameOptions;
  final TextEditingController mecNameCtrl;
  final Future<void> Function(String value) onLocomotiveTypeSelected;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String> onMecOptionChanged;

  const FormularSefTuraFormare({
    super.key,
    required this.selectedLocomotiveType,
    required this.locomotiveTypeItems,
    required this.selectedClassValue,
    required this.availableClasses,
    required this.locoNumberCtrl,
    required this.customLocoClassCtrl,
    required this.selectedMecOption,
    required this.mecNameOptions,
    required this.mecNameCtrl,
    required this.onLocomotiveTypeSelected,
    required this.onClassChanged,
    required this.onMecOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return const Text('ACEASTA ZONA ESTE INCA IN LUCRU');
  }
}