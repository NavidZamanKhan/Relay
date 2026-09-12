import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

class CacheUsage {
  const CacheUsage({
    required this.photosBytes,
    required this.voiceBytes,
    required this.fileBytes,
  });

  final int photosBytes;
  final int voiceBytes;
  final int fileBytes;

  int get totalBytes => photosBytes + voiceBytes + fileBytes;
  int get totalMb => (totalBytes / (1024 * 1024)).ceil();

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class CacheService {
  const CacheService({
    this.customDocsDir,
    this.customTempDir,
  });

  final Directory? customDocsDir;
  final Directory? customTempDir;

  Future<Directory?> _getTempDir() async {
    if (customTempDir != null) return customTempDir;
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _getDocsDir() async {
    if (customDocsDir != null) return customDocsDir;
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Scans application directories and Flutter image cache to compute exact bytes.
  Future<CacheUsage> calculateCacheUsage() async {
    int photosBytes = 0;
    int voiceBytes = 0;
    int fileBytes = 0;

    // Flutter in-memory decoded image cache
    try {
      photosBytes += PaintingBinding.instance.imageCache.currentSizeBytes;
    } catch (_) {}

    // Temporary files directory
    try {
      final tempDir = await _getTempDir();
      if (tempDir != null && await tempDir.exists()) {
        await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              final length = await entity.length();
              final path = entity.path.toLowerCase();
              if (path.endsWith('.jpg') ||
                  path.endsWith('.jpeg') ||
                  path.endsWith('.png') ||
                  path.endsWith('.webp') ||
                  path.endsWith('.gif')) {
                photosBytes += length;
              } else if (path.endsWith('.m4a') ||
                  path.endsWith('.aac') ||
                  path.endsWith('.mp3') ||
                  path.endsWith('.wav')) {
                voiceBytes += length;
              } else {
                fileBytes += length;
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    // Documents directory (avatar cache and voice cache)
    try {
      final docsDir = await _getDocsDir();
      if (docsDir != null && await docsDir.exists()) {
        final avatarDir = Directory('${docsDir.path}/relay_avatars');
        if (await avatarDir.exists()) {
          await for (final entity in avatarDir.list(recursive: false, followLinks: false)) {
            if (entity is File) {
              try {
                photosBytes += await entity.length();
              } catch (_) {}
            }
          }
        }

        final voiceDir = Directory('${docsDir.path}/relay_voice');
        if (await voiceDir.exists()) {
          await for (final entity in voiceDir.list(recursive: false, followLinks: false)) {
            if (entity is File) {
              try {
                voiceBytes += await entity.length();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    return CacheUsage(
      photosBytes: photosBytes,
      voiceBytes: voiceBytes,
      fileBytes: fileBytes,
    );
  }

  /// Purges local caches, evicts decoded images, and wipes temporary directories.
  Future<CacheUsage> purgeLocalCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    try {
      final tempDir = await _getTempDir();
      if (tempDir != null && await tempDir.exists()) {
        await for (final entity in tempDir.list(recursive: false, followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}

    try {
      final docsDir = await _getDocsDir();
      if (docsDir != null && await docsDir.exists()) {
        final avatarDir = Directory('${docsDir.path}/relay_avatars');
        if (await avatarDir.exists()) {
          await for (final entity in avatarDir.list(recursive: false, followLinks: false)) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }

        final voiceDir = Directory('${docsDir.path}/relay_voice');
        if (await voiceDir.exists()) {
          await for (final entity in voiceDir.list(recursive: false, followLinks: false)) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    return const CacheUsage(photosBytes: 0, voiceBytes: 0, fileBytes: 0);
  }
}

