// /lib/screens/Adauga_modifica_serviciu/avansat/dialog_avansat.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/advanced_photo_cleanup_service.dart';
import 'formular_acar.dart';
import 'formular_alte_activitati.dart';
import 'formular_mv_depou.dart';
import 'formular_mv_statie.dart';
import 'formular_odihna.dart';
import 'formular_regie.dart';
import 'formular_revizor.dart';
import 'formular_sef_tura.dart';
import 'formular_tren.dart';
import 'model_avansat.dart';
import 'sectiune_observatii_foto.dart';

/// Dialog pentru setări avansate ale unui segment.
Future<SegmentAdvancedData?> showSegmentAdvancedDialog(
    BuildContext context, {
      required String segmentTypeLabel,
      required String dateLabel,
      String? trainNumber,
      SegmentAdvancedData? initialData,
    }) {
  return showDialog<SegmentAdvancedData>(
    context: context,
    builder: (ctx) => _SegmentAdvancedDialog(
      segmentTypeLabel: segmentTypeLabel,
      dateLabel: dateLabel,
      trainNumber: trainNumber,
      initialData: initialData,
    ),
  );
}

class _SegmentAdvancedDialog extends StatefulWidget {
  final String segmentTypeLabel;
  final String dateLabel;
  final String? trainNumber;
  final SegmentAdvancedData? initialData;

  const _SegmentAdvancedDialog({
    required this.segmentTypeLabel,
    required this.dateLabel,
    this.trainNumber,
    this.initialData,
  });

  @override
  State<_SegmentAdvancedDialog> createState() => _SegmentAdvancedDialogState();
}

class _SegmentAdvancedDialogState extends State<_SegmentAdvancedDialog> {
  SegmentAdvancedMode _mode = SegmentAdvancedMode.trenAvansat;

  final List<String> _locomotiveTypes = const [
    'EA',
    'EC',
    'LEMA',
    'LDE',
    'LDH',
    'CAT',
    'Desiro',
    'Introdu manual',
  ];
  String? _selectedLocomotiveType = 'EA';

  static const Map<String, List<String>> _classesByLocomotiveType = {
    'EA': ['40', '41', '42', 'Alta'],
    'EC': ['43', '44', 'Alta'],
    'LDE': [
      '60/060-DA',
      '61/060-DB',
      '62/060-DA-1',
      '63',
      '64/060-DG',
      '65',
      '66/060-DC',
      '67',
      '68',
      '69/040-DF',
      '70/060-DD',
      '71',
      '72/060-DF',
      '73',
      '74',
      'Alta',
    ],
    'LDH': [
      '80/040-DHC',
      '81',
      '82',
      '83',
      '84',
      '85',
      '86/LDH-70',
      '87',
      '89',
      'Alta',
    ],
  };

  String? _selectedLocomotiveClass = '40';

  final TextEditingController _locoNumberCtrl = TextEditingController();
  final TextEditingController _customLocoTypeCtrl = TextEditingController();
  final TextEditingController _customLocoClassCtrl = TextEditingController();
  final TextEditingController _observationsCtrl = TextEditingController();
  final TextEditingController odihnaDormitorCtrl = TextEditingController();
  final TextEditingController odihnaCameraCtrl = TextEditingController();

  final List<String> _mecNameOptions = const [
    'Mec. 1',
    'Mec. 2',
    'Altul',
  ];
  String _selectedMecOption = 'Altul';
  final TextEditingController _mecNameCtrl = TextEditingController();

  final List<String> servicePerformedAsOptions = const [
    'Mecanic (simplificat)',
    'Mecanic (completă)',
    'Mecanic Ajutor',
    'Mecanic Asistent',
    'Mecanic Formator',
    'Mecanic Evaluator',
  ];
  String selectedServicePerformedAs = 'Mecanic (simplificat)';
  final TextEditingController assistantMechanicCtrl = TextEditingController();

  final List<String> _photoPaths = [];
  final Set<String> _initialPhotoPaths = <String>{};
  bool _committed = false;
  int? _selectedPhotoIndex;

