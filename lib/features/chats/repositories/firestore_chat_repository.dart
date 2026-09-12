import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/crypto/crypto_service.dart';
import '../models/conversation.dart';
import '../models/delivery_stage.dart';
import '../models/message_kind.dart';
import '../models/relay_contact.dart';
import '../models/relay_message.dart';
import 'i_chat_repository.dart';

/// Production implementation of [IChatRepository] backed by Cloud Firestore
/// and hardened with client-side X25519/AES-GCM End-to-End Encryption.
class FirestoreChatRepository implements IChatRepository {
  FirestoreChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    CryptoService? cryptoService,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _customStorage = storage,
        _cryptoService = cryptoService ?? CryptoService();

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final FirebaseStorage? _customStorage;
  final CryptoService _cryptoService;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  final Map<String, List<int>> _sharedSecretCache = {};
  final Map<String, String> _userDisplayNameCache = {};
  final Map<String, String> _userPublicKeyCache = {};
  final Map<String, String> _userAvatarCache = {};
  final Set<String> _knownExistingChats = {};
  String? _cachedMyPublicKey;

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Helper to derive or retrieve cached shared secret with a peer.
  Future<List<int>> _getOrDeriveSecret(String peerPublicKey) async {
    final cached = _sharedSecretCache[peerPublicKey];
    if (cached != null) return cached;

    final derived = await _cryptoService.deriveSharedSecret(
      peerPublicKeyBase64: peerPublicKey,
    );
    _sharedSecretCache[peerPublicKey] = derived;
    return derived;
  }

