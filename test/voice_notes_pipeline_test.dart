import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/core/services/audio_service.dart';
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
  }) async =>
      _data[key];

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

  group('Waveform Resampling & Normalization Algorithm', () {
    test('handles empty amplitude list by returning default 32 bars', () {
      final waveform = RelayAudioService.resampleWaveform([], 32);
      expect(waveform.length, equals(32));
      for (final bar in waveform) {
        expect(bar, equals(0.25));
      }
    });

    test('retains exact bar count and clamps values between 0.15 and 1.0', () {
      final input = List.generate(32, (i) => i % 2 == 0 ? 0.05 : 1.25);
      final waveform = RelayAudioService.resampleWaveform(input, 32);
      expect(waveform.length, equals(32));
      for (var i = 0; i < 32; i++) {
        if (i % 2 == 0) {
          expect(waveform[i], equals(0.15));
        } else {
          expect(waveform[i], equals(1.0));
        }
      }
    });

    test('upsamples short recordings via smooth interpolation', () {
      final input = [0.2, 0.8, 0.4];
      final waveform = RelayAudioService.resampleWaveform(input, 32);
      expect(waveform.length, equals(32));
      expect(waveform.first, closeTo(0.2, 0.01));
      expect(waveform.last, closeTo(0.4, 0.01));
      for (final bar in waveform) {
        expect(bar, greaterThanOrEqualTo(0.15));
        expect(bar, lessThanOrEqualTo(1.0));
      }
    });

    test('downsamples long recordings by capturing peak bucket amplitudes', () {
      final input = List.generate(320, (i) => (i % 10 == 0) ? 0.95 : 0.20);
      final waveform = RelayAudioService.resampleWaveform(input, 32);
      expect(waveform.length, equals(32));
      for (final bar in waveform) {
        expect(bar, equals(0.95));
      }
    });
  });

  group('RelayMessage Voice Metadata Serialization', () {
    test('serializes and deserializes waveform and audioUrl cleanly', () {
      final testWaveform = List.generate(32, (i) => (i / 32.0).clamp(0.15, 1.0));
      final message = RelayMessage(
        id: 'voice_msg_001',
        senderId: 'alice_uid',
        recipientId: 'bob_uid',
        sentAt: DateTime.utc(2026, 9, 10, 12, 0),
        kind: MessageKind.voice,
        audioUrl: 'https://firebasestorage.googleapis.com/v0/b/relay/voice_001.enc',
        waveform: testWaveform,
        duration: const Duration(seconds: 14),
        delivery: DeliveryStage.sent,
        nonce: 'NONCE_BASE_64',
      );

      final map = message.toMap();
      expect(map['kind'], equals('voice'));
      expect(map['audioUrl'], equals('https://firebasestorage.googleapis.com/v0/b/relay/voice_001.enc'));
      expect(map['durationMs'], equals(14000));
      expect(map['waveform'], equals(testWaveform));

      final deserialized = RelayMessage.fromMap(map, 'voice_msg_001', currentUserId: 'bob_uid');
      expect(deserialized.id, equals('voice_msg_001'));
      expect(deserialized.kind, equals(MessageKind.voice));
      expect(deserialized.audioUrl, equals('https://firebasestorage.googleapis.com/v0/b/relay/voice_001.enc'));
      expect(deserialized.duration, equals(const Duration(seconds: 14)));
      expect(deserialized.waveform, equals(testWaveform));
      expect(deserialized.isMine, isFalse);
    });
  });

  group('Binary Audio Payload E2EE Roundtrip', () {
    test('encrypts and decrypts raw binary audio bytes using AES-256-GCM', () async {
      final aliceCrypto = CryptoService(storage: FakeSecureStorage());
      final bobCrypto = CryptoService(storage: FakeSecureStorage());

      final alicePublicKey = await aliceCrypto.getOrCreatePublicKey();
      final bobPublicKey = await bobCrypto.getOrCreatePublicKey();

      final aliceSecretWithBob = await aliceCrypto.deriveSharedSecret(
        peerPublicKeyBase64: bobPublicKey,
      );
      final bobSecretWithAlice = await bobCrypto.deriveSharedSecret(
        peerPublicKeyBase64: alicePublicKey,
      );

      expect(aliceSecretWithBob, equals(bobSecretWithAlice));

      // Simulate simulated AAC audio bytes (e.g. 5 KB random payload)
      final rawAudio = Uint8List.fromList(List.generate(5000, (i) => (i * 17) % 256));

      // Alice encrypts audio bytes before upload
      final encrypted = await aliceCrypto.encryptRawBytes(
        rawBytes: rawAudio,
        sharedSecretBytes: aliceSecretWithBob,
      );

      expect(encrypted.ciphertext.isNotEmpty, isTrue);
      expect(encrypted.nonce.isNotEmpty, isTrue);
      expect(encrypted.ciphertext, isNot(equals(rawAudio)));

      // Bob receives ciphertext and decrypts with shared secret
      final decrypted = await bobCrypto.decryptRawBytes(
        combinedBytes: encrypted.ciphertext,
        nonceBase64: encrypted.nonce,
        sharedSecretBytes: bobSecretWithAlice,
      );

      expect(decrypted, equals(rawAudio));
    });
  });
}