  bool get isOdihna => widget.segmentTypeLabel == 'Odihnă';

  bool get _isWorkInProgressType {
    switch (widget.segmentTypeLabel) {
      case 'MV Depou':
      case 'Regie':
      case 'Acar':
      case 'Revizor':
      case 'Șef Tura':
      case 'Alte Activități':
        return true;
      default:
        return false;
    }
  }

  Widget _buildAdvancedTypeForm({
    required List<String> locomotiveTypeItems,
  }) {
    switch (widget.segmentTypeLabel) {
      case 'MV Stație':
        return FormularMvStatieAvansat(
          selectedServicePerformedAs: selectedServicePerformedAs,
          assistantMechanicCtrl: assistantMechanicCtrl,
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          locoNumberCtrl: _locoNumberCtrl,
          onLocomotiveTypeSelected: _handleAdvancedLocomotiveTypeSelected,
          onServicePerformedAsChanged: _handleServicePerformedAsChanged,
        );
      case 'MV Depou':
        return FormularMvDepouAvansat(
          selectedServicePerformedAs: selectedServicePerformedAs,
          assistantMechanicCtrl: assistantMechanicCtrl,
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          locoNumberCtrl: _locoNumberCtrl,
          onLocomotiveTypeSelected: _handleAdvancedLocomotiveTypeSelected,
          onServicePerformedAsChanged: _handleServicePerformedAsChanged,
        );
      case 'Regie':
        return FormularRegieAvansat(
          selectedServicePerformedAs: selectedServicePerformedAs,
          assistantMechanicCtrl: assistantMechanicCtrl,
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          locoNumberCtrl: _locoNumberCtrl,
          onLocomotiveTypeSelected: _handleAdvancedLocomotiveTypeSelected,
          onServicePerformedAsChanged: _handleServicePerformedAsChanged,
        );
      case 'Acar':
        return FormularAcarAvansat(
          selectedServicePerformedAs: selectedServicePerformedAs,
          assistantMechanicCtrl: assistantMechanicCtrl,
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          locoNumberCtrl: _locoNumberCtrl,
          onLocomotiveTypeSelected: _handleAdvancedLocomotiveTypeSelected,
          onServicePerformedAsChanged: _handleServicePerformedAsChanged,
        );
      case 'Revizor':
        return FormularRevizorAvansat(
          selectedServicePerformedAs: selectedServicePerformedAs,
          assistantMechanicCtrl: assistantMechanicCtrl,
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          locoNumberCtrl: _locoNumberCtrl,
          onLocomotiveTypeSelected: _handleAdvancedLocomotiveTypeSelected,
          onServicePerformedAsChanged: _handleServicePerformedAsChanged,
        );
      case 'Șef Tura':
        return FormularSefTuraAvansat(
          selectedServicePerformedAs: selectedServicePerformedAs,
          assistantMechanicCtrl: assistantMechanicCtrl,
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          locoNumberCtrl: _locoNumberCtrl,
          onLocomotiveTypeSelected: _handleAdvancedLocomotiveTypeSelected,
          onServicePerformedAsChanged: _handleServicePerformedAsChanged,
        );
      case 'Alte Activități':
        return FormularAlteActivitatiAvansat(
          selectedServicePerformedAs: selectedServicePerformedAs,
          assistantMechanicCtrl: assistantMechanicCtrl,
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          locoNumberCtrl: _locoNumberCtrl,
          onLocomotiveTypeSelected: _handleAdvancedLocomotiveTypeSelected,
          onServicePerformedAsChanged: _handleServicePerformedAsChanged,
        );
      case 'Tren':
      default:
        return FormularTrenAvansat(
          selectedServicePerformedAs: selectedServicePerformedAs,
          assistantMechanicCtrl: assistantMechanicCtrl,
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          locoNumberCtrl: _locoNumberCtrl,
          onLocomotiveTypeSelected: _handleAdvancedLocomotiveTypeSelected,
          onServicePerformedAsChanged: _handleServicePerformedAsChanged,
        );
    }
  }

