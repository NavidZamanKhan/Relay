import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cryptographic service providing client-side X25519 key generation and secure local persistence.
class CryptoService {
  CryptoService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
              aOptions: AndroidOptions(),
            );

  final FlutterSecureStorage _storage;
  static const _privateKeyKey = 'relay_x25519_private_key';
  static const _publicKeyKey = 'relay_x25519_public_key';

  final _algorithm = X25519();

  /// Retrieves the existing base64-encoded public key or generates a new keypair.
  Future<String> getOrCreatePublicKey() async {
    final existingPub = await _storage.read(key: _publicKeyKey);
    if (existingPub != null) return existingPub;

    final keyPair = await _algorithm.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    final pubBase64 = base64Encode(publicKey.bytes);
    final privBase64 = base64Encode(privateBytes);

    await _storage.write(key: _publicKeyKey, value: pubBase64);
    await _storage.write(key: _privateKeyKey, value: privBase64);

    return pubBase64;
  }

  /// Returns the existing public key if already generated, otherwise null.
  Future<String?> getPublicKey() => _storage.read(key: _publicKeyKey);

  /// Clears stored cryptographic keys on sign-out or account wipe.
  Future<void> clearKeys() async {
    await _storage.delete(key: _publicKeyKey);
    await _storage.delete(key: _privateKeyKey);
  }
}
