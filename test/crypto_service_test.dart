import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/crypto/crypto_service.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  group('CryptoService Security & Verification Tests', () {
    late FakeSecureStorage storage;
    late CryptoService cryptoService;

    setUp(() {
      storage = FakeSecureStorage();
      cryptoService = CryptoService(storage: storage);
    });

    test('generates valid 32-byte X25519 public key in Base64', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();
      final decodedBytes = base64Decode(pubKey);

      expect(decodedBytes.length, 32);
      expect(await storage.read(key: 'relay_x25519_public_key'), pubKey);
      expect(await storage.read(key: 'relay_x25519_private_key'), isNotNull);
    });

    test('reuses existing keypair without generating duplicates', () async {
      final firstKey = await cryptoService.getOrCreatePublicKey();
      final secondKey = await cryptoService.getOrCreatePublicKey();

      expect(firstKey, equals(secondKey));
    });

    test('regenerates keypair if private key was missing (corrupted state)', () async {
      final firstPub = await cryptoService.getOrCreatePublicKey();
      // Simulate partial write or corrupted state where private key is wiped
      await storage.delete(key: 'relay_x25519_private_key');

      final secondPub = await cryptoService.getOrCreatePublicKey();
      expect(secondPub, isNot(equals(firstPub)));
      expect(await storage.read(key: 'relay_x25519_private_key'), isNotNull);
    });

    test('derives identical shared secrets on both peer sides via Diffie-Hellman', () async {
      final storageAlice = FakeSecureStorage();
      final cryptoAlice = CryptoService(storage: storageAlice);
      final alicePub = await cryptoAlice.getOrCreatePublicKey();

      final storageBob = FakeSecureStorage();
      final cryptoBob = CryptoService(storage: storageBob);
      final bobPub = await cryptoBob.getOrCreatePublicKey();

      final secretAlice = await cryptoAlice.deriveSharedSecret(
        peerPublicKeyBase64: bobPub,
      );
      final secretBob = await cryptoBob.deriveSharedSecret(
        peerPublicKeyBase64: alicePub,
      );

      expect(secretAlice.length, 32);
      expect(secretBob.length, 32);
      expect(base64Encode(secretAlice), equals(base64Encode(secretBob)));
    });

    test('rejects malformed or invalid-length peer public keys', () async {
      await cryptoService.getOrCreatePublicKey();
      final malformedKey = base64Encode([1, 2, 3]); // Only 3 bytes instead of 32

      expect(
        () => cryptoService.deriveSharedSecret(peerPublicKeyBase64: malformedKey),
        throwsArgumentError,
      );
    });

    test('clearKeys removes both public and private keys from secure storage', () async {
      await cryptoService.getOrCreatePublicKey();
      await cryptoService.clearKeys();

      expect(await storage.read(key: 'relay_x25519_public_key'), isNull);
      expect(await storage.read(key: 'relay_x25519_private_key'), isNull);
    });
  });
}