  Widget _buildFormareTypeForm({
    required List<String> locomotiveTypeItems,
    required String? selectedClassValue,
    required List<String> availableClasses,
  }) {
    switch (widget.segmentTypeLabel) {
      case 'MV Stație':
        return FormularMvStatieFormare(
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          selectedClassValue: selectedClassValue,
          availableClasses: availableClasses,
          locoNumberCtrl: _locoNumberCtrl,
          customLocoClassCtrl: _customLocoClassCtrl,
          selectedMecOption: _selectedMecOption,
          mecNameOptions: _mecNameOptions,
          mecNameCtrl: _mecNameCtrl,
          onLocomotiveTypeSelected: _handleFormareLocomotiveTypeSelected,
          onClassChanged: _handleLocomotiveClassChanged,
          onMecOptionChanged: _handleMecOptionChanged,
        );
      case 'MV Depou':
        return FormularMvDepouFormare(
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          selectedClassValue: selectedClassValue,
          availableClasses: availableClasses,
          locoNumberCtrl: _locoNumberCtrl,
          customLocoClassCtrl: _customLocoClassCtrl,
          selectedMecOption: _selectedMecOption,
          mecNameOptions: _mecNameOptions,
          mecNameCtrl: _mecNameCtrl,
          onLocomotiveTypeSelected: _handleFormareLocomotiveTypeSelected,
          onClassChanged: _handleLocomotiveClassChanged,
          onMecOptionChanged: _handleMecOptionChanged,
        );
      case 'Regie':
        return FormularRegieFormare(
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          selectedClassValue: selectedClassValue,
          availableClasses: availableClasses,
          locoNumberCtrl: _locoNumberCtrl,
          customLocoClassCtrl: _customLocoClassCtrl,
          selectedMecOption: _selectedMecOption,
          mecNameOptions: _mecNameOptions,
          mecNameCtrl: _mecNameCtrl,
          onLocomotiveTypeSelected: _handleFormareLocomotiveTypeSelected,
          onClassChanged: _handleLocomotiveClassChanged,
          onMecOptionChanged: _handleMecOptionChanged,
        );
      case 'Acar':
        return FormularAcarFormare(
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          selectedClassValue: selectedClassValue,
          availableClasses: availableClasses,
          locoNumberCtrl: _locoNumberCtrl,
          customLocoClassCtrl: _customLocoClassCtrl,
          selectedMecOption: _selectedMecOption,
          mecNameOptions: _mecNameOptions,
          mecNameCtrl: _mecNameCtrl,
          onLocomotiveTypeSelected: _handleFormareLocomotiveTypeSelected,
          onClassChanged: _handleLocomotiveClassChanged,
          onMecOptionChanged: _handleMecOptionChanged,
        );
      case 'Revizor':
        return FormularRevizorFormare(
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          selectedClassValue: selectedClassValue,
          availableClasses: availableClasses,
          locoNumberCtrl: _locoNumberCtrl,
          customLocoClassCtrl: _customLocoClassCtrl,
          selectedMecOption: _selectedMecOption,
          mecNameOptions: _mecNameOptions,
          mecNameCtrl: _mecNameCtrl,
          onLocomotiveTypeSelected: _handleFormareLocomotiveTypeSelected,
          onClassChanged: _handleLocomotiveClassChanged,
          onMecOptionChanged: _handleMecOptionChanged,
        );
      case 'Șef Tura':
        return FormularSefTuraFormare(
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          selectedClassValue: selectedClassValue,
          availableClasses: availableClasses,
          locoNumberCtrl: _locoNumberCtrl,
          customLocoClassCtrl: _customLocoClassCtrl,
          selectedMecOption: _selectedMecOption,
          mecNameOptions: _mecNameOptions,
          mecNameCtrl: _mecNameCtrl,
          onLocomotiveTypeSelected: _handleFormareLocomotiveTypeSelected,
          onClassChanged: _handleLocomotiveClassChanged,
          onMecOptionChanged: _handleMecOptionChanged,
        );
      case 'Alte Activități':
        return FormularAlteActivitatiFormare(
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          selectedClassValue: selectedClassValue,
          availableClasses: availableClasses,
          locoNumberCtrl: _locoNumberCtrl,
          customLocoClassCtrl: _customLocoClassCtrl,
          selectedMecOption: _selectedMecOption,
          mecNameOptions: _mecNameOptions,
          mecNameCtrl: _mecNameCtrl,
          onLocomotiveTypeSelected: _handleFormareLocomotiveTypeSelected,
          onClassChanged: _handleLocomotiveClassChanged,
          onMecOptionChanged: _handleMecOptionChanged,
        );
      case 'Tren':
      default:
        return FormularTrenFormare(
          selectedLocomotiveType: _selectedLocomotiveType,
          locomotiveTypeItems: locomotiveTypeItems,
          selectedClassValue: selectedClassValue,
          availableClasses: availableClasses,
          locoNumberCtrl: _locoNumberCtrl,
          customLocoClassCtrl: _customLocoClassCtrl,
          selectedMecOption: _selectedMecOption,
          mecNameOptions: _mecNameOptions,
          mecNameCtrl: _mecNameCtrl,
          onLocomotiveTypeSelected: _handleFormareLocomotiveTypeSelected,
          onClassChanged: _handleLocomotiveClassChanged,
          onMecOptionChanged: _handleMecOptionChanged,
        );
    }
  }

