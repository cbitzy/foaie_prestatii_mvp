// /lib/services/advanced_photo_cleanup_service.dart

import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/service_segment.dart';
import 'report_storage_v2.dart';

class OrphanPhotoCleanupResult {
  final int existingFilesCount;
  final int referencedFilesCount;
  final int deletedFilesCount;

  const OrphanPhotoCleanupResult({
    required this.existingFilesCount,
    required this.referencedFilesCount,
    required this.deletedFilesCount,
  });
}

class AdvancedPhotoCleanupService {
  static const String photosDirectoryName = 'segment_advanced_photos';

  static Future<Directory> _getPhotosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$photosDirectoryName');
  }

  static Set<String> collectPhotoPathsFromStorageSegments(
      Iterable<Map<String, dynamic>> segments,
      ) {
    final out = <String>{};

    for (final segment in segments) {
      final raw = segment['advancedPhotoPaths'];
      if (raw is! List) {
        continue;
      }

      for (final item in raw) {
        final path = item.toString().trim();
        if (path.isNotEmpty) {
          out.add(path);
        }
      }
    }

    return out;
  }

  static Set<String> collectPhotoPathsFromServiceSegments(
      Iterable<ServiceSegment> segments,
      ) {
    final out = <String>{};

    for (final segment in segments) {
      final raw = segment.advancedPhotoPaths;
      if (raw == null || raw.isEmpty) {
        continue;
      }

      for (final item in raw) {
        final path = item.trim();
        if (path.isNotEmpty) {
          out.add(path);
        }
      }
    }

    return out;
  }

  static Future<void> deletePhotoFiles(Iterable<String> paths) async {
    for (final rawPath in paths) {
      final path = rawPath.trim();
      if (path.isEmpty) {
        continue;
      }

      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  static Future<Set<String>> collectStoredPhotoPathsForService(
      String serviceId,
      ) async {
    final storedSegments = await ReportStorageV2.listAllSegmentsForService(serviceId);
    return collectPhotoPathsFromStorageSegments(storedSegments);
  }

  static Future<void> deleteStoredPhotosForService(String serviceId) async {
    final photoPaths = await collectStoredPhotoPathsForService(serviceId);
    await deletePhotoFiles(photoPaths);
  }

  static Future<void> deleteRemovedStoredPhotosAfterEdit({
    required String serviceId,
    required List<ServiceSegment> updatedSegments,
  }) async {
    final oldPaths = await collectStoredPhotoPathsForService(serviceId);
    final newPaths = collectPhotoPathsFromServiceSegments(updatedSegments);
    final toDelete = oldPaths.difference(newPaths);

    if (toDelete.isEmpty) {
      return;
    }

    await deletePhotoFiles(toDelete);
  }

  static Future<OrphanPhotoCleanupResult> cleanupOrphanAdvancedPhotoFiles() async {
    final box = Hive.isBoxOpen(ReportStorageV2.boxName)
        ? Hive.box(ReportStorageV2.boxName)
        : await Hive.openBox(ReportStorageV2.boxName);

    final referencedPaths = <String>{};

    for (final key in box.keys) {
      if (key is! String || !key.endsWith('#seg')) {
        continue;
      }

      final byService = Map<String, dynamic>.from(box.get(key) ?? const <String, dynamic>{});

      for (final value in byService.values) {
        if (value is! List) {
          continue;
        }

        final segments = value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e));

        referencedPaths.addAll(collectPhotoPathsFromStorageSegments(segments));
      }
    }

    final photosDir = await _getPhotosDirectory();
    if (!await photosDir.exists()) {
      return OrphanPhotoCleanupResult(
        existingFilesCount: 0,
        referencedFilesCount: referencedPaths.length,
        deletedFilesCount: 0,
      );
    }

    final existingFiles = await photosDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();

    final orphanPaths = <String>[];
    for (final file in existingFiles) {
      if (!referencedPaths.contains(file.path)) {
        orphanPaths.add(file.path);
      }
    }

    await deletePhotoFiles(orphanPaths);

    return OrphanPhotoCleanupResult(
      existingFilesCount: existingFiles.length,
      referencedFilesCount: referencedPaths.length,
      deletedFilesCount: orphanPaths.length,
    );
  }
}