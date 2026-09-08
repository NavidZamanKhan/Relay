import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cryptographic service providing client-side X25519 key management,
/// Diffie-Hellman shared secret derivation, and secure local persistence.
class CryptoService {
  CryptoService({
    FlutterSecureStorage? storage,
    X25519? algorithm,
    AesGcm? cipher,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
              aOptions: AndroidOptions(),
            ),
        _algorithm = algorithm ?? X25519(),
        _cipher = cipher ?? AesGcm.with256bits();

  final FlutterSecureStorage _storage;
  final X25519 _algorithm;
  final AesGcm _cipher;

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

  /// Encrypts plaintext using AES-GCM 256-bit with the derived shared secret.
  Future<({String ciphertext, String nonce})> encryptPayload({
    required String plaintext,
    required List<int> sharedSecretBytes,
  }) async {
    final secretKey = SecretKey(sharedSecretBytes);
    final clearBytes = utf8.encode(plaintext);
    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: secretKey,
    );
    final combinedCiphertext = secretBox.cipherText + secretBox.mac.bytes;
    return (
      ciphertext: base64Encode(combinedCiphertext),
      nonce: base64Encode(secretBox.nonce),
    );
  }

  /// Decrypts AES-GCM ciphertext using the derived shared secret and nonce.
  Future<String> decryptPayload({
    required String ciphertextBase64,
    required String nonceBase64,
    required List<int> sharedSecretBytes,
  }) async {
    final secretKey = SecretKey(sharedSecretBytes);
    final combinedBytes = base64Decode(ciphertextBase64);
    final nonceBytes = base64Decode(nonceBase64);

    if (combinedBytes.length < 16) {
      throw ArgumentError('Ciphertext too short for MAC verification.');
    }
    final cipherText = combinedBytes.sublist(0, combinedBytes.length - 16);
    final macBytes = combinedBytes.sublist(combinedBytes.length - 16);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonceBytes,
      mac: Mac(macBytes),
    );

    final decryptedBytes = await _cipher.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(decryptedBytes);
  }

  /// Clears stored cryptographic keys on sign-out or account wipe.
  Future<void> clearKeys() async {
    await _storage.delete(key: _publicKeyKey);
    await _storage.delete(key: _privateKeyKey);
  }

  /// Returns whether a valid local private key is currently stored on this device.
  Future<bool> hasLocalPrivateKey() async {
    final priv = await _storage.read(key: _privateKeyKey);
    return priv != null && priv.trim().isNotEmpty;
  }

  /// Derives a 256-bit vault key tied to the user authenticated UID.
  Future<List<int>> _deriveVaultKey(String uid) async {
    final salt = utf8.encode('relay.keyvault.v1.salt:');
    final combined = [...salt, ...utf8.encode(uid)];
    final hash = await Sha256().hash(combined);
    return hash.bytes;
  }

  /// Exports the user private key as an AES-GCM encrypted vault bundle.
  Future<String> exportEncryptedKeyVault(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('UID cannot be empty for key vault export.');
    }
    var privBase64 = await _storage.read(key: _privateKeyKey);
    if (privBase64 == null || privBase64.isEmpty) {
      await getOrCreatePublicKey();
      privBase64 = await _storage.read(key: _privateKeyKey);
    }
    if (privBase64 == null || privBase64.isEmpty) {
      throw StateError('Cannot export vault: private key generation failed.');
    }

    final vaultKey = await _deriveVaultKey(uid);
    final encrypted = await encryptPayload(
      plaintext: privBase64,
      sharedSecretBytes: vaultKey,
    );

    return jsonEncode({
      'ciphertext': encrypted.ciphertext,
      'nonce': encrypted.nonce,
      'v': 1,
    });
  }

  /// Imports an AES-GCM encrypted vault bundle, restores the private key,
  /// reconstructs the public key, and persists them into secure storage.
  Future<String> importEncryptedKeyVault({
    required String encryptedVault,
    required String uid,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('UID cannot be empty for key vault import.');
    }
    if (encryptedVault.trim().isEmpty) {
      throw ArgumentError('Encrypted vault cannot be empty.');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(encryptedVault) as Map<String, dynamic>;
    } catch (_) {
      throw ArgumentError('Malformed key vault JSON format.');
    }

    final ciphertext = decoded['ciphertext'] as String?;
    final nonce = decoded['nonce'] as String?;
    if (ciphertext == null || nonce == null) {
      throw ArgumentError('Key vault payload missing ciphertext or nonce.');
    }

    final vaultKey = await _deriveVaultKey(uid);
    final privBase64 = await decryptPayload(
      ciphertextBase64: ciphertext,
      nonceBase64: nonce,
      sharedSecretBytes: vaultKey,
    );

    final privBytes = base64Decode(privBase64);
    if (privBytes.length != 32) {
      throw StateError('Decrypted private key has invalid length.');
    }

    final keyPair = await _algorithm.newKeyPairFromSeed(privBytes);
    final pubKey = await keyPair.extractPublicKey();
    final pubBase64 = base64Encode(pubKey.bytes);

    await _storage.write(key: _publicKeyKey, value: pubBase64);
    await _storage.write(key: _privateKeyKey, value: privBase64);

    return pubBase64;
  }
}