  Future<void> _handleAdvancedLocomotiveTypeSelected(String value) async {
    if (value == 'Introdu manual') {
      final manualValue = await askManualLocomotiveType();
      if (!mounted || manualValue == null) {
        return;
      }

      final normalized = manualValue.trim();
      if (normalized.isEmpty) {
        return;
      }

      setState(() {
        _customLocoTypeCtrl.text = normalized;
        _selectedLocomotiveType = normalized;
      });
      return;
    }

    setState(() {
      _selectedLocomotiveType = value;
      if (_locomotiveTypes.contains(value)) {
        _customLocoTypeCtrl.clear();
      }
    });
  }

  Future<void> _handleFormareLocomotiveTypeSelected(String value) async {
    if (value == 'Introdu manual') {
      final manualValue = await askManualLocomotiveType();
      if (!mounted || manualValue == null) {
        return;
      }

      final normalized = manualValue.trim();
      if (normalized.isEmpty) {
        return;
      }

      setState(() {
        _customLocoTypeCtrl.text = normalized;
        _selectedLocomotiveType = normalized;
        final classes = _classesForType(normalized);
        _selectedLocomotiveClass =
        classes.isNotEmpty ? classes.first : null;
      });
      return;
    }

    setState(() {
      _selectedLocomotiveType = value;
      final classes = _classesForType(value);
      _selectedLocomotiveClass =
      classes.isNotEmpty ? classes.first : null;
      if (_locomotiveTypes.contains(value)) {
        _customLocoTypeCtrl.clear();
      }
      _customLocoClassCtrl.clear();
    });
  }

  void _handleServicePerformedAsChanged(String value) {
    setState(() {
      selectedServicePerformedAs = value;
      if (selectedServicePerformedAs == 'Mecanic (simplificat)') {
        assistantMechanicCtrl.clear();
      }
    });
  }

  void _handleLocomotiveClassChanged(String? value) {
    setState(() {
      _selectedLocomotiveClass = value;
      _customLocoClassCtrl.clear();
    });
  }

  void _handleMecOptionChanged(String value) {
    setState(() {
      _selectedMecOption = value;
      if (_selectedMecOption != 'Altul') {
        _mecNameCtrl.text = _selectedMecOption;
      } else {
        _mecNameCtrl.clear();
      }
    });
  }
  List<String> _classesForType(String? locomotiveType) {
    if (locomotiveType == null) {
      return const ['Alta'];
    }
    final mapped = _classesByLocomotiveType[locomotiveType];
    if (mapped != null) {
      return mapped;
    }
    return const ['Alta'];
  }

