import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../crypto/crypto_service.dart';

class BackupMetadata {
  const BackupMetadata({
    required this.timestamp,
    required this.conversationCount,
    required this.messageCount,
    required this.byteSize,
    required this.filePath,
  });

  final DateTime timestamp;
  final int conversationCount;
  final int messageCount;
  final int byteSize;
  final String filePath;

  String get formattedSize {
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class BackupService {
  const BackupService({CryptoService? cryptoService, this.customDir})
      : _crypto = cryptoService;

  final CryptoService? _crypto;
  final Directory? customDir;

  CryptoService get _cryptoService => _crypto ?? CryptoService();

  Future<File> _getBackupDirectory() async {
    final docs = customDir ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/relay_backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(dir.path);
  }


  /// Exports conversations and messages into a cryptographically secured bundle.
  Future<BackupMetadata> createEncryptedBackup({
    required String userId,
    required List<Map<String, dynamic>> conversationsData,
    required int totalMessages,
  }) async {
    final payload = {
      'v': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'userId': userId,
      'totalConversations': conversationsData.length,
      'totalMessages': totalMessages,
      'conversations': conversationsData,
    };

    final rawJson = jsonEncode(payload);

    // Encrypt the JSON payload using account-bound vault key and AES-GCM-256
    final vaultKey = await _cryptoService.deriveVaultKey(userId);
    final encrypted = await _cryptoService.encryptPayload(
      plaintext: rawJson,
      sharedSecretBytes: vaultKey,
    );

    final encryptedBundle = jsonEncode({
      'ciphertext': encrypted.ciphertext,
      'nonce': encrypted.nonce,
      'v': 1,
    });

    final dir = await _getBackupDirectory();
    final now = DateTime.now();
    final backupFile = File('${dir.path}/relay_backup_${now.millisecondsSinceEpoch}.enc');
    await backupFile.writeAsString(encryptedBundle, flush: true);

    final bytes = await backupFile.length();

    return BackupMetadata(
      timestamp: now,
      conversationCount: conversationsData.length,
      messageCount: totalMessages,
      byteSize: bytes,
      filePath: backupFile.path,
    );
  }

  /// Lists available local backups sorted by most recent first.
  Future<List<BackupMetadata>> listLocalBackups() async {
    final dir = await _getBackupDirectory();
    final directory = Directory(dir.path);
    if (!await directory.exists()) return [];

    final backups = <BackupMetadata>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.enc')) {
        try {
          final stat = await entity.stat();
          final length = await entity.length();
          backups.add(
            BackupMetadata(
              timestamp: stat.modified,
              conversationCount: 0,
              messageCount: 0,
              byteSize: length,
              filePath: entity.path,
            ),
          );
        } catch (_) {}
      }
    }

    backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return backups;
  }

  /// Validates and decrypts an encrypted backup bundle.
  Future<Map<String, dynamic>?> decryptBackupBundle(
    String encryptedBundle,
    String userId,
  ) async {
    try {
      final decoded = jsonDecode(encryptedBundle) as Map<String, dynamic>;
      final ciphertext = decoded['ciphertext'] as String?;
      final nonce = decoded['nonce'] as String?;
      if (ciphertext == null || nonce == null) return null;

      final vaultKey = await _cryptoService.deriveVaultKey(userId);
      final decryptedJson = await _cryptoService.decryptPayload(
        ciphertextBase64: ciphertext,
        nonceBase64: nonce,
        sharedSecretBytes: vaultKey,
      );

      final data = jsonDecode(decryptedJson) as Map<String, dynamic>;
      if (data['v'] != null && data['conversations'] != null) {
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