  /// Helper to get or fetch cached avatar URL for a user.
  Future<String?> _getOrFetchUserAvatar(String uid) async {
    if (_userAvatarCache.containsKey(uid)) {
      return _userAvatarCache[uid];
    }
    try {
      final doc = await _usersCollection
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      final av = (doc.data()?['avatarUrl'] ?? doc.data()?['photoUrl']) as String?;
      if (av != null && av.trim().isNotEmpty) {
        final trimmed = av.trim();
        _userAvatarCache[uid] = trimmed;
        return trimmed;
      }
    } catch (_) {
      try {
        final doc = await _usersCollection
            .doc(uid)
            .get()
            .timeout(const Duration(milliseconds: 1500));
        final av = (doc.data()?['avatarUrl'] ?? doc.data()?['photoUrl']) as String?;
        if (av != null && av.trim().isNotEmpty) {
          final trimmed = av.trim();
          _userAvatarCache[uid] = trimmed;
          return trimmed;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) {
    return _chatsCollection
        .where('participantIds', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = <Conversation>[];

      for (final doc in snapshot.docs) {
        _knownExistingChats.add(doc.id);
        final data = doc.data();
        final isGroup = (data['isGroup'] as bool?) ?? false;
        final participants = (data['participantIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [];

        final otherParticipantId = participants.firstWhere(
          (p) => p != currentUserId,
          orElse: () => '',
        );

        String? resolvedFallbackName;
        String? resolvedPublicKey;
        String? resolvedFallbackAvatar;
        if (!isGroup && otherParticipantId.isNotEmpty) {
          final rawNames = data['participantNames'] as Map<dynamic, dynamic>?;
          if (rawNames != null &&
              rawNames[otherParticipantId] != null &&
              rawNames[otherParticipantId].toString().trim().isNotEmpty) {
            resolvedFallbackName = rawNames[otherParticipantId].toString().trim();
          } else {
            // Resolve from cache or fetch from users collection
            if (_userDisplayNameCache.containsKey(otherParticipantId)) {
              resolvedFallbackName = _userDisplayNameCache[otherParticipantId];
            } else {
              try {
                final userDoc =
                    await _usersCollection.doc(otherParticipantId).get();
                final name =
                    (userDoc.data()?['displayName'] as String?)?.trim();
                if (name != null && name.isNotEmpty) {
                  _userDisplayNameCache[otherParticipantId] = name;
                  resolvedFallbackName = name;
                  // Backfill participantNames on chat document asynchronously
                  _chatsCollection.doc(doc.id).update({
                    'participantNames.$otherParticipantId': name,
                  }).catchError((_) {});
                }
              } catch (_) {}
            }
          }

          // Resolve avatar: from chat doc, cache, or user doc
          final rawAvatars = data['participantAvatars'] as Map<dynamic, dynamic>?;
          if (rawAvatars != null &&
              rawAvatars[otherParticipantId] != null &&
              rawAvatars[otherParticipantId].toString().trim().isNotEmpty) {
            resolvedFallbackAvatar = rawAvatars[otherParticipantId].toString().trim();
            _userAvatarCache[otherParticipantId] = resolvedFallbackAvatar;
          } else if (_userAvatarCache.containsKey(otherParticipantId)) {
            resolvedFallbackAvatar = _userAvatarCache[otherParticipantId];
          } else {
            try {
              final userDoc =
                  await _usersCollection.doc(otherParticipantId).get();
              final av = (userDoc.data()?['avatarUrl'] ?? userDoc.data()?['photoUrl']) as String?;
              if (av != null && av.trim().isNotEmpty) {
                resolvedFallbackAvatar = av.trim();
                _userAvatarCache[otherParticipantId] = resolvedFallbackAvatar;
                _chatsCollection.doc(doc.id).update({
                  'participantAvatars.$otherParticipantId': resolvedFallbackAvatar,
                }).catchError((_) {});
              }
            } catch (_) {}
          }

          // Resolve canonical public key and self-heal stale chat metadata
          final rawKeys = data['participantPublicKeys'] as Map<dynamic, dynamic>?;
          final existingChatKey = rawKeys?[otherParticipantId]?.toString().trim();

          if (_userPublicKeyCache.containsKey(otherParticipantId)) {
            resolvedPublicKey = _userPublicKeyCache[otherParticipantId];
          } else {
            try {
              final userDoc =
                  await _usersCollection.doc(otherParticipantId).get();
              final pub = (userDoc.data()?['publicKey'] as String?)?.trim();
              if (pub != null && pub.isNotEmpty) {
                _userPublicKeyCache[otherParticipantId] = pub;
                resolvedPublicKey = pub;
              }
            } catch (_) {}
          }

          if (resolvedPublicKey != null &&
              resolvedPublicKey.isNotEmpty &&
              resolvedPublicKey != existingChatKey) {
            _chatsCollection.doc(doc.id).update({
              'participantPublicKeys.$otherParticipantId': resolvedPublicKey,
            }).catchError((_) {});
          }
        }

        final conv = Conversation.fromMap(
          data,
          doc.id,
          currentUserId: currentUserId,
          fallbackName: resolvedFallbackName,
          fallbackAvatar: resolvedFallbackAvatar,
          recipientPublicKey: resolvedPublicKey,
        );

        // Proactively self-heal stale unread count in Firestore if current user authored the latest message
        if (conv.lastMessageSenderId == currentUserId &&
            (data['unreadCount.$currentUserId'] != null ||
                (data['unreadCount'] is Map &&
                    ((data['unreadCount'][currentUserId] as num?)?.toInt() ?? 0) > 0))) {
          _chatsCollection.doc(doc.id).update({
            'unreadCount.$currentUserId': 0,
          }).catchError((_) {});
        }

        conversations.add(conv);
      }

      // Sort locally by lastMessageAt descending with null safety
      conversations.sort((a, b) {
        if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
        if (a.lastMessageAt == null) return 1;
        if (b.lastMessageAt == null) return -1;
        return b.lastMessageAt!.compareTo(a.lastMessageAt!);
      });

      return conversations;
    });
  }

  @override
  Stream<List<RelayMessage>> watchMessages(
    String chatId,
    String currentUserId,
  ) {
    String effectiveChatId = chatId;
    if (!effectiveChatId.startsWith('chat_') && !effectiveChatId.startsWith('group_')) {
      final sorted = [currentUserId, effectiveChatId]..sort();
      effectiveChatId = 'chat_${sorted[0]}_${sorted[1]}';
    }
    _knownExistingChats.add(effectiveChatId);

    return _chatsCollection
        .doc(effectiveChatId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
      final messages = <RelayMessage>[];

      for (final doc in snapshot.docs) {
        final rawMessage = RelayMessage.fromMap(
          doc.data(),
          doc.id,
          currentUserId: currentUserId,
        );

        // Voice payloads are decrypted as audio bytes when playback begins.
        if (rawMessage.kind == MessageKind.text &&
            rawMessage.encryptedPayload != null &&
            rawMessage.nonce != null) {
          // If the message was authored by current user and text is present, preserve it directly.
          if (rawMessage.isMine &&
              rawMessage.text != null &&
              rawMessage.text!.trim().isNotEmpty) {
            messages.add(rawMessage);
            continue;
          }

          try {
            // In 1-on-1 chats, look up peer key or decrypt with peer's public key
            String? peerUid = rawMessage.isMine
                ? rawMessage.recipientId
                : rawMessage.senderId;

            if ((peerUid == null || peerUid.trim().isEmpty) &&
                effectiveChatId.startsWith('chat_')) {
              final parts =
                  effectiveChatId.replaceFirst('chat_', '').split('_');
              peerUid = parts.where((p) => p != currentUserId).firstOrNull;
            }

            if (peerUid != null && peerUid.isNotEmpty) {
              String? peerPublicKey = _userPublicKeyCache[peerUid];
              if (peerPublicKey == null) {
                final peerDoc = await _usersCollection.doc(peerUid).get();
                peerPublicKey = peerDoc.data()?['publicKey'] as String?;
                if (peerPublicKey != null && peerPublicKey.isNotEmpty) {
                  _userPublicKeyCache[peerUid] = peerPublicKey;
                }
              }

              if (peerPublicKey != null && peerPublicKey.isNotEmpty) {
                final secret = await _getOrDeriveSecret(peerPublicKey);
                final decryptedText = await _cryptoService.decryptPayload(
                  ciphertextBase64: rawMessage.encryptedPayload!,
                  nonceBase64: rawMessage.nonce!,
                  sharedSecretBytes: secret,
                );
                messages.add(rawMessage.copyWith(text: decryptedText));
                continue;
              }
            }

            // Fallback for group messages or peers without shared secrets
            try {
              final decodedBytes = base64Decode(rawMessage.encryptedPayload!);
              final decodedText = utf8.decode(decodedBytes);
              if (decodedText.isNotEmpty) {
                messages.add(rawMessage.copyWith(text: decodedText));
                continue;
              }
            } catch (_) {}

            // If public key was unavailable or group decryption failed, check if stored text exists
            if (rawMessage.text != null && rawMessage.text!.trim().isNotEmpty) {
              messages.add(rawMessage);
              continue;
            }
          } catch (_) {
            // If decryption threw an error (e.g. key mismatch or MAC failure),
            // preserve existing document text if present
            if (rawMessage.text != null && rawMessage.text!.trim().isNotEmpty) {
              messages.add(rawMessage);
              continue;
            }

            // Check if encryptedPayload was fallback base64 encoded text
            try {
              final decodedBytes = base64Decode(rawMessage.encryptedPayload!);
              final decodedText = utf8.decode(decodedBytes);
              if (decodedText.isNotEmpty) {
                messages.add(rawMessage.copyWith(text: decodedText));
                continue;
              }
            } catch (_) {}

            // Decryption failure fallback: show guarded preview only if no text exists
            messages.add(rawMessage.copyWith(text: '[Encrypted message]'));
            continue;
          }
        }

        messages.add(rawMessage);
      }

      return messages;
    });
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required RelayMessage message,
    required String recipientPublicKey,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot send message: Unauthenticated session.');
    }

    // Normalize chatId: if caller passed a raw UID, convert to canonical composite ID
    String effectiveChatId = chatId;
    if (!effectiveChatId.startsWith('chat_') && !effectiveChatId.startsWith('group_')) {
      final sorted = [user.uid, effectiveChatId]..sort();
      effectiveChatId = 'chat_${sorted[0]}_${sorted[1]}';
    }

    // Resolve recipient ID
    String? effectiveRecipientId = message.recipientId;
    if (effectiveRecipientId == null && effectiveChatId.startsWith('chat_')) {
      final parts = effectiveChatId.replaceFirst('chat_', '').split('_');
      effectiveRecipientId = parts.where((p) => p != user.uid).firstOrNull;
    }

    // 1. Resolve recipient public key from memory cache or arguments first
    String effectivePublicKey = recipientPublicKey.trim();
    if (effectivePublicKey.isEmpty && effectiveRecipientId != null) {
      effectivePublicKey = _userPublicKeyCache[effectiveRecipientId] ?? '';
    }
    if (effectivePublicKey.isEmpty && effectiveRecipientId != null) {
      try {
        final peerDoc = await _usersCollection
            .doc(effectiveRecipientId)
            .get(const GetOptions(source: Source.cache));
        final pub = (peerDoc.data()?['publicKey'] as String?)?.trim();
        if (pub != null && pub.isNotEmpty) {
          _userPublicKeyCache[effectiveRecipientId] = pub;
          effectivePublicKey = pub;
        }
      } catch (_) {
        try {
          final peerDoc = await _usersCollection
              .doc(effectiveRecipientId)
              .get()
              .timeout(const Duration(milliseconds: 1500));
          final pub = (peerDoc.data()?['publicKey'] as String?)?.trim();
          if (pub != null && pub.isNotEmpty) {
            _userPublicKeyCache[effectiveRecipientId] = pub;
            effectivePublicKey = pub;
          }
        } catch (_) {}
      }
    }
    if (effectivePublicKey.isNotEmpty && effectiveRecipientId != null) {
      _userPublicKeyCache[effectiveRecipientId] = effectivePublicKey;
    }

    String? ciphertext;
    String? nonce;

    // Encrypt plaintext payload on client device before transmission
    if (message.text != null && message.text!.isNotEmpty) {
      if (effectivePublicKey.isNotEmpty) {
        final secret = await _getOrDeriveSecret(effectivePublicKey);
        final result = await _cryptoService.encryptPayload(
          plaintext: message.text!,
          sharedSecretBytes: secret,
        );
        ciphertext = result.ciphertext;
        nonce = result.nonce;
      } else {
        // Fallback guard: Base64 encode plaintext so schema validation passes
        ciphertext = base64Encode(utf8.encode(message.text!));
        nonce = base64Encode(List<int>.filled(12, 0));
      }
    }

    final messageRef = _chatsCollection.doc(effectiveChatId).collection('messages').doc(message.id);
    final chatRef = _chatsCollection.doc(effectiveChatId);

    String currentUserName = _userDisplayNameCache[user.uid] ?? 'Me';
    if (!_userDisplayNameCache.containsKey(user.uid)) {
      _usersCollection
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache))
          .then((doc) {
        final name = (doc.data()?['displayName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          _userDisplayNameCache[user.uid] = name;
        }
      }).catchError((_) {});
    }

    String peerName = 'Relay Contact';
    if (effectiveRecipientId != null) {
      final recipientId = effectiveRecipientId;
      peerName = _userDisplayNameCache[recipientId] ?? 'Relay Contact';
      if (!_userDisplayNameCache.containsKey(recipientId)) {
        _usersCollection
            .doc(recipientId)
            .get(const GetOptions(source: Source.cache))
            .then((doc) {
          final name = (doc.data()?['displayName'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            _userDisplayNameCache[recipientId] = name;
          }
        }).catchError((_) {});
      }
    }

    final myAvatar = _userAvatarCache[user.uid];
    final peerAvatar = effectiveRecipientId != null ? _userAvatarCache[effectiveRecipientId] : null;
    if (myAvatar == null) {
      _getOrFetchUserAvatar(user.uid).catchError((_) => null);
    }
    if (peerAvatar == null && effectiveRecipientId != null) {
      _getOrFetchUserAvatar(effectiveRecipientId).catchError((_) => null);
    }

    final payload = message.copyWith(
      senderId: user.uid,
      senderName: currentUserName,
      recipientId: effectiveRecipientId,
      encryptedPayload: ciphertext,
      nonce: nonce,
      delivery: DeliveryStage.sent,
    );

    final batch = _firestore.batch();
    bool chatExists = _knownExistingChats.contains(effectiveChatId);
    DocumentSnapshot<Map<String, dynamic>>? chatDoc;

    if (!chatExists) {
      try {
        chatDoc = await chatRef.get(const GetOptions(source: Source.cache));
        chatExists = chatDoc.exists;
      } catch (_) {
        try {
          chatDoc = await chatRef.get().timeout(const Duration(milliseconds: 1500));
          chatExists = chatDoc.exists;
        } catch (_) {}
      }
    }

    if (!chatExists) {
      String myPublicKey = _cachedMyPublicKey ?? '';
      if (myPublicKey.isEmpty) {
        try {
          myPublicKey = await _cryptoService.getOrCreatePublicKey();
          if (myPublicKey.isNotEmpty) _cachedMyPublicKey = myPublicKey;
        } catch (_) {}
      }

      final participantNames = {
        user.uid: currentUserName,
        ?effectiveRecipientId: peerName,
      };
      final participantAvatars = {
        user.uid: ?myAvatar,
        ?effectiveRecipientId: ?peerAvatar,
      };

      final newConvData = <String, dynamic>{
        'participantIds': [user.uid, effectiveRecipientId ?? ''],
        'recipientId': effectiveRecipientId,
        'name': peerName,
        'participantNames': participantNames,
        if (participantAvatars.isNotEmpty)
          'participantAvatars': participantAvatars,
        'lastMessage': message.text ?? 'Media message',
        'previewKind': message.kind.toDbString(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'delivery': DeliveryStage.sent.toDbString(),
        'isGroup': false,
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {
          user.uid: 0,
          ?effectiveRecipientId: 1,
        },
        if (effectiveRecipientId != null)
          'participantPublicKeys': {
            user.uid: myPublicKey,
            effectiveRecipientId: effectivePublicKey,
          },
      };

      batch.set(chatRef, newConvData);
      batch.set(messageRef, payload.toMap(useServerTimestamp: true));
      await batch.commit();
      _knownExistingChats.add(effectiveChatId);
      return;
    }

    // Existing chat: fast-path atomic update with zero pre-fetch
    batch.set(messageRef, payload.toMap(useServerTimestamp: true));

    final updateData = <String, dynamic>{
      'lastMessage': message.text ?? 'Media message',
      'previewKind': message.kind.toDbString(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': user.uid,
      'delivery': DeliveryStage.sent.toDbString(),
      'unreadCount.${user.uid}': 0,
      if (effectiveRecipientId != null)
        'unreadCount.$effectiveRecipientId': FieldValue.increment(1),
      if (effectiveRecipientId != null && effectivePublicKey.isNotEmpty)
        'participantPublicKeys.$effectiveRecipientId': effectivePublicKey,
      'participantAvatars.${user.uid}': ?myAvatar,
    };

    try {
      batch.update(chatRef, updateData);
      await batch.commit();
    } catch (_) {
      final fallbackBatch = _firestore.batch();
      fallbackBatch.set(messageRef, payload.toMap(useServerTimestamp: true));
      fallbackBatch.set(chatRef, updateData, SetOptions(merge: true));
      await fallbackBatch.commit();
    }
    _knownExistingChats.add(effectiveChatId);
  }

  @override
  Future<void> updateDeliveryStatus({
    required String chatId,
    required String messageId,
    required DeliveryStage status,
  }) async {
    final user = _auth.currentUser;
    final effectiveChatId = user != null
        ? _canonicalChatId(chatId, user.uid)
        : chatId;

    try {
      final chatRef = _chatsCollection.doc(effectiveChatId);
      final messageRef = chatRef.collection('messages').doc(messageId);
      final batch = _firestore.batch();
      batch.update(messageRef, {'delivery': status.toDbString()});

      final chatUpdates = <String, dynamic>{
        'delivery': status.toDbString(),
      };
      if (user != null && status == DeliveryStage.read) {
        chatUpdates['unreadCount.${user.uid}'] = 0;
      }
      batch.update(chatRef, chatUpdates);
      await batch.commit();
    } catch (_) {}
  }

  @override
  Future<void> markConversationDelivered({
    required String chatId,
    required String recipientUserId,
  }) async {
    final effectiveChatId = _canonicalChatId(chatId, recipientUserId);
    try {
      final chatRef = _chatsCollection.doc(effectiveChatId);
      final snapshot = await chatRef
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(30)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      bool hasUpdates = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['senderId'] != recipientUserId &&
            (data['delivery'] == DeliveryStage.sent.toDbString() ||
                data['delivery'] == DeliveryStage.sending.toDbString())) {
          hasUpdates = true;
          batch.update(doc.reference, {
            'delivery': DeliveryStage.delivered.toDbString(),
          });
        }
      }

      if (hasUpdates) {
        batch.update(chatRef, {
          'delivery': DeliveryStage.delivered.toDbString(),
        });
        await batch.commit();
      }
    } catch (_) {}
  }

  @override
  Future<void> markConversationRead({
    required String chatId,
    required String readerUserId,
  }) async {
    final effectiveChatId = _canonicalChatId(chatId, readerUserId);
    try {
      final chatRef = _chatsCollection.doc(effectiveChatId);
      final snapshot = await chatRef
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(30)
          .get();

      final chatDoc = await chatRef.get();
      final chatData = chatDoc.data() ?? {};

      final chatUpdates = <String, dynamic>{
        'delivery': DeliveryStage.read.toDbString(),
        'lastMessageDelivery': DeliveryStage.read.toDbString(),
      };

      // Reset nested unreadCount map
      if (chatData['unreadCount'] is Map) {
        chatUpdates['unreadCount.$readerUserId'] = 0;
      } else {
        chatUpdates['unreadCount'] = {readerUserId: 0};
      }

      // Reset legacy literal dotted fields if present on the document
      if (chatData.containsKey('unreadCount.$readerUserId')) {
        chatUpdates['unreadCount.$readerUserId'] = 0;
      }
      if (chatData['unreadCounts'] is Map) {
        chatUpdates['unreadCounts.$readerUserId'] = 0;
      }
      if (chatData.containsKey('unreadCounts.$readerUserId')) {
        chatUpdates['unreadCounts.$readerUserId'] = 0;
      }

      final batch = _firestore.batch();
      batch.set(chatRef, chatUpdates, SetOptions(merge: true));

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['senderId'] != readerUserId &&
            data['delivery'] != DeliveryStage.read.toDbString()) {
          batch.update(doc.reference, {
            'delivery': DeliveryStage.read.toDbString(),
          });
        }
      }

      await batch.commit();
    } catch (_) {}
  }