  @override
  void initState() {
    super.initState();

    final initialData = widget.initialData;
    if (initialData == null) {
      return;
    }

    _mode = initialData.mode;

    final initialType = (initialData.locomotiveType ?? '').trim();
    if (initialType.isNotEmpty) {
      if (_locomotiveTypes.contains(initialType)) {
        _selectedLocomotiveType = initialType;
      } else {
        _selectedLocomotiveType = initialType;
        _customLocoTypeCtrl.text = initialType;
      }
    }

    final availableClasses = _classesForType(_selectedLocomotiveType);
    final initialClass = (initialData.locomotiveClass ?? '').trim();
    if (initialClass.isNotEmpty) {
      if (availableClasses.contains(initialClass)) {
        _selectedLocomotiveClass = initialClass;
      } else {
        _selectedLocomotiveClass = 'Alta';
        _customLocoClassCtrl.text = initialClass;
      }
    } else if (availableClasses.isNotEmpty) {
      _selectedLocomotiveClass = availableClasses.first;
    }

    _locoNumberCtrl.text = initialData.locomotiveNumber ?? '';
    _mecNameCtrl.text = initialData.mecFormatorName ?? '';
    _observationsCtrl.text = initialData.observations ?? '';
    odihnaDormitorCtrl.text = initialData.odihnaDormitor ?? '';
    odihnaCameraCtrl.text = initialData.odihnaCamera ?? '';
    assistantMechanicCtrl.text = initialData.assistantMechanicName ?? '';

    final savedServicePerformedAs = (initialData.servicePerformedAs ?? '').trim();
    if (savedServicePerformedAs == 'Mecanic') {
      selectedServicePerformedAs = 'Mecanic (simplificat)';
    } else if (savedServicePerformedAs == 'Mecanic (echipa completă)') {
      selectedServicePerformedAs = 'Mecanic (completă)';
    } else if (savedServicePerformedAs.isNotEmpty &&
        servicePerformedAsOptions.contains(savedServicePerformedAs)) {
      selectedServicePerformedAs = savedServicePerformedAs;
    }

    final savedPhotoPaths = initialData.photoPaths ?? const <String>[];
    _photoPaths
      ..clear()
      ..addAll(
        savedPhotoPaths.map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    _initialPhotoPaths
      ..clear()
      ..addAll(_photoPaths);

    final savedMecName = (initialData.mecFormatorName ?? '').trim();
    if (savedMecName.isNotEmpty) {
      if (_mecNameOptions.contains(savedMecName)) {
        _selectedMecOption = savedMecName;
      } else {
        _selectedMecOption = 'Altul';
      }
    }
  }

  Future<void> _deleteNewPathsRelativeToInitial(Iterable<String> paths) async {
    final toDelete = paths
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !_initialPhotoPaths.contains(e))
        .toSet();

    if (toDelete.isEmpty) {
      return;
    }

    await AdvancedPhotoCleanupService.deletePhotoFiles(toDelete);
  }

  @override
  void dispose() {
    if (!_committed) {
      AdvancedPhotoCleanupService.deletePhotoFiles(
        _photoPaths.where((e) => !_initialPhotoPaths.contains(e)),
      );
    }
    _locoNumberCtrl.dispose();
    _customLocoTypeCtrl.dispose();
    _customLocoClassCtrl.dispose();
    _observationsCtrl.dispose();
    odihnaDormitorCtrl.dispose();
    odihnaCameraCtrl.dispose();
    _mecNameCtrl.dispose();
    assistantMechanicCtrl.dispose();
    super.dispose();
  }

