import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/features/chats/chat_models.dart';

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
  }) async => _data[key];

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Relay Real-Time E2EE Messaging Pipeline & 4-Stage Delivery Lifecycle', () {
    late CryptoService aliceCrypto;
    late CryptoService bobCrypto;
    late String alicePublicKey;
    late String bobPublicKey;

    setUp(() async {
      aliceCrypto = CryptoService(storage: FakeSecureStorage());
      bobCrypto = CryptoService(storage: FakeSecureStorage());

      alicePublicKey = await aliceCrypto.getOrCreatePublicKey();
      bobPublicKey = await bobCrypto.getOrCreatePublicKey();
    });

    test('verifies distinct X25519 public keys generated for both peers', () {
      expect(alicePublicKey, isNotEmpty);
      expect(bobPublicKey, isNotEmpty);
      expect(alicePublicKey, isNot(equals(bobPublicKey)));

      final aliceBytes = base64Decode(alicePublicKey);
      final bobBytes = base64Decode(bobPublicKey);
      expect(aliceBytes.length, 32);
      expect(bobBytes.length, 32);
    });

    test('Alice derives shared secret with Bob that matches Bob deriving with Alice', () async {
      final aliceSecret = await aliceCrypto.deriveSharedSecret(
        peerPublicKeyBase64: bobPublicKey,
      );
      final bobSecret = await bobCrypto.deriveSharedSecret(
        peerPublicKeyBase64: alicePublicKey,
      );

      expect(aliceSecret, equals(bobSecret));
      expect(aliceSecret.length, 32);
    });

    test('client-side AES-GCM 256-bit encryption produces ciphertext without plaintext leak', () async {
      final aliceSecret = await aliceCrypto.deriveSharedSecret(
        peerPublicKeyBase64: bobPublicKey,
      );

      const plaintext = 'Classified message for Bob: Relay v0.3 active.';
      final encrypted = await aliceCrypto.encryptPayload(
        plaintext: plaintext,
        sharedSecretBytes: aliceSecret,
      );

      expect(encrypted.ciphertext, isNotEmpty);
      expect(encrypted.nonce, isNotEmpty);
      expect(encrypted.ciphertext, isNot(contains('Classified')));
      expect(encrypted.ciphertext, isNot(contains('Bob')));

      final outgoingMessage = RelayMessage(
        id: 'msg_001',
        senderId: 'user_alice',
        recipientId: 'user_bob',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: plaintext,
        encryptedPayload: encrypted.ciphertext,
        nonce: encrypted.nonce,
        delivery: DeliveryStage.sent,
        isMine: true,
      );

      final map = outgoingMessage.toMap();
      expect(map['encryptedPayload'], equals(encrypted.ciphertext));
      expect(map['nonce'], equals(encrypted.nonce));
      expect(map['delivery'], equals('sent'));
    });

    test('Bob decrypts incoming message and verifies exact plaintext match', () async {
      final aliceSecret = await aliceCrypto.deriveSharedSecret(
        peerPublicKeyBase64: bobPublicKey,
      );
      final bobSecret = await bobCrypto.deriveSharedSecret(
        peerPublicKeyBase64: alicePublicKey,
      );

      const originalText = 'Zero dollar infrastructure with peer encryption.';
      final encrypted = await aliceCrypto.encryptPayload(
        plaintext: originalText,
        sharedSecretBytes: aliceSecret,
      );

      final decrypted = await bobCrypto.decryptPayload(
        ciphertextBase64: encrypted.ciphertext,
        nonceBase64: encrypted.nonce,
        sharedSecretBytes: bobSecret,
      );

      expect(decrypted, equals(originalText));
    });

    test('4-stage delivery lifecycle advances sequentially: sending -> sent -> delivered -> read', () {
      var msg = RelayMessage(
        id: 'msg_stage_test',
        senderId: 'user_alice',
        recipientId: 'user_bob',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Tracking receipts',
        delivery: DeliveryStage.sending,
        isMine: true,
      );
      expect(msg.delivery, DeliveryStage.sending);

      // 1. Server write confirmation
      msg = msg.copyWith(delivery: DeliveryStage.sent);
      expect(msg.delivery, DeliveryStage.sent);

      // 2. Peer client snapshot notification
      msg = msg.copyWith(delivery: DeliveryStage.delivered);
      expect(msg.delivery, DeliveryStage.delivered);

      // 3. Peer viewport opened
      msg = msg.copyWith(delivery: DeliveryStage.read);
      expect(msg.delivery, DeliveryStage.read);
    });

    test('bidirectional dialogue verifies symmetric round-trip encrypted exchange', () async {
      final aliceSecret = await aliceCrypto.deriveSharedSecret(
        peerPublicKeyBase64: bobPublicKey,
      );
      final bobSecret = await bobCrypto.deriveSharedSecret(
        peerPublicKeyBase64: alicePublicKey,
      );

      // 1. Alice -> Bob
      const aliceMsg = 'Hey Bob, does the new Relay pipeline work?';
      final encAlice = await aliceCrypto.encryptPayload(
        plaintext: aliceMsg,
        sharedSecretBytes: aliceSecret,
      );
      final bobReceived = await bobCrypto.decryptPayload(
        ciphertextBase64: encAlice.ciphertext,
        nonceBase64: encAlice.nonce,
        sharedSecretBytes: bobSecret,
      );
      expect(bobReceived, equals(aliceMsg));

      // 2. Bob -> Alice
      const bobMsg = 'Confirmed Alice, sub-second delivery and 256-bit AES-GCM verified.';
      final encBob = await bobCrypto.encryptPayload(
        plaintext: bobMsg,
        sharedSecretBytes: bobSecret,
      );
      final aliceReceived = await aliceCrypto.decryptPayload(
        ciphertextBase64: encBob.ciphertext,
        nonceBase64: encBob.nonce,
        sharedSecretBytes: aliceSecret,
      );
      expect(aliceReceived, equals(bobMsg));
    });

    test('corrupted or tampered ciphertext gracefully fails decryption without unhandled exception', () async {
      final bobSecret = await bobCrypto.deriveSharedSecret(
        peerPublicKeyBase64: alicePublicKey,
      );

      final invalidCiphertext = base64Encode(List<int>.filled(32, 0xFF));
      final invalidNonce = base64Encode(List<int>.filled(12, 0x01));

      expect(
        () => bobCrypto.decryptPayload(
          ciphertextBase64: invalidCiphertext,
          nonceBase64: invalidNonce,
          sharedSecretBytes: bobSecret,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('verifies 4-stage message delivery lifecycle semantics', () {
      expect(DeliveryStage.fromString('sending'), equals(DeliveryStage.sending));
      expect(DeliveryStage.fromString('sent'), equals(DeliveryStage.sent));
      expect(DeliveryStage.fromString('delivered'), equals(DeliveryStage.delivered));
      expect(DeliveryStage.fromString('read'), equals(DeliveryStage.read));

      expect(DeliveryStage.sending.toDbString(), equals('sending'));
      expect(DeliveryStage.sent.toDbString(), equals('sent'));
      expect(DeliveryStage.delivered.toDbString(), equals('delivered'));
      expect(DeliveryStage.read.toDbString(), equals('read'));
    });
  });
}