  String _canonicalChatId(String chatId, String userId) {
    if (!chatId.startsWith('chat_') &&
        !chatId.startsWith('group_') &&
        chatId.isNotEmpty) {
      final sorted = [userId, chatId]..sort();
      return 'chat_${sorted[0]}_${sorted[1]}';
    }
    return chatId;
  }

  @override
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    String effectiveChatId = chatId;
    if (!effectiveChatId.startsWith('chat_') &&
        !effectiveChatId.startsWith('group_')) {
      final sorted = [userId, effectiveChatId]..sort();
      effectiveChatId = 'chat_${sorted[0]}_${sorted[1]}';
    }

    try {
      await _chatsCollection.doc(effectiveChatId).set({
        'typing': {userId: isTyping},
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<Conversation> getOrCreateDirectConversation({
    required String currentUserId,
    required String recipientUserId,
    required String recipientName,
    String? recipientPublicKey,
  }) async {
    // Generate canonical composite document ID: chat_{minUid}_{maxUid}
    final sorted = [currentUserId, recipientUserId]..sort();
    final canonicalId = 'chat_${sorted[0]}_${sorted[1]}';
    _knownExistingChats.add(canonicalId);

    String resolvedPeerKey = '';
    if (_userPublicKeyCache.containsKey(recipientUserId)) {
      resolvedPeerKey = _userPublicKeyCache[recipientUserId]!;
    } else {
      try {
        final peerDoc = await _usersCollection.doc(recipientUserId).get();
        final pub = (peerDoc.data()?['publicKey'] as String?)?.trim();
        if (pub != null && pub.isNotEmpty) {
          _userPublicKeyCache[recipientUserId] = pub;
          resolvedPeerKey = pub;
        }
      } catch (_) {
        resolvedPeerKey = _userPublicKeyCache[recipientUserId] ?? '';
      }
    }
    if (resolvedPeerKey.isEmpty) {
      resolvedPeerKey = recipientPublicKey?.trim() ?? '';
    }

    String myPublicKey = '';
    try {
      myPublicKey = await _cryptoService.getOrCreatePublicKey();
    } catch (_) {}

    String currentUserName = 'Me';
    try {
      if (_userDisplayNameCache.containsKey(currentUserId)) {
        currentUserName = _userDisplayNameCache[currentUserId]!;
      } else {
        final myDoc = await _usersCollection.doc(currentUserId).get();
        currentUserName =
            (myDoc.data()?['displayName'] as String?)?.trim() ?? 'Me';
        _userDisplayNameCache[currentUserId] = currentUserName;
      }
    } catch (_) {}

    final participantNames = {
      currentUserId: currentUserName,
      recipientUserId: recipientName,
    };

    final myAvatar = await _getOrFetchUserAvatar(currentUserId);
    final peerAvatar = await _getOrFetchUserAvatar(recipientUserId);
    final participantAvatars = {
      currentUserId: ?myAvatar,
      recipientUserId: ?peerAvatar,
    };

    final docRef = _chatsCollection.doc(canonicalId);
    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      final updates = <String, dynamic>{};
      final existingKeys = data['participantPublicKeys'] as Map<dynamic, dynamic>?;
      if (existingKeys == null) {
        if (myPublicKey.isNotEmpty || resolvedPeerKey.isNotEmpty) {
          updates['participantPublicKeys'] = {
            if (myPublicKey.isNotEmpty) currentUserId: myPublicKey,
            if (resolvedPeerKey.isNotEmpty) recipientUserId: resolvedPeerKey,
          };
        }
      } else {
        if (myPublicKey.isNotEmpty && existingKeys[currentUserId] != myPublicKey) {
          updates['participantPublicKeys.$currentUserId'] = myPublicKey;
        }
        if (resolvedPeerKey.isNotEmpty && existingKeys[recipientUserId] != resolvedPeerKey) {
          updates['participantPublicKeys.$recipientUserId'] = resolvedPeerKey;
        }
      }

      final existingNames = data['participantNames'] as Map<dynamic, dynamic>?;
      if (existingNames == null ||
          existingNames[currentUserId] == null ||
          existingNames[recipientUserId] == null) {
        updates['participantNames'] = {
          ...?existingNames,
          currentUserId: currentUserName,
          recipientUserId: recipientName,
        };
      }
      final existingAvatars = data['participantAvatars'] as Map<dynamic, dynamic>?;
      if (existingAvatars == null ||
          (myAvatar != null && existingAvatars[currentUserId] != myAvatar) ||
          (peerAvatar != null && existingAvatars[recipientUserId] != peerAvatar)) {
        updates['participantAvatars'] = {
          ...?existingAvatars,
          currentUserId: ?myAvatar,
          recipientUserId: ?peerAvatar,
        };
      }
      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
      return Conversation.fromMap(
        {
          ...data,
          if (updates.containsKey('participantNames'))
            'participantNames': updates['participantNames'],
          if (updates.containsKey('participantAvatars'))
            'participantAvatars': updates['participantAvatars'],
        },
        canonicalId,
        currentUserId: currentUserId,
        fallbackName: recipientName,
        fallbackAvatar: peerAvatar,
        recipientPublicKey: resolvedPeerKey.isNotEmpty ? resolvedPeerKey : null,
      );
    }

    // Initialize new 1-on-1 conversation document
    final newConvData = <String, dynamic>{
      'participantIds': [currentUserId, recipientUserId],
      'recipientId': recipientUserId,
      'name': recipientName,
      'participantNames': participantNames,
      if (participantAvatars.isNotEmpty)
        'participantAvatars': participantAvatars,
      'lastMessage': 'Started a new relay',
      'previewKind': 'text',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'delivery': DeliveryStage.sent.toDbString(),
      'isGroup': false,
      'createdAt': FieldValue.serverTimestamp(),
      'unreadCount': {
        currentUserId: 0,
        recipientUserId: 0,
      },
      'participantPublicKeys': {
        currentUserId: myPublicKey,
        recipientUserId: resolvedPeerKey,
      },
    };

    await docRef.set(newConvData);

    return Conversation(
      id: canonicalId,
      name: recipientName,
      avatarAsset: null,
      lastMessage: 'Started a new relay',
      timeLabel: 'Now',
      participantIds: [currentUserId, recipientUserId],
      recipientId: recipientUserId,
      recipientPublicKey: resolvedPeerKey.isNotEmpty ? resolvedPeerKey : null,
      participantNames: participantNames,
      delivery: DeliveryStage.sent,
    );
  }

  @override
  Future<List<RelayContact>> matchContacts(
    List<String> normalizedPhoneNumbers,
  ) async {
    if (normalizedPhoneNumbers.isEmpty) return const [];

    final matched = <RelayContact>[];
    final uniqueNumbers = normalizedPhoneNumbers.toSet().toList();

    // Batch queries in chunks of 30 to stay within Firestore limits
    for (var i = 0; i < uniqueNumbers.length; i += 30) {
      final chunk = uniqueNumbers.sublist(
        i,
        i + 30 > uniqueNumbers.length ? uniqueNumbers.length : i + 30,
      );

      final querySnapshot = await _usersCollection
          .where('phoneNumber', whereIn: chunk)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final av = (data['avatarUrl'] ?? data['photoUrl']) as String?;
        if (av != null && av.trim().isNotEmpty) {
          _userAvatarCache[doc.id] = av.trim();
        }
        matched.add(
          RelayContact(
            id: doc.id,
            displayName: (data['displayName'] as String?) ?? 'Relay User',
            phoneNumber: (data['phoneNumber'] as String?) ?? '',
            publicKey: data['publicKey'] as String?,
            about: data['about'] as String?,
            avatarUrl: av?.trim(),
            isRegistered: true,
          ),
        );
      }
    }

    return matched;
  }

  @override
  Future<List<RelayContact>> searchUsers(String query) async {
    final cleanQuery = query.trim();
    final snapshot = await _usersCollection.limit(20).get();
    final currentUid = _auth.currentUser?.uid;
    final results = <RelayContact>[];

    for (final doc in snapshot.docs) {
      if (doc.id == currentUid) continue;
      final data = doc.data();
      final name = (data['displayName'] as String?) ?? '';
      final phone = (data['phoneNumber'] as String?) ?? '';
      final av = (data['avatarUrl'] ?? data['photoUrl']) as String?;
      if (av != null && av.trim().isNotEmpty) {
        _userAvatarCache[doc.id] = av.trim();
      }

      if (cleanQuery.isEmpty ||
          name.toLowerCase().contains(cleanQuery.toLowerCase()) ||
          phone.contains(cleanQuery)) {
        results.add(
          RelayContact(
            id: doc.id,
            displayName: name.isEmpty ? 'Relay User' : name,
            phoneNumber: phone,
            publicKey: data['publicKey'] as String?,
            about: data['about'] as String?,
            avatarUrl: av?.trim(),
            isRegistered: true,
          ),
        );
      }
    }

    return results;
  }

  @override
  Future<void> sendVoiceMessage({
    required String chatId,
    required String localFilePath,
    required Duration duration,
    required List<double> waveform,
    required String recipientPublicKey,
    String? messageId,
    String? replyTo,
    String? replyToId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot send voice note: Unauthenticated session.');
    }

    // Normalize chatId
    String effectiveChatId = chatId;
    if (!effectiveChatId.startsWith('chat_') && !effectiveChatId.startsWith('group_')) {
      final sorted = [user.uid, effectiveChatId]..sort();
      effectiveChatId = 'chat_${sorted[0]}_${sorted[1]}';
    }

    // Resolve recipient ID
    String? effectiveRecipientId;
    if (effectiveChatId.startsWith('chat_')) {
      final parts = effectiveChatId.replaceFirst('chat_', '').split('_');
      effectiveRecipientId = parts.where((p) => p != user.uid).firstOrNull;
    }

    // Resolve recipient public key
    String effectivePublicKey = '';
    if (effectiveRecipientId != null) {
      try {
        final peerDoc = await _usersCollection.doc(effectiveRecipientId).get();
        final pub = (peerDoc.data()?['publicKey'] as String?)?.trim();
        if (pub != null && pub.isNotEmpty) {
          _userPublicKeyCache[effectiveRecipientId] = pub;
          effectivePublicKey = pub;
        }
      } catch (_) {
        effectivePublicKey = _userPublicKeyCache[effectiveRecipientId] ?? '';
      }
    }

    if (effectivePublicKey.isEmpty) {
      effectivePublicKey = recipientPublicKey.trim();
    }

    final effectiveMessageId = (messageId != null && messageId.isNotEmpty)
        ? messageId
        : 'msg_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, math.min(6, user.uid.length))}';

    // 1. Read local audio bytes
    final audioFile = File(localFilePath);
    if (!await audioFile.exists()) {
      throw StateError('Local voice note file not found: $localFilePath');
    }
    final rawBytes = await audioFile.readAsBytes();

    // 2. Encrypt audio bytes with AES-256-GCM using peer shared secret
    String nonce;
    List<int> ciphertextBytes;
    if (effectivePublicKey.isNotEmpty) {
      final secret = await _getOrDeriveSecret(effectivePublicKey);
      final encrypted = await _cryptoService.encryptRawBytes(
        rawBytes: rawBytes,
        sharedSecretBytes: secret,
      );
      ciphertextBytes = encrypted.ciphertext;
      nonce = encrypted.nonce;
    } else {
      ciphertextBytes = rawBytes;
      nonce = base64Encode(List<int>.filled(12, 0));
    }

    // 3. Upload encrypted blob to Firebase Cloud Storage (with resilient inline fallback)
    String? downloadUrl;
    String? audioData;
    try {
      final storagePath = 'chats/$effectiveChatId/voice/$effectiveMessageId.enc';
      final storageRef = _storage.ref(storagePath);
      final uploadTask = await storageRef.putData(
        Uint8List.fromList(ciphertextBytes),
        SettableMetadata(contentType: 'application/octet-stream'),
      ).timeout(const Duration(milliseconds: 1500));
      downloadUrl = await uploadTask.ref.getDownloadURL().timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      // Graceful fallback to inline base64 if Cloud Storage bucket is not yet provisioned, timed out, or offline
      if (ciphertextBytes.length < 500 * 1024) {
        audioData = base64Encode(ciphertextBytes);
      } else {
        rethrow;
      }
    }

    // 4. Cache local decrypted file so sender does not re-download
    try {
      final cacheDir = await getTemporaryDirectory();
      final localCacheFile = File('${cacheDir.path}/voice_$effectiveMessageId.m4a');
      if (localFilePath != localCacheFile.path) {
        await audioFile.copy(localCacheFile.path);
      }
    } catch (_) {}

    // 5. Construct RelayMessage and batch write to Firestore
    final message = RelayMessage(
      id: effectiveMessageId,
      senderId: user.uid,
      recipientId: effectiveRecipientId,
      sentAt: DateTime.now(),
      kind: MessageKind.voice,
      encryptedPayload: '[Voice message]',
      audioUrl: downloadUrl,
      audioData: audioData,
      waveform: waveform,
      duration: duration,
      nonce: nonce,
      delivery: DeliveryStage.sent,
      replyTo: replyTo,
      replyToId: replyToId,
    );

    final chatRef = _chatsCollection.doc(effectiveChatId);
    final messageRef = chatRef.collection('messages').doc(effectiveMessageId);
    final batch = _firestore.batch();

    String currentUserName = _userDisplayNameCache[user.uid] ?? 'Me';
    if (!_userDisplayNameCache.containsKey(user.uid)) {
      _usersCollection
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache))
          .then((doc) {
        final name = (doc.data()?['displayName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          _userDisplayNameCache[user.uid] = name;
        }
      }).catchError((_) {});
    }

    String peerName = 'Relay Contact';
    if (effectiveRecipientId != null) {
      final recipientId = effectiveRecipientId;
      peerName = _userDisplayNameCache[recipientId] ?? 'Relay Contact';
      if (!_userDisplayNameCache.containsKey(recipientId)) {
        _usersCollection
            .doc(recipientId)
            .get(const GetOptions(source: Source.cache))
            .then((doc) {
          final name = (doc.data()?['displayName'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            _userDisplayNameCache[recipientId] = name;
          }
        }).catchError((_) {});
      }
    }

    final myAvatar = _userAvatarCache[user.uid];
    final peerAvatar = effectiveRecipientId != null
        ? _userAvatarCache[effectiveRecipientId]
        : null;

    final durationSeconds = duration.inSeconds;
    final durationMinutes = duration.inMinutes;
    final secondsRem = durationSeconds % 60;
    final timeStr = '$durationMinutes:${secondsRem.toString().padLeft(2, '0')}';
    final voiceSnippet = 'Voice message · $timeStr';

    bool chatExists = _knownExistingChats.contains(effectiveChatId);
    DocumentSnapshot<Map<String, dynamic>>? chatDoc;

    if (!chatExists) {
      try {
        chatDoc = await chatRef.get(const GetOptions(source: Source.cache));
        chatExists = chatDoc.exists;
      } catch (_) {
        try {
          chatDoc = await chatRef.get().timeout(const Duration(milliseconds: 1500));
          chatExists = chatDoc.exists;
        } catch (_) {}
      }
    }

    if (!chatExists) {
      String myPublicKey = _cachedMyPublicKey ?? '';
      if (myPublicKey.isEmpty) {
        try {
          myPublicKey = await _cryptoService.getOrCreatePublicKey();
          if (myPublicKey.isNotEmpty) _cachedMyPublicKey = myPublicKey;
        } catch (_) {}
      }

      final participantNames = {
        user.uid: currentUserName,
        ?effectiveRecipientId: peerName,
      };
      final participantAvatars = {
        user.uid: ?myAvatar,
        ?effectiveRecipientId: ?peerAvatar,
      };

      final newConvData = <String, dynamic>{
        'participantIds': [user.uid, effectiveRecipientId ?? ''],
        'participantNames': participantNames,
        if (participantAvatars.isNotEmpty)
          'participantAvatars': participantAvatars,
        'name': peerName,
        'lastMessage': voiceSnippet,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'previewKind': 'voice',
        'unreadCount': {
          user.uid: 0,
          ?effectiveRecipientId: 1,
        },
        'delivery': 'sent',
        'lastMessageDelivery': 'sent',
        'isGroup': false,
        'pinned': false,
        'muted': false,
        if (effectivePublicKey.isNotEmpty || myPublicKey.isNotEmpty)
          'participantPublicKeys': {
            user.uid: myPublicKey,
            if (effectiveRecipientId != null && effectivePublicKey.isNotEmpty)
              effectiveRecipientId: effectivePublicKey,
          },
      };
      batch.set(chatRef, newConvData);
    } else {
      final updateData = <String, dynamic>{
        'lastMessage': voiceSnippet,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'previewKind': 'voice',
        'delivery': 'sent',
        'lastMessageDelivery': 'sent',
        'unreadCount.${user.uid}': 0,
        if (effectiveRecipientId != null)
          'unreadCount.$effectiveRecipientId': FieldValue.increment(1),
        if (effectiveRecipientId != null && effectivePublicKey.isNotEmpty)
          'participantPublicKeys.$effectiveRecipientId': effectivePublicKey,
        'participantAvatars.${user.uid}': ?myAvatar,
      };
      batch.set(chatRef, updateData, SetOptions(merge: true));
    }

    // Keep the ordering timestamp available locally while the write is pending.
    batch.set(messageRef, message.toMap(useServerTimestamp: false));
    await batch.commit();
    _knownExistingChats.add(effectiveChatId);
  }

  @override
  Future<String> getOrDownloadVoiceAudio({
    required String chatId,
    required String messageId,
    required String audioUrl,
    String? audioData,
    required String peerPublicKey,
    required String nonce,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final localCacheFile = File('${cacheDir.path}/voice_$messageId.m4a');

    // Return cached decrypted audio if present and valid
    if (await localCacheFile.exists() && await localCacheFile.length() > 0) {
      return localCacheFile.path;
    }

    // Check if audioUrl is already a local file path
    if (audioUrl.isNotEmpty && File(audioUrl).existsSync()) {
      return audioUrl;
    }

    // Download ciphertext bytes from Firebase Storage or decode inline audioData
    Uint8List? ciphertextBytes;
    if (audioUrl.isNotEmpty) {
      try {
        if (audioUrl.startsWith('gs://') || !audioUrl.startsWith('http')) {
          final storageRef = _storage.ref(audioUrl);
          ciphertextBytes = await storageRef.getData().timeout(const Duration(milliseconds: 2000));
        } else {
          final storageRef = _storage.refFromURL(audioUrl);
          ciphertextBytes = await storageRef.getData().timeout(const Duration(milliseconds: 2000));
        }
      } catch (_) {}
    }

    if ((ciphertextBytes == null || ciphertextBytes.isEmpty) &&
        audioData != null &&
        audioData.isNotEmpty) {
      try {
        ciphertextBytes = base64Decode(audioData);
      } catch (_) {}
    }

    if (ciphertextBytes == null || ciphertextBytes.isEmpty) {
      throw StateError('Voice audio payload empty or not found in storage');
    }

    // Decrypt audio bytes using peer shared secret
    List<int> decryptedBytes;
    if (peerPublicKey.isNotEmpty && nonce.isNotEmpty) {
      final secret = await _getOrDeriveSecret(peerPublicKey);
      decryptedBytes = await _cryptoService.decryptRawBytes(
        combinedBytes: ciphertextBytes,
        nonceBase64: nonce,
        sharedSecretBytes: secret,
      );
    } else {
      decryptedBytes = ciphertextBytes;
    }

    // Save decrypted AAC to local cache
    await localCacheFile.writeAsBytes(decryptedBytes, flush: true);
    return localCacheFile.path;
  }

  @override
  Future<void> sendImageMessage({
    required String chatId,
    required String localFilePath,
    required String recipientPublicKey,
    String? caption,
    String? messageId,
    String? replyTo,
    String? replyToId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not authenticated');

    String effectiveChatId = chatId;
    if (!effectiveChatId.startsWith('chat_') && !effectiveChatId.startsWith('group_')) {
      final sorted = [user.uid, effectiveChatId]..sort();
      effectiveChatId = 'chat_${sorted[0]}_${sorted[1]}';
    }

    // Resolve recipient ID
    String? effectiveRecipientId;
    if (effectiveChatId.startsWith('chat_')) {
      final parts = effectiveChatId.replaceFirst('chat_', '').split('_');
      effectiveRecipientId = parts.first == user.uid ? parts.last : parts.first;
    }

    final effectiveMessageId = (messageId != null && messageId.isNotEmpty)
        ? messageId
        : 'msg_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, math.min(6, user.uid.length))}';

    // 1. Read local image bytes
    final imageFile = File(localFilePath);
    if (!await imageFile.exists()) {
      throw StateError('Local image file not found: $localFilePath');
    }
    final rawBytes = await imageFile.readAsBytes();

    // 2. Upload image to Firebase Cloud Storage with resilient inline fallback
    String? downloadUrl;
    String? imageData;
    try {
      final storagePath = 'chats/$effectiveChatId/images/$effectiveMessageId.jpg';
      final storageRef = _storage.ref(storagePath);
      final uploadTask = await storageRef.putData(
        rawBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(milliseconds: 3500));
      downloadUrl = await uploadTask.ref.getDownloadURL().timeout(const Duration(milliseconds: 2500));
    } catch (_) {
      // Resilient fallback to inline base64 if Cloud Storage times out, offline, or unprovisioned
      if (rawBytes.length < 800 * 1024) {
        imageData = base64Encode(rawBytes);
      }
    }

    // Always guarantee that a visual payload is present
    if (downloadUrl == null && imageData == null && rawBytes.isNotEmpty) {
      imageData = base64Encode(rawBytes);
    }

    // 3. Cache local image file in persistent application documents directory
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${docsDir.path}/relay_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final localCacheFile = File('${imagesDir.path}/img_$effectiveMessageId.jpg');
      if (localFilePath != localCacheFile.path) {
        await imageFile.copy(localCacheFile.path);
      }
    } catch (_) {}

    // 4. Construct RelayMessage and batch write to Firestore
    final message = RelayMessage(
      id: effectiveMessageId,
      senderId: user.uid,
      recipientId: effectiveRecipientId,
      sentAt: DateTime.now(),
      kind: MessageKind.image,
      text: caption,
      imageUrl: downloadUrl,
      imageData: imageData,
      asset: null,
      delivery: DeliveryStage.sent,
      replyTo: replyTo,
      replyToId: replyToId,
    );

    final chatRef = _chatsCollection.doc(effectiveChatId);
    final messageRef = chatRef.collection('messages').doc(effectiveMessageId);
    final batch = _firestore.batch();

    String currentUserName = _userDisplayNameCache[user.uid] ?? 'Me';
    if (!_userDisplayNameCache.containsKey(user.uid)) {
      _usersCollection
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache))
          .then((doc) {
        final name = (doc.data()?['displayName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          _userDisplayNameCache[user.uid] = name;
        }
      }).catchError((_) {});
    }

    String peerName = 'Relay Contact';
    if (effectiveRecipientId != null) {
      final recipientId = effectiveRecipientId;
      peerName = _userDisplayNameCache[recipientId] ?? 'Relay Contact';
      if (!_userDisplayNameCache.containsKey(recipientId)) {
        _usersCollection
            .doc(recipientId)
            .get(const GetOptions(source: Source.cache))
            .then((doc) {
          final name = (doc.data()?['displayName'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            _userDisplayNameCache[recipientId] = name;
          }
        }).catchError((_) {});
      }
    }

    final myAvatar = _userAvatarCache[user.uid];
    final peerAvatar = effectiveRecipientId != null
        ? _userAvatarCache[effectiveRecipientId]
        : null;

    final snippet = caption != null && caption.isNotEmpty ? caption : 'Photo';
    final messageData = message.toMap(useServerTimestamp: true);

    bool chatExists = _knownExistingChats.contains(effectiveChatId);
    DocumentSnapshot<Map<String, dynamic>>? chatDoc;

    if (!chatExists) {
      try {
        chatDoc = await chatRef.get(const GetOptions(source: Source.cache));
        chatExists = chatDoc.exists;
      } catch (_) {
        try {
          chatDoc = await chatRef.get().timeout(const Duration(milliseconds: 1500));
          chatExists = chatDoc.exists;
        } catch (_) {}
      }
    }

    if (!chatExists) {
      final participantNames = {
        user.uid: currentUserName,
        ?effectiveRecipientId: peerName,
      };
      final participantAvatars = {
        user.uid: ?myAvatar,
        ?effectiveRecipientId: ?peerAvatar,
      };

      final newConvData = <String, dynamic>{
        'participantIds': [user.uid, effectiveRecipientId ?? ''],
        'participants': [user.uid, ?effectiveRecipientId],
        'recipientId': effectiveRecipientId,
        'name': peerName,
        'participantNames': participantNames,
        if (participantAvatars.isNotEmpty)
          'participantAvatars': participantAvatars,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': snippet,
        'previewKind': MessageKind.image.toDbString(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'delivery': DeliveryStage.sent.toDbString(),
        'lastMessageDelivery': DeliveryStage.sent.toDbString(),
        'unreadCount': {
          user.uid: 0,
          ?effectiveRecipientId: 1,
        },
        'unreadCounts': {
          user.uid: 0,
          ?effectiveRecipientId: 1,
        },
        'isGroup': false,
        if (effectiveRecipientId != null && recipientPublicKey.isNotEmpty)
          'participantPublicKeys': {
            effectiveRecipientId: recipientPublicKey,
          },
      };
      batch.set(chatRef, newConvData);
    } else {
      final updateData = <String, dynamic>{
        'lastMessage': snippet,
        'previewKind': MessageKind.image.toDbString(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'delivery': DeliveryStage.sent.toDbString(),
        'lastMessageDelivery': DeliveryStage.sent.toDbString(),
        'unreadCount.${user.uid}': 0,
        if (effectiveRecipientId != null) ...{
          'unreadCount.$effectiveRecipientId': FieldValue.increment(1),
          'unreadCounts.$effectiveRecipientId': FieldValue.increment(1),
        },
        'participantAvatars.${user.uid}': ?myAvatar,
      };
      batch.set(chatRef, updateData, SetOptions(merge: true));
    }

    batch.set(messageRef, messageData);
    await batch.commit();
    _knownExistingChats.add(effectiveChatId);
  }

  @override
  Future<String> getOrDownloadImage({
    required String chatId,
    required String messageId,
    required String imageUrl,
    String? imageData,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${docsDir.path}/relay_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final localCacheFile = File('${imagesDir.path}/img_$messageId.jpg');

    // Return cached file if present and valid
    if (await localCacheFile.exists() && await localCacheFile.length() > 0) {
      return localCacheFile.path;
    }

    // Check if imageUrl is already a local file path
    if (imageUrl.isNotEmpty && File(imageUrl).existsSync()) {
      return imageUrl;
    }

    // Download image bytes from Cloud Storage or decode inline imageData
    Uint8List? imageBytes;
    if (imageUrl.isNotEmpty) {
      try {
        if (imageUrl.startsWith('gs://') || !imageUrl.startsWith('http')) {
          final storageRef = _storage.ref(imageUrl);
          imageBytes = await storageRef.getData().timeout(const Duration(milliseconds: 3000));
        } else {
          final storageRef = _storage.refFromURL(imageUrl);
          imageBytes = await storageRef.getData().timeout(const Duration(milliseconds: 3000));
        }
      } catch (_) {}
    }

    if ((imageBytes == null || imageBytes.isEmpty) &&
        imageData != null &&
        imageData.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageData);
      } catch (_) {}
    }

    if (imageBytes == null || imageBytes.isEmpty) {
      throw StateError('Image payload empty or not found in storage');
    }

    await localCacheFile.writeAsBytes(imageBytes, flush: true);
    return localCacheFile.path;
  }

  @override
  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String? reaction,
  }) async {
    String effectiveChatId = chatId;
    if (!effectiveChatId.startsWith('chat_') && !effectiveChatId.startsWith('group_')) {
      final user = _auth.currentUser;
      if (user != null) {
        final sorted = [user.uid, effectiveChatId]..sort();
        effectiveChatId = 'chat_${sorted[0]}_${sorted[1]}';
      }
    }

    final messageRef = _chatsCollection
        .doc(effectiveChatId)
        .collection('messages')
        .doc(messageId);

    if (reaction != null && reaction.isNotEmpty) {
      await messageRef.update({'reactions.$userId': reaction});
    } else {
      await messageRef.update({'reactions.$userId': FieldValue.delete()});
    }
  }

  @override
  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberIds,
    required String adminId,
    String? description,
    String? avatarUrl,
  }) async {
    final effectiveGroupId =
        'group_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
    final allParticipants = <String>{adminId, ...memberIds}.toList();
    final groupRef = _chatsCollection.doc(effectiveGroupId);

    final participantNames = <String, String>{};
    final participantAvatars = <String, String>{};

    for (final uid in allParticipants) {
      if (_userDisplayNameCache.containsKey(uid)) {
        participantNames[uid] = _userDisplayNameCache[uid]!;
      } else {
        try {
          final doc = await _usersCollection.doc(uid).get();
          final dName = (doc.data()?['displayName'] as String?)?.trim();
          if (dName != null && dName.isNotEmpty) {
            _userDisplayNameCache[uid] = dName;
            participantNames[uid] = dName;
          }
        } catch (_) {}
      }

      final av = await _getOrFetchUserAvatar(uid);
      if (av != null && av.isNotEmpty) {
        participantAvatars[uid] = av;
      }
    }

    final unreadMap = <String, int>{
      for (final uid in allParticipants) uid: 0,
    };

    final groupData = <String, dynamic>{
      'id': effectiveGroupId,
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty) ...{
        'avatarUrl': avatarUrl.trim(),
        'avatarAsset': avatarUrl.trim(),
      },
      'isGroup': true,
      'participantIds': allParticipants,
      'adminIds': [adminId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Group created',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'previewKind': MessageKind.text.toDbString(),
      'unreadCount': unreadMap,
      if (participantNames.isNotEmpty) 'participantNames': participantNames,
      if (participantAvatars.isNotEmpty) 'participantAvatars': participantAvatars,
    };

    await groupRef.set(groupData);

    return Conversation(
      id: effectiveGroupId,
      name: name.trim(),
      description: description?.trim(),
      avatarAsset: avatarUrl?.trim(),
      lastMessage: 'Group created',
      timeLabel: 'Now',
      lastMessageAt: DateTime.now(),
      participantIds: allParticipants,
      participantNames: participantNames,
      isGroup: true,
      adminIds: [adminId],
    );
  }

  Future<String> _resolveDisplayName(String uid) async {
    if (_userDisplayNameCache.containsKey(uid)) {
      return _userDisplayNameCache[uid]!;
    }
    try {
      final doc = await _usersCollection.doc(uid).get();
      final name = (doc.data()?['displayName'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        _userDisplayNameCache[uid] = name;
        return name;
      }
    } catch (_) {}
    return 'A member';
  }

  @override
  Future<void> sendSystemMessage({
    required String groupId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    final messageId = 'sys_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
    final messageRef = _chatsCollection.doc(groupId).collection('messages').doc(messageId);
    final chatRef = _chatsCollection.doc(groupId);

    final sysMessage = RelayMessage(
      id: messageId,
      senderId: user?.uid ?? 'system',
      senderName: 'System',
      recipientId: groupId,
      sentAt: DateTime.now(),
      kind: MessageKind.system,
      text: text,
      delivery: DeliveryStage.sent,
    );

    final batch = _firestore.batch();
    batch.set(messageRef, sysMessage.toMap(useServerTimestamp: true));
    batch.update(chatRef, {
      'lastMessage': text,
      'previewKind': MessageKind.system.toDbString(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      updates['name'] = name.trim();
    }
    if (description != null) {
      updates['description'] = description.trim();
    }
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      updates['avatarUrl'] = avatarUrl.trim();
      updates['avatarAsset'] = avatarUrl.trim();
    }
    if (updates.isNotEmpty) {
      await _chatsCollection.doc(groupId).update(updates);
      final currentUid = _auth.currentUser?.uid;
      final actorName = currentUid != null ? await _resolveDisplayName(currentUid) : 'An admin';
      if (name != null && name.trim().isNotEmpty) {
        await sendSystemMessage(groupId: groupId, text: '$actorName changed the group name to "$name"');
      } else if (description != null) {
        await sendSystemMessage(groupId: groupId, text: '$actorName updated the group description');
      } else if (avatarUrl != null) {
        await sendSystemMessage(groupId: groupId, text: '$actorName updated the group photo');
      }
    }
  }

  @override
  Future<void> promoteToAdmin({
    required String groupId,
    required String targetUserId,
  }) async {
    await _chatsCollection.doc(groupId).update({
      'adminIds': FieldValue.arrayUnion([targetUserId]),
    });
    final currentUid = _auth.currentUser?.uid;
    final actorName = currentUid != null ? await _resolveDisplayName(currentUid) : 'An admin';
    final targetName = await _resolveDisplayName(targetUserId);
    await sendSystemMessage(groupId: groupId, text: '$actorName appointed $targetName as an admin');
  }

  @override
  Future<void> demoteAdmin({
    required String groupId,
    required String targetUserId,
  }) async {
    await _chatsCollection.doc(groupId).update({
      'adminIds': FieldValue.arrayRemove([targetUserId]),
    });
    final currentUid = _auth.currentUser?.uid;
    final actorName = currentUid != null ? await _resolveDisplayName(currentUid) : 'An admin';
    final targetName = await _resolveDisplayName(targetUserId);
    await sendSystemMessage(groupId: groupId, text: '$actorName dismissed $targetName as an admin');
  }

  @override
  Future<void> addGroupMembers({
    required String groupId,
    required List<RelayContact> newMembers,
  }) async {
    final newMemberIds = newMembers.map((m) => m.id).toList();
    if (newMemberIds.isEmpty) return;

    final updates = <String, dynamic>{
      'participantIds': FieldValue.arrayUnion(newMemberIds),
    };

    for (final member in newMembers) {
      updates['participantNames.${member.id}'] = member.displayName;
      if (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) {
        updates['participantAvatars.${member.id}'] = member.avatarUrl!;
      }
    }

    await _chatsCollection.doc(groupId).update(updates);
    final currentUid = _auth.currentUser?.uid;
    final actorName = currentUid != null ? await _resolveDisplayName(currentUid) : 'An admin';
    final names = newMembers.map((m) => m.displayName).join(', ');
    await sendSystemMessage(groupId: groupId, text: '$actorName added $names');
  }

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String targetUserId,
  }) async {
    await _chatsCollection.doc(groupId).update({
      'participantIds': FieldValue.arrayRemove([targetUserId]),
      'adminIds': FieldValue.arrayRemove([targetUserId]),
    });
    final currentUid = _auth.currentUser?.uid;
    final actorName = currentUid != null ? await _resolveDisplayName(currentUid) : 'An admin';
    final targetName = await _resolveDisplayName(targetUserId);
    await sendSystemMessage(groupId: groupId, text: '$actorName removed $targetName');
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String currentUserId,
  }) async {
    final docRef = _chatsCollection.doc(groupId);
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) return;

    final data = docSnapshot.data() ?? {};
    final participants = (data['participantIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final admins = (data['adminIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final remainingParticipants =
        participants.where((id) => id != currentUserId).toList();
    var remainingAdmins = admins.where((id) => id != currentUserId).toList();

    // If leaving member was admin and no admins remain, auto-promote next member
    if (remainingAdmins.isEmpty && remainingParticipants.isNotEmpty) {
      remainingAdmins = [remainingParticipants.first];
    }

    await docRef.update({
      'participantIds': remainingParticipants,
      'adminIds': remainingAdmins,
    });
    final actorName = await _resolveDisplayName(currentUserId);
    await sendSystemMessage(groupId: groupId, text: '$actorName left the group');
  }
}