  Future<void> _showPhotoPreview(String photoPath) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(
                File(photoPath),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildTitle() {
    final tn = (widget.trainNumber ?? '').trim();
    if (tn.isNotEmpty) {
      return 'Tren $tn - ${widget.dateLabel}';
    }
    return '${widget.segmentTypeLabel} - ${widget.dateLabel}';
  }

  String sanitizeFileNamePart(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'foto' : cleaned;
  }

  String buildPhotoPrefix() {
    final rawTrainNumber = (widget.trainNumber ?? '').trim();
    final segmentPart = rawTrainNumber.isNotEmpty
        ? sanitizeFileNamePart(rawTrainNumber)
        : sanitizeFileNamePart(widget.segmentTypeLabel);
    final datePart = sanitizeFileNamePart(widget.dateLabel);
    return '${segmentPart}_$datePart';
  }

  int _nextDefaultPhotoIndex() {
    final prefix = '${buildPhotoPrefix()}_foto';
    final usedIndexes = <int>{};

    for (final photoPath in _photoPaths) {
      final fileName = photoPath.split(Platform.pathSeparator).last;
      final dot = fileName.lastIndexOf('.');
      final baseName = dot == -1 ? fileName : fileName.substring(0, dot);

      if (!baseName.startsWith(prefix)) {
        continue;
      }

      final suffix = baseName.substring(prefix.length);
      final value = int.tryParse(suffix);
      if (value != null && value > 0) {
        usedIndexes.add(value);
      }
    }

    var nextIndex = 1;
    while (usedIndexes.contains(nextIndex)) {
      nextIndex++;
    }

    return nextIndex;
  }

  Future<String?> askPhotoName([String initialValue = '']) async {
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nume fotografie'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Introdu numele fotografiei (opțional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Renunță'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Salvează'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<String?> askManualLocomotiveType() async {
    final controller = TextEditingController(
      text: _customLocoTypeCtrl.text.trim(),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tip locomotivă'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Introdu tipul locomotivei',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Renunță'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Salvează'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<CroppedFile?> cropPickedImage(XFile pickedFile) async {
    return ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Decupează foto',
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Decupează foto',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );
  }

  Future<String?> _chooseImageSource() async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cameră'),
              onTap: () => Navigator.of(sheetCtx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.of(sheetCtx).pop('gallery'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _copyPickedImageToAppStorage(
      CroppedFile croppedFile,
      String targetBaseName,
      ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/segment_advanced_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final sourceFile = File(croppedFile.path);
    var targetPath = '${photosDir.path}/$targetBaseName.jpg';
    var targetFile = File(targetPath);
    var duplicateIndex = 2;

    while (await targetFile.exists()) {
      targetPath = '${photosDir.path}/${targetBaseName}_$duplicateIndex.jpg';
      targetFile = File(targetPath);
      duplicateIndex++;
    }

    final savedFile = await sourceFile.copy(targetPath);
    return savedFile.path;
  }

  Future<void> _handleAddPhoto() async {
    final source = await _chooseImageSource();
    if (source == null) {
      return;
    }

    final picker = ImagePicker();
    XFile? pickedFile;

    if (source == 'camera') {
      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
    } else if (source == 'gallery') {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
    }

    if (pickedFile == null) {
      return;
    }

    final croppedFile = await cropPickedImage(pickedFile);
    if (croppedFile == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final customPhotoName = await askPhotoName();
    if (customPhotoName == null) {
      return;
    }

    final normalizedPhotoName = customPhotoName.trim().isEmpty
        ? 'foto${_nextDefaultPhotoIndex()}'
        : sanitizeFileNamePart(customPhotoName);

    final fileBaseName = '${buildPhotoPrefix()}_$normalizedPhotoName';

    final savedPath = await _copyPickedImageToAppStorage(
      croppedFile,
      fileBaseName,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _photoPaths.add(savedPath);
    });
  }

  Future<void> _handleRecropPhoto(int index) async {
    final oldPath = _photoPaths[index];
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: oldPath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Decupează foto',
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Decupează foto',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );

    if (croppedFile == null) {
      return;
    }

    final currentBaseName = _photoFileNameWithoutExtension(oldPath);
    final newPath = await _copyPickedImageToAppStorage(croppedFile, currentBaseName);

    await _deleteNewPathsRelativeToInitial([oldPath]);

    if (!mounted) {
      return;
    }

    setState(() {
      _photoPaths[index] = newPath;
      _selectedPhotoIndex = null;
    });
  }

  String _photoFileNameWithoutExtension(String photoPath) {
    final fileName = photoPath.split(Platform.pathSeparator).last;
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) {
      return fileName;
    }
    return fileName.substring(0, dot);
  }

  String _photoCustomNameFromPath(String photoPath) {
    final baseName = _photoFileNameWithoutExtension(photoPath);
    final prefix = '${buildPhotoPrefix()}_';
    if (baseName.startsWith(prefix)) {
      return baseName.substring(prefix.length);
    }
    return baseName;
  }

  Future<void> _renamePhoto(int index, String newCustomName) async {
    final oldPath = _photoPaths[index];
    final oldFile = File(oldPath);
    if (!await oldFile.exists()) {
      return;
    }

    final normalizedPhotoName = newCustomName.trim().isEmpty
        ? 'foto${_nextDefaultPhotoIndex()}'
        : sanitizeFileNamePart(newCustomName);
    final fileBaseName = '${buildPhotoPrefix()}_$normalizedPhotoName';

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/segment_advanced_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    var targetPath = '${photosDir.path}/$fileBaseName.jpg';
    var targetFile = File(targetPath);
    var duplicateIndex = 2;

    while (await targetFile.exists() && targetPath != oldPath) {
      targetPath = '${photosDir.path}/${fileBaseName}_$duplicateIndex.jpg';
      targetFile = File(targetPath);
      duplicateIndex++;
    }

    if (targetPath == oldPath) {
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPhotoIndex = null;
      });
      return;
    }

    final renamedFile = await oldFile.copy(targetPath);

    await _deleteNewPathsRelativeToInitial([oldPath]);

    if (!mounted) {
      return;
    }

    setState(() {
      _photoPaths[index] = renamedFile.path;
      _selectedPhotoIndex = null;
    });
  }

  Future<void> _handleRenamePhoto(int index) async {
    final photoPath = _photoPaths[index];
    final currentCustomName = _photoCustomNameFromPath(photoPath);
    final editedPhotoName = await askPhotoName(currentCustomName);
    if (editedPhotoName == null) {
      return;
    }

    await _renamePhoto(index, editedPhotoName);
  }

  Future<void> _handleDeletePhoto(int index) async {
    final photoPath = _photoPaths[index];
    await _deleteNewPathsRelativeToInitial([photoPath]);

    if (!mounted) {
      return;
    }

    setState(() {
      _photoPaths.removeAt(index);
      _selectedPhotoIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _buildTitle();

    final locomotiveTypeItems = <String>[
      ..._locomotiveTypes,
      if (_selectedLocomotiveType != null &&
          _selectedLocomotiveType!.trim().isNotEmpty &&
          !_locomotiveTypes.contains(_selectedLocomotiveType))
        _selectedLocomotiveType!,
    ];

    final List<String> availableClasses =
    _classesForType(_selectedLocomotiveType);
    final String? selectedClassValue = availableClasses.contains(
      _selectedLocomotiveClass,
    )
        ? _selectedLocomotiveClass
        : (availableClasses.isNotEmpty ? availableClasses.first : null);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(title),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOdihna && !_isWorkInProgressType) ...[
                SelectorTipInregistrareAvansata(
                  mode: _mode,
                  onChanged: (value) {
                    setState(() {
                      _mode = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (isOdihna)
                FormularOdihna(
                  dormitorCtrl: odihnaDormitorCtrl,
                  cameraCtrl: odihnaCameraCtrl,
                ),
              if (!isOdihna && _mode == SegmentAdvancedMode.trenAvansat)
                _buildAdvancedTypeForm(
                  locomotiveTypeItems: locomotiveTypeItems,
                ),
              if (!isOdihna && _mode == SegmentAdvancedMode.formare)
                _buildFormareTypeForm(
                  locomotiveTypeItems: locomotiveTypeItems,
                  selectedClassValue: selectedClassValue,
                  availableClasses: availableClasses,
                ),
              const SizedBox(height: 12),
              SectiuneObservatiiFoto(
                observationsCtrl: _observationsCtrl,
                photoPaths: _photoPaths,
                selectedPhotoIndex: _selectedPhotoIndex,
                onAddPhoto: _handleAddPhoto,
                onPreviewPhoto: _showPhotoPreview,
                onRecropPhoto: _handleRecropPhoto,
                onRenamePhoto: _handleRenamePhoto,
                onDeletePhoto: _handleDeletePhoto,
                onTogglePhotoSelection: (index, isSelected) {
                  setState(() {
                    _selectedPhotoIndex = isSelected ? null : index;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Renunță'),
        ),
        ElevatedButton(
          onPressed: () {
            SegmentAdvancedData result;

            if (isOdihna) {
              result = SegmentAdvancedData(
                mode: SegmentAdvancedMode.trenAvansat,
                odihnaDormitor: odihnaDormitorCtrl.text.trim().isEmpty
                    ? null
                    : odihnaDormitorCtrl.text.trim(),
                odihnaCamera: odihnaCameraCtrl.text.trim().isEmpty
                    ? null
                    : odihnaCameraCtrl.text.trim(),
                observations: _observationsCtrl.text.trim().isEmpty
                    ? null
                    : _observationsCtrl.text.trim(),
                photoPaths: _photoPaths.isEmpty
                    ? null
                    : List<String>.from(_photoPaths),
              );
            } else if (_isWorkInProgressType) {
              result = SegmentAdvancedData(
                mode: _mode,
                observations: _observationsCtrl.text.trim().isEmpty
                    ? null
                    : _observationsCtrl.text.trim(),
                photoPaths: _photoPaths.isEmpty
                    ? null
                    : List<String>.from(_photoPaths),
              );
            } else if (_mode == SegmentAdvancedMode.formare) {
              String? locomotiveTypeToSave;
              if (_selectedLocomotiveType == null ||
                  _selectedLocomotiveType!.trim().isEmpty ||
                  _selectedLocomotiveType == 'Introdu manual') {
                final customType = _customLocoTypeCtrl.text.trim();
                locomotiveTypeToSave = customType.isEmpty ? null : customType;
              } else {
                locomotiveTypeToSave = _selectedLocomotiveType;
              }

              String? locomotiveClassToSave;
              if (_selectedLocomotiveClass == 'Alta') {
                final customClass = _customLocoClassCtrl.text.trim();
                locomotiveClassToSave = customClass.isEmpty ? null : customClass;
              } else {
                locomotiveClassToSave = _selectedLocomotiveClass;
              }

              result = SegmentAdvancedData(
                mode: _mode,
                locomotiveType: locomotiveTypeToSave,
                locomotiveClass: locomotiveClassToSave,
                locomotiveNumber: _locoNumberCtrl.text.trim().isEmpty
                    ? null
                    : _locoNumberCtrl.text.trim(),
                mecFormatorName: _mecNameCtrl.text.trim().isEmpty
                    ? null
                    : _mecNameCtrl.text.trim(),
                observations: _observationsCtrl.text.trim().isEmpty
                    ? null
                    : _observationsCtrl.text.trim(),
                photoPaths: _photoPaths.isEmpty
                    ? null
                    : List<String>.from(_photoPaths),
              );
            } else {
              String? locomotiveTypeToSave;
              if (_selectedLocomotiveType == null ||
                  _selectedLocomotiveType!.trim().isEmpty ||
                  _selectedLocomotiveType == 'Introdu manual') {
                final customType = _customLocoTypeCtrl.text.trim();
                locomotiveTypeToSave = customType.isEmpty ? null : customType;
              } else {
                locomotiveTypeToSave = _selectedLocomotiveType;
              }

              result = SegmentAdvancedData(
                mode: _mode,
                locomotiveType: locomotiveTypeToSave,
                locomotiveNumber: _locoNumberCtrl.text.trim().isEmpty
                    ? null
                    : _locoNumberCtrl.text.trim(),
                observations: _observationsCtrl.text.trim().isEmpty
                    ? null
                    : _observationsCtrl.text.trim(),
                servicePerformedAs: selectedServicePerformedAs,
                assistantMechanicName: assistantMechanicCtrl.text.trim().isEmpty
                    ? null
                    : assistantMechanicCtrl.text.trim(),
                photoPaths: _photoPaths.isEmpty
                    ? null
                    : List<String>.from(_photoPaths),
              );
            }
            _committed = true;
            Navigator.of(context).pop(result);
          },
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}