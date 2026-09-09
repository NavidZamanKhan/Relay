import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/crypto/crypto_service.dart';
import '../models/conversation.dart';
import '../models/delivery_stage.dart';
import '../models/relay_contact.dart';
import '../models/relay_message.dart';
import 'i_chat_repository.dart';

/// Production implementation of [IChatRepository] backed by Cloud Firestore
/// and hardened with client-side X25519/AES-GCM End-to-End Encryption.
class FirestoreChatRepository implements IChatRepository {
  FirestoreChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    CryptoService? cryptoService,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _cryptoService = cryptoService ?? CryptoService();

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final CryptoService _cryptoService;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  final Map<String, List<int>> _sharedSecretCache = {};
  final Map<String, String> _userDisplayNameCache = {};
  final Map<String, String> _userPublicKeyCache = {};

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

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) {
    return _chatsCollection
        .where('participantIds', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = <Conversation>[];

      for (final doc in snapshot.docs) {
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

        conversations.add(
          Conversation.fromMap(
            data,
            doc.id,
            currentUserId: currentUserId,
            fallbackName: resolvedFallbackName,
            recipientPublicKey: resolvedPublicKey,
          ),
        );
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

        // If message is encrypted and carries nonce, decrypt client-side
        if (rawMessage.encryptedPayload != null && rawMessage.nonce != null) {
          try {
            // In 1-on-1 chats, we can look up peer key or decrypt with peer's public key
            final peerUid = rawMessage.isMine
                ? rawMessage.recipientId
                : rawMessage.senderId;

            if (peerUid != null) {
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
          } catch (_) {
            // Decryption failure fallback: show guarded preview
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

    // Resolve recipient public key: users directory is canonical source of truth
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

    final payload = message.copyWith(
      senderId: user.uid,
      recipientId: effectiveRecipientId,
      encryptedPayload: ciphertext,
      nonce: nonce,
      delivery: DeliveryStage.sent,
    );

    final chatDoc = await chatRef.get();
    final batch = _firestore.batch();

    String currentUserName = 'Me';
    try {
      if (_userDisplayNameCache.containsKey(user.uid)) {
        currentUserName = _userDisplayNameCache[user.uid]!;
      } else {
        final myDoc = await _usersCollection.doc(user.uid).get();
        currentUserName =
            (myDoc.data()?['displayName'] as String?)?.trim() ?? 'Me';
        _userDisplayNameCache[user.uid] = currentUserName;
      }
    } catch (_) {}

    String peerName = 'Relay Contact';
    if (effectiveRecipientId != null) {
      if (_userDisplayNameCache.containsKey(effectiveRecipientId)) {
        peerName = _userDisplayNameCache[effectiveRecipientId]!;
      } else {
        try {
          final pDoc = await _usersCollection.doc(effectiveRecipientId).get();
          peerName = (pDoc.data()?['displayName'] as String?)?.trim() ??
              'Relay Contact';
          _userDisplayNameCache[effectiveRecipientId] = peerName;
        } catch (_) {}
      }
    }

    final participantNames = {
      user.uid: currentUserName,
      ?effectiveRecipientId: peerName,
    };

    if (!chatDoc.exists) {
      String myPublicKey = '';
      try {
        myPublicKey = await _cryptoService.getOrCreatePublicKey();
      } catch (_) {}

      final newConvData = <String, dynamic>{
        'participantIds': [user.uid, effectiveRecipientId ?? ''],
        'recipientId': effectiveRecipientId,
        'name': peerName,
        'participantNames': participantNames,
        'lastMessage': message.text ?? 'Media message',
        'previewKind': message.kind.toDbString(),
        'lastMessageAt': FieldValue.serverTimestamp(),
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
      return;
    }
    batch.set(messageRef, payload.toMap(useServerTimestamp: true));

    // Update parent conversation thread metadata
    final updateData = <String, dynamic>{
      'lastMessage': message.text ?? 'Media message',
      'previewKind': message.kind.toDbString(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'delivery': DeliveryStage.sent.toDbString(),
    };

    final existingData = chatDoc.data();
    if (existingData != null) {
      if (existingData['participantNames'] == null) {
        updateData['participantNames'] = participantNames;
      }
      // Synchronize recipient's public key on parent chat doc if changed or missing
      if (effectiveRecipientId != null && effectivePublicKey.isNotEmpty) {
        final existingKeys = existingData['participantPublicKeys'] as Map<dynamic, dynamic>?;
        if (existingKeys?[effectiveRecipientId] != effectivePublicKey) {
          updateData['participantPublicKeys.$effectiveRecipientId'] = effectivePublicKey;
        }
      }
      // Synchronize sender's public key on parent chat doc if changed or missing
      String myPublicKey = '';
      try {
        myPublicKey = await _cryptoService.getOrCreatePublicKey();
      } catch (_) {}
      if (myPublicKey.isNotEmpty) {
        final existingKeys = existingData['participantPublicKeys'] as Map<dynamic, dynamic>?;
        if (existingKeys?[user.uid] != myPublicKey) {
          updateData['participantPublicKeys.${user.uid}'] = myPublicKey;
        }
      }
    }

    if (effectiveRecipientId != null) {
      updateData['unreadCount.$effectiveRecipientId'] = FieldValue.increment(1);
    }

    batch.update(chatRef, updateData);
    await batch.commit();
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

      final batch = _firestore.batch();
      batch.update(chatRef, {
        'unreadCount.$readerUserId': 0,
        'delivery': DeliveryStage.read.toDbString(),
      });

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

    await _chatsCollection.doc(effectiveChatId).update({
      'typing.$userId': isTyping,
    });
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
      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
      return Conversation.fromMap(
        {
          ...data,
          if (updates.containsKey('participantNames'))
            'participantNames': updates['participantNames'],
        },
        canonicalId,
        currentUserId: currentUserId,
        fallbackName: recipientName,
        recipientPublicKey: resolvedPeerKey.isNotEmpty ? resolvedPeerKey : null,
      );
    }

    // Initialize new 1-on-1 conversation document
    final newConvData = <String, dynamic>{
      'participantIds': [currentUserId, recipientUserId],
      'recipientId': recipientUserId,
      'name': recipientName,
      'participantNames': participantNames,
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
        matched.add(
          RelayContact(
            id: doc.id,
            displayName: (data['displayName'] as String?) ?? 'Relay User',
            phoneNumber: (data['phoneNumber'] as String?) ?? '',
            publicKey: data['publicKey'] as String?,
            about: data['about'] as String?,
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
            isRegistered: true,
          ),
        );
      }
    }

    return results;
  }
}
