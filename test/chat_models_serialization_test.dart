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

    test('Conversation.fromMap parses schema fallback keys correctly', () {
      final fallbackDocMap = {
        'participants': ['user_navid', 'user_sadman'],
        'lastMessage': 'Photo',
        'previewKind': 'image',
        'lastMessageTime': Timestamp.fromDate(testDate),
        'lastMessageDelivery': 'sent',
        'unreadCounts': {
          'user_navid': 0,
          'user_sadman': 1,
        },
        'isGroup': false,
      };

      final convSadman = Conversation.fromMap(
        fallbackDocMap,
        'chat_navid_sadman',
        currentUserId: 'user_sadman',
        fallbackName: 'Navid',
      );

      expect(convSadman.recipientId, 'user_navid');
      expect(convSadman.unread, 1);
      expect(convSadman.delivery, DeliveryStage.sent);
      expect(convSadman.previewKind, MessageKind.image);
      expect(convSadman.lastMessage, 'Photo');
      expect(convSadman.lastMessageAt?.isAtSameMomentAs(testDate), isTrue);
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

    test('Conversation.fromMap resolves peer display name from participantNames based on current user', () {
      final docMap = {
        'participantIds': ['uid_sadman', 'uid_navid'],
        'lastMessage': 'Hello there',
        'name': 'Navid',
        'participantNames': {
          'uid_sadman': 'Sadman',
          'uid_navid': 'Navid',
        },
      };

      final convForSadman = Conversation.fromMap(
        docMap,
        'chat_uid_navid_uid_sadman',
        currentUserId: 'uid_sadman',
      );
      expect(convForSadman.name, equals('Navid'));

      final convForNavid = Conversation.fromMap(
        docMap,
        'chat_uid_navid_uid_sadman',
        currentUserId: 'uid_navid',
      );
      expect(convForNavid.name, equals('Sadman'));
    });

    test('serializes and deserializes participantNames in Conversation', () {
      const conv = Conversation(
        id: 'chat_a_b',
        name: 'Bob',
        avatarAsset: null,
        lastMessage: 'Hi',
        timeLabel: 'Now',
        participantIds: ['uid_a', 'uid_b'],
        participantNames: {'uid_a': 'Alice', 'uid_b': 'Bob'},
      );

      final map = conv.toMap();
      expect(map['participantNames'], equals({'uid_a': 'Alice', 'uid_b': 'Bob'}));

      final deserialized = Conversation.fromMap(map, 'chat_a_b', currentUserId: 'uid_a');
      expect(deserialized.name, equals('Bob'));
      expect(deserialized.participantNames, equals({'uid_a': 'Alice', 'uid_b': 'Bob'}));
    });

    test('Conversation.fromMap parses isPeerTyping from typing map for peer participant', () {
      final docMapWithTyping = {
        'participantIds': ['uid_a', 'uid_b'],
        'lastMessage': 'Typing test',
        'typing': {
          'uid_a': false,
          'uid_b': true,
        },
      };

      final convForA = Conversation.fromMap(
        docMapWithTyping,
        'chat_uid_a_uid_b',
        currentUserId: 'uid_a',
      );
      expect(convForA.isPeerTyping, isTrue);

      final convForB = Conversation.fromMap(
        docMapWithTyping,
        'chat_uid_a_uid_b',
        currentUserId: 'uid_b',
      );
      expect(convForB.isPeerTyping, isFalse);

      final docMapWithoutTyping = {
        'participantIds': ['uid_a', 'uid_b'],
        'lastMessage': 'No typing test',
        'typing': {
          'uid_b': false,
        },
      };

      final convNotTyping = Conversation.fromMap(
        docMapWithoutTyping,
        'chat_uid_a_uid_b',
        currentUserId: 'uid_a',
      );
      expect(convNotTyping.isPeerTyping, isFalse);
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

  group('RelayMessage Image Attachments Serialization', () {
    test('serializes and deserializes imageUrl and imageData cleanly', () {
      final imgMsg = RelayMessage(
        id: 'msg_img_001',
        senderId: 'user_1',
        recipientId: 'user_2',
        sentAt: DateTime.utc(2026, 9, 10, 12, 0),
        kind: MessageKind.image,
        text: 'Sunset view',
        imageUrl: 'https://firebasestorage.googleapis.com/test_image.jpg',
        imageData: 'BASE64_IMAGE_FALLBACK_DATA',
        delivery: DeliveryStage.delivered,
      );

      final map = imgMsg.toMap();
      expect(map['kind'], 'image');
      expect(map['imageUrl'], 'https://firebasestorage.googleapis.com/test_image.jpg');
      expect(map['imageData'], 'BASE64_IMAGE_FALLBACK_DATA');
      expect(map['text'], 'Sunset view');

      final restored = RelayMessage.fromMap(map, 'msg_img_001', currentUserId: 'user_1');
      expect(restored.kind, MessageKind.image);
      expect(restored.imageUrl, 'https://firebasestorage.googleapis.com/test_image.jpg');
      expect(restored.imageData, 'BASE64_IMAGE_FALLBACK_DATA');
      expect(restored.text, 'Sunset view');
      expect(restored.isMine, isTrue);
    });
  });
}
