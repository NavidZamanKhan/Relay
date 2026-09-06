import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cryptographic service providing client-side X25519 key management,
/// Diffie-Hellman shared secret derivation, and secure local persistence.
class CryptoService {
  CryptoService({FlutterSecureStorage? storage, X25519? algorithm})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
              aOptions: AndroidOptions(),
            ),
        _algorithm = algorithm ?? X25519();

  final FlutterSecureStorage _storage;
  final X25519 _algorithm;

  static const _privateKeyKey = 'relay_x25519_private_key';
  static const _publicKeyKey = 'relay_x25519_public_key';

  Future<String>? _keyGenInFlight;

  /// Retrieves the existing base64-encoded public key or securely generates a new keypair.
  Future<String> getOrCreatePublicKey() async {
    if (_keyGenInFlight != null) {
      return _keyGenInFlight!;
    }

    _keyGenInFlight = _getOrCreatePublicKeyInternal();
    try {
      return await _keyGenInFlight!;
    } finally {
      _keyGenInFlight = null;
    }
  }

  Future<String> _getOrCreatePublicKeyInternal() async {
    final existingPub = await _storage.read(key: _publicKeyKey);
    final existingPriv = await _storage.read(key: _privateKeyKey);

    // Defense-in-depth: Ensure both public and private keys exist locally.
    // If one is missing (e.g. partial storage write or corrupted device state),
    // regenerate both to prevent unusable orphan public keys.
    if (existingPub != null &&
        existingPriv != null &&
        existingPub.isNotEmpty &&
        existingPriv.isNotEmpty) {
      return existingPub;
    }

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

  /// Derives an X25519 shared secret bytes with a remote peer's public key.
  ///
  /// The returned shared secret can be used with AES-GCM or Argon2/HKDF for message encryption.
  Future<List<int>> deriveSharedSecret({
    required String peerPublicKeyBase64,
  }) async {
    final privBase64 = await _storage.read(key: _privateKeyKey);
    if (privBase64 == null) {
      throw StateError('Cannot derive shared secret: local private key missing.');
    }

    final privBytes = base64Decode(privBase64);
    final peerPubBytes = base64Decode(peerPublicKeyBase64);

    // Defense-in-depth: Validate X25519 key size (must be 32 bytes)
    if (peerPubBytes.length != 32) {
      throw ArgumentError(
        'Invalid peer public key size: expected 32 bytes, got ${peerPubBytes.length}.',
      );
    }

    final localKeyPair = await _algorithm.newKeyPairFromSeed(privBytes);
    final peerPublicKey = SimplePublicKey(
      peerPubBytes,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _algorithm.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: peerPublicKey,
    );

    return sharedSecret.extractBytes();
  }

  /// Clears stored cryptographic keys on sign-out or account wipe.
  Future<void> clearKeys() async {
    await _storage.delete(key: _publicKeyKey);
    await _storage.delete(key: _privateKeyKey);
  }
}
