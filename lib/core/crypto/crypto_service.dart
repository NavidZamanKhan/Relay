import 'dart:convert';
import 'dart:math' as math;
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

  String? _cachedPublicKey;
  String? _cachedPrivateKey;
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
      _cachedPublicKey = existingPub;
      _cachedPrivateKey = existingPriv;
      return existingPub;
    }

    final keyPair = await _algorithm.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    final pubBase64 = base64Encode(publicKey.bytes);
    final privBase64 = base64Encode(privateBytes);

    _cachedPublicKey = pubBase64;
    _cachedPrivateKey = privBase64;

    await _storage.write(key: _publicKeyKey, value: pubBase64);
    await _storage.write(key: _privateKeyKey, value: privBase64);

    return pubBase64;
  }

  /// Returns the existing public key if already generated, otherwise null.
  Future<String?> getPublicKey() async {
    if (_cachedPublicKey != null && _cachedPublicKey!.isNotEmpty) {
      return _cachedPublicKey;
    }
    final pub = await _storage.read(key: _publicKeyKey);
    if (pub != null && pub.isNotEmpty) {
      _cachedPublicKey = pub;
    }
    return pub;
  }

  /// Derives an X25519 shared secret bytes with a remote peer's public key.
  ///
  /// The returned shared secret can be used with AES-GCM or Argon2/HKDF for message encryption.
  Future<List<int>> deriveSharedSecret({
    required String peerPublicKeyBase64,
  }) async {
    var privBase64 =
        _cachedPrivateKey ?? await _storage.read(key: _privateKeyKey);
    if (privBase64 == null || privBase64.trim().isEmpty) {
      await getOrCreatePublicKey();
      privBase64 =
          _cachedPrivateKey ?? await _storage.read(key: _privateKeyKey);
    }
    if (privBase64 == null || privBase64.trim().isEmpty) {
      throw StateError(
          'Cannot derive shared secret: local private key missing.');
    }
    _cachedPrivateKey = privBase64;

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

  /// Encrypts raw binary bytes (audio/image) using AES-GCM 256-bit with the derived shared secret.
  Future<({List<int> ciphertext, String nonce})> encryptRawBytes({
    required List<int> rawBytes,
    required List<int> sharedSecretBytes,
  }) async {
    final secretKey = SecretKey(sharedSecretBytes);
    final secretBox = await _cipher.encrypt(
      rawBytes,
      secretKey: secretKey,
    );
    final combinedCiphertext = secretBox.cipherText + secretBox.mac.bytes;
    return (
      ciphertext: combinedCiphertext,
      nonce: base64Encode(secretBox.nonce),
    );
  }

  /// Decrypts AES-GCM ciphertext bytes using the derived shared secret and nonce.
  Future<List<int>> decryptRawBytes({
    required List<int> combinedBytes,
    required String nonceBase64,
    required List<int> sharedSecretBytes,
  }) async {
    final secretKey = SecretKey(sharedSecretBytes);
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

    return await _cipher.decrypt(
      secretBox,
      secretKey: secretKey,
    );
  }

  /// Clears stored cryptographic keys on sign-out or account wipe.
  Future<void> clearKeys() async {
    _cachedPublicKey = null;
    _cachedPrivateKey = null;
    await _storage.delete(key: _publicKeyKey);
    await _storage.delete(key: _privateKeyKey);
  }

  /// Returns whether a valid local private key is currently stored on this device.
  Future<bool> hasLocalPrivateKey() async {
    if (_cachedPrivateKey != null && _cachedPrivateKey!.trim().isNotEmpty) {
      return true;
    }
    final priv = await _storage.read(key: _privateKeyKey);
    if (priv != null && priv.trim().isNotEmpty) {
      _cachedPrivateKey = priv;
      return true;
    }
    return false;
  }

  /// Computes a deterministic 30-digit safety number (in 6 blocks of 5 digits)
  /// between two public keys for out-of-band cryptographic verification.
  static Future<String> computeSafetyNumber(String keyA, String keyB) async {
    final cleanedA = keyA.trim();
    final cleanedB = keyB.trim();
    if (cleanedA.isEmpty || cleanedB.isEmpty) {
      return '00000 00000 00000 00000 00000 00000';
    }
    final sorted = [cleanedA, cleanedB]..sort();
    final seed = utf8.encode('relay.safety_number.v1:${sorted[0]}:${sorted[1]}');
    final digest = await Sha256().hash(seed);
    final bytes = digest.bytes;
    final buffer = StringBuffer();
    for (var i = 0; i < 6; i++) {
      final val = (bytes[i * 4] << 24) |
          (bytes[i * 4 + 1] << 16) |
          (bytes[i * 4 + 2] << 8) |
          bytes[i * 4 + 3];
      final numStr = (val.abs() % 100000).toString().padLeft(5, '0');
      if (i > 0) buffer.write(' ');
      buffer.write(numStr);
    }
    return buffer.toString();
  }

  /// Formats a base64 public key into a 16-character grouped hex fingerprint.
  static String formatKeyFingerprint(String publicKeyBase64) {
    if (publicKeyBase64.trim().isEmpty) return 'None';
    try {
      final bytes = base64Decode(publicKeyBase64.trim());
      final hex = bytes
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join('')
          .toUpperCase();
      return '${hex.substring(0, 4)} ${hex.substring(4, 8)} ${hex.substring(8, 12)} ${hex.substring(12, 16)}';
    } catch (_) {
      return publicKeyBase64.substring(0, math.min(12, publicKeyBase64.length));
    }
  }

  /// Regenerates a fresh X25519 keypair, overwriting secure storage.
  Future<String> regenerateKeypair() async {
    final keyPair = await _algorithm.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    final pubBase64 = base64Encode(publicKey.bytes);
    final privBase64 = base64Encode(privateBytes);

    _cachedPublicKey = pubBase64;
    _cachedPrivateKey = privBase64;

    await _storage.write(key: _publicKeyKey, value: pubBase64);
    await _storage.write(key: _privateKeyKey, value: privBase64);

    return pubBase64;
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

    _cachedPublicKey = pubBase64;
    _cachedPrivateKey = privBase64;

    await _storage.write(key: _publicKeyKey, value: pubBase64);
    await _storage.write(key: _privateKeyKey, value: privBase64);

    return pubBase64;
  }
}

