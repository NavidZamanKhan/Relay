import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_models.dart';

void main() {
  group('DeliveryStage Enum', () {
    test('serializes and parses correctly', () {
      expect(DeliveryStage.fromString('sending'), DeliveryStage.sending);
      expect(DeliveryStage.fromString('sent'), DeliveryStage.sent);
      expect(DeliveryStage.fromString('delivered'), DeliveryStage.delivered);
      expect(DeliveryStage.fromString('read'), DeliveryStage.read);
      expect(DeliveryStage.fromString('unknown_value'), DeliveryStage.sent);
      expect(DeliveryStage.fromString(null), DeliveryStage.sent);

      expect(DeliveryStage.sending.toDbString(), 'sending');
      expect(DeliveryStage.sent.toDbString(), 'sent');
      expect(DeliveryStage.delivered.toDbString(), 'delivered');
      expect(DeliveryStage.read.toDbString(), 'read');
    });
  });

  group('MessageKind Enum', () {
    test('serializes and parses correctly', () {
      expect(MessageKind.fromString('text'), MessageKind.text);
      expect(MessageKind.fromString('image'), MessageKind.image);
      expect(MessageKind.fromString('voice'), MessageKind.voice);
      expect(MessageKind.fromString('document'), MessageKind.document);
      expect(MessageKind.fromString(null), MessageKind.text);

      expect(MessageKind.text.toDbString(), 'text');
      expect(MessageKind.image.toDbString(), 'image');
      expect(MessageKind.voice.toDbString(), 'voice');
      expect(MessageKind.document.toDbString(), 'document');
    });
  });

  group('RelayMessage Serialization & Deserialization', () {
    final testDate = DateTime.utc(2026, 9, 8, 2, 30);

    test('serializes cleanly to Firestore document map', () {
      final message = RelayMessage(
        id: 'msg_001',
        senderId: 'alice_uid',
        recipientId: 'bob_uid',
        sentAt: testDate,
        kind: MessageKind.text,
        text: 'Hello Bob',
        encryptedPayload: 'ENCRYPTED_BASE64_DATA',
        nonce: 'NONCE_12_BYTES',
        ephemeralPublicKey: 'EPHEMERAL_KEY_BASE64',
        delivery: DeliveryStage.sent,
        replyTo: 'msg_000',
      );

      final map = message.toMap();
      expect(map['senderId'], 'alice_uid');
      expect(map['recipientId'], 'bob_uid');
      expect(map['kind'], 'text');
      expect(map['delivery'], 'sent');
      expect(map['encryptedPayload'], 'ENCRYPTED_BASE64_DATA');
      expect(map['nonce'], 'NONCE_12_BYTES');
      expect(map['ephemeralPublicKey'], 'EPHEMERAL_KEY_BASE64');
      expect(map['replyTo'], 'msg_000');
      expect(map['sentAt'], isA<Timestamp>());
    });

    test('serializes with server timestamp flag', () {
      final message = RelayMessage(
        id: 'msg_002',
        senderId: 'alice_uid',
        sentAt: testDate,
        kind: MessageKind.text,
      );

      final map = message.toMap(useServerTimestamp: true);
      expect(map['sentAt'], isA<FieldValue>());
    });

    test('deserializes safely with complete fields and computes isMine', () {
      final docMap = {
        'senderId': 'alice_uid',
        'recipientId': 'bob_uid',
        'kind': 'voice',
        'sentAt': Timestamp.fromDate(testDate),
        'delivery': 'delivered',
        'encryptedPayload': 'CIPHERTEXT',
        'nonce': 'IV_BYTES',
        'durationMs': 3500,
        'replyTo': 'msg_prev',
      };

      final messageForAlice = RelayMessage.fromMap(
        docMap,
        'msg_100',
        currentUserId: 'alice_uid',
      );
      expect(messageForAlice.id, 'msg_100');
      expect(messageForAlice.senderId, 'alice_uid');
      expect(messageForAlice.recipientId, 'bob_uid');
      expect(messageForAlice.kind, MessageKind.voice);
      expect(messageForAlice.delivery, DeliveryStage.delivered);
      expect(messageForAlice.duration, const Duration(milliseconds: 3500));
      expect(messageForAlice.isMine, isTrue);

      final messageForBob = RelayMessage.fromMap(
        docMap,
        'msg_100',
        currentUserId: 'bob_uid',
      );
      expect(messageForBob.isMine, isFalse);
    });

    test('deserializes safely with missing or corrupted fields', () {
      final emptyMap = <String, dynamic>{};
      final message = RelayMessage.fromMap(emptyMap, 'corrupted_id');

      expect(message.id, 'corrupted_id');
      expect(message.senderId, isEmpty);
      expect(message.kind, MessageKind.text);
      expect(message.delivery, DeliveryStage.sent);
      expect(message.isMine, isFalse);
      expect(message.duration, Duration.zero);
      expect(message.sentAt, isA<DateTime>());
    });
  });

  group('Conversation Serialization & Deserialization', () {
    final testDate = DateTime.utc(2026, 9, 8, 2, 15);

    test('serializes conversation to Firestore map', () {
      final conv = Conversation(
        id: 'chat_alice_bob',
        name: 'Bob',
        avatarAsset: 'assets/avatars/bob.jpg',
        lastMessage: 'Sounds good',
        timeLabel: '02:15',
        lastMessageAt: testDate,
        participantIds: const ['alice_uid', 'bob_uid'],
        recipientId: 'bob_uid',
        delivery: DeliveryStage.read,
      );

      final map = conv.toMap();
      expect(map['participantIds'], ['alice_uid', 'bob_uid']);
      expect(map['recipientId'], 'bob_uid');
      expect(map['lastMessage'], 'Sounds good');
      expect(map['delivery'], 'read');
      expect(map['isGroup'], isFalse);
      expect(map['lastMessageAt'], isA<Timestamp>());
    });

    test('deserializes conversation and extracts peer recipient ID', () {
      final docMap = {
        'participantIds': ['alice_uid', 'bob_uid'],
        'lastMessage': 'Let us meet tomorrow',
        'lastMessageAt': Timestamp.fromDate(testDate),
        'previewKind': 'text',
        'delivery': 'sent',
        'unreadCount': {
          'alice_uid': 0,
          'bob_uid': 2,
        },
        'isGroup': false,
      };

      final convAlice = Conversation.fromMap(
        docMap,
        'chat_123',
        currentUserId: 'alice_uid',
        fallbackName: 'Bob Smith',
        fallbackAvatar: 'assets/avatars/bob.png',
        recipientPublicKey: 'BOB_PUBLIC_KEY',
      );

      expect(convAlice.id, 'chat_123');
      expect(convAlice.recipientId, 'bob_uid');
      expect(convAlice.name, 'Bob Smith');
      expect(convAlice.avatarAsset, 'assets/avatars/bob.png');
      expect(convAlice.recipientPublicKey, 'BOB_PUBLIC_KEY');
      expect(convAlice.unread, 0);
      expect(convAlice.delivery, DeliveryStage.sent);

      final convBob = Conversation.fromMap(
        docMap,
        'chat_123',
        currentUserId: 'bob_uid',
        fallbackName: 'Alice Johnson',
      );

      expect(convBob.recipientId, 'alice_uid');
      expect(convBob.unread, 2);
    });

    test('directChatId returns deterministic sorted composite ID', () {
      final id1 = Conversation.directChatId('uid_alice', 'uid_bob');
      final id2 = Conversation.directChatId('uid_bob', 'uid_alice');
      expect(id1, equals('chat_uid_alice_uid_bob'));
      expect(id2, equals('chat_uid_alice_uid_bob'));
      expect(id1, equals(id2));
    });

    test('Conversation.fromMap extracts recipientPublicKey from participantPublicKeys map', () {
      final docMap = {
        'participantIds': ['uid_alice', 'uid_bob'],
        'lastMessage': 'Testing public key extraction',
        'participantPublicKeys': {
          'uid_alice': 'ALICE_PUBLIC_KEY',
          'uid_bob': 'BOB_PUBLIC_KEY',
        },
      };

      final convForAlice = Conversation.fromMap(
        docMap,
        'chat_uid_alice_uid_bob',
        currentUserId: 'uid_alice',
      );
      expect(convForAlice.recipientPublicKey, equals('BOB_PUBLIC_KEY'));

      final convForBob = Conversation.fromMap(
        docMap,
        'chat_uid_alice_uid_bob',
        currentUserId: 'uid_bob',
      );
      expect(convForBob.recipientPublicKey, equals('ALICE_PUBLIC_KEY'));
    });
  });

  group('RelayContact Model', () {
    test('supports equality and copyWith', () {
      const contact = RelayContact(
        id: 'contact_01',
        displayName: 'Sami Ahmed',
        phoneNumber: '+16505550199',
        isRegistered: false,
      );

      final registeredContact = contact.copyWith(
        publicKey: 'SAMI_KEY',
        isRegistered: true,
      );

      expect(registeredContact.isRegistered, isTrue);
      expect(registeredContact.publicKey, 'SAMI_KEY');
      expect(registeredContact.displayName, 'Sami Ahmed');
      expect(registeredContact.phoneNumber, '+16505550199');
    });
  });
}
