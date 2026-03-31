// /lib/screens/Adauga_modifica_serviciu/avansat/formular_tren.dart

import 'package:flutter/material.dart';

import 'model_avansat.dart';

class SelectorTipInregistrareAvansata extends StatelessWidget {
  final SegmentAdvancedMode mode;
  final ValueChanged<SegmentAdvancedMode> onChanged;

  const SelectorTipInregistrareAvansata({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<SegmentAdvancedMode>(
      initialValue: mode,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tip înregistrare',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: SegmentAdvancedMode.trenAvansat,
          child: Text('Avansat'),
        ),
        DropdownMenuItem(
          value: SegmentAdvancedMode.formare,
          child: Text('Formare'),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        onChanged(value);
      },
    );
  }
}

class FormularTrenAvansat extends StatelessWidget {
  final String selectedServicePerformedAs;
  final TextEditingController assistantMechanicCtrl;
  final String? selectedLocomotiveType;
  final List<String> locomotiveTypeItems;
  final TextEditingController locoNumberCtrl;
  final Future<void> Function(String value) onLocomotiveTypeSelected;
  final ValueChanged<String> onServicePerformedAsChanged;

  const FormularTrenAvansat({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedServicePerformedAs,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Serviciu efectuat ca',
            border: OutlineInputBorder(),
          ),
          selectedItemBuilder: (context) => const [
            Text(
              'Mecanic',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Mecanic (simplificat)'),
            Text('Mecanic (completă)'),
            Text('Mecanic Ajutor'),
            Text('Mecanic Asistent'),
            Text('Mecanic Formator'),
            Text('Mecanic Evaluator'),
          ],
          items: const [
            DropdownMenuItem<String>(
              enabled: false,
              value: '__header_mecanic__',
              child: Text(
                'Mecanic',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DropdownMenuItem<String>(
              value: 'Mecanic (simplificat)',
              child: Padding(
                padding: EdgeInsets.only(left: 24),
                child: Text('Simplificat'),
              ),
            ),
            DropdownMenuItem<String>(
              value: 'Mecanic (completă)',
              child: Padding(
                padding: EdgeInsets.only(left: 24),
                child: Text('Echipă completă'),
              ),
            ),
            DropdownMenuItem<String>(
              value: 'Mecanic Ajutor',
              child: Text('Mecanic Ajutor'),
            ),
            DropdownMenuItem<String>(
              value: 'Mecanic Asistent',
              child: Text('Mecanic Asistent'),
            ),
            DropdownMenuItem<String>(
              value: 'Mecanic Formator',
              child: Text('Mecanic Formator'),
            ),
            DropdownMenuItem<String>(
              value: 'Mecanic Evaluator',
              child: Text('Mecanic Evaluator'),
            ),
          ],
          onChanged: (value) {
            if (value == null || value == '__header_mecanic__') {
              return;
            }
            onServicePerformedAsChanged(value);
          },
        ),
        if (selectedServicePerformedAs == 'Mecanic (completă)' ||
            selectedServicePerformedAs == 'Mecanic Ajutor' ||
            selectedServicePerformedAs == 'Mecanic Asistent') ...[
          const SizedBox(height: 8),
          TextField(
            controller: assistantMechanicCtrl,
            decoration: InputDecoration(
              labelText: selectedServicePerformedAs == 'Mecanic (completă)'
                  ? 'Numele mecanicului ajutor'
                  : 'Numele mecanicului',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        if (selectedServicePerformedAs == 'Mecanic Formator' ||
            selectedServicePerformedAs == 'Mecanic Evaluator') ...[
          const SizedBox(height: 8),
          TextField(
            controller: assistantMechanicCtrl,
            decoration: const InputDecoration(
              labelText: 'Numele mecanicului asistent',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedLocomotiveType,
                decoration: const InputDecoration(
                  labelText: 'Tip locomotivă',
                  border: OutlineInputBorder(),
                ),
                items: locomotiveTypeItems
                    .map(
                      (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) {
                    return;
                  }
                  await onLocomotiveTypeSelected(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: locoNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Număr',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class FormularTrenFormare extends StatelessWidget {
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

  const FormularTrenFormare({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedLocomotiveType,
          decoration: const InputDecoration(
            labelText: 'Locomotivă',
            border: OutlineInputBorder(),
          ),
          items: locomotiveTypeItems
              .map(
                (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
              .toList(),
          onChanged: (value) async {
            if (value == null) {
              return;
            }
            await onLocomotiveTypeSelected(value);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedClassValue,
                decoration: const InputDecoration(
                  labelText: 'Clasa',
                  border: OutlineInputBorder(),
                ),
                items: availableClasses
                    .map(
                      (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                    .toList(),
                onChanged: onClassChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: locoNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Număr',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        if (selectedClassValue == 'Alta') ...[
          const SizedBox(height: 8),
          TextField(
            controller: customLocoClassCtrl,
            decoration: const InputDecoration(
              hintText: 'scrie clasa locomotivei',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Nume Mec. Formator',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: selectedMecOption,
          decoration: const InputDecoration(
            labelText: 'Alege din listă',
            border: OutlineInputBorder(),
          ),
          items: mecNameOptions
              .map(
                (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            onMecOptionChanged(value);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: mecNameCtrl,
          decoration: const InputDecoration(
            hintText: 'scrie numele mecanicului formator',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}