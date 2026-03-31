// /lib/screens/Adauga_modifica_serviciu/avansat/sectiune_observatii_foto.dart

import 'dart:io';

import 'package:flutter/material.dart';

class SectiuneObservatiiFoto extends StatelessWidget {
  final TextEditingController observationsCtrl;
  final List<String> photoPaths;
  final int? selectedPhotoIndex;
  final VoidCallback onAddPhoto;
  final void Function(String photoPath) onPreviewPhoto;
  final void Function(int index) onRecropPhoto;
  final void Function(int index) onRenamePhoto;
  final void Function(int index) onDeletePhoto;
  final void Function(int index, bool isSelected) onTogglePhotoSelection;

  const SectiuneObservatiiFoto({
    super.key,
    required this.observationsCtrl,
    required this.photoPaths,
    required this.selectedPhotoIndex,
    required this.onAddPhoto,
    required this.onPreviewPhoto,
    required this.onRecropPhoto,
    required this.onRenamePhoto,
    required this.onDeletePhoto,
    required this.onTogglePhotoSelection,
  });

  @override
  Widget build(BuildContext context) {
    final photoFileNames = photoPaths
        .where((item) => item.trim().isNotEmpty)
        .map((item) => item.split(Platform.pathSeparator).last)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: observationsCtrl,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Observații',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onAddPhoto,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Adaugă Foto'),
            ),
            if (photoFileNames.isNotEmpty)
              Text(
                '${photoFileNames.length} foto adăugate',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        if (photoPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photoPaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photoPath = photoPaths[index];
                final photoName = photoPath.split(Platform.pathSeparator).last;
                final isSelected = selectedPhotoIndex == index;

                return GestureDetector(
                  onLongPress: () {
                    onTogglePhotoSelection(index, isSelected);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 110,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => onPreviewPhoto(photoPath),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(photoPath),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 4,
                                right: 68,
                                child: Material(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => onRecropPhoto(index),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.crop,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (isSelected)
                              Positioned(
                                top: 4,
                                right: 36,
                                child: Material(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => onRenamePhoto(index),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (isSelected)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => onDeletePhoto(index),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 140,
                        child: Text(
                          photoName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}