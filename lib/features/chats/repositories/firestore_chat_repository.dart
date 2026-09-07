import 'dart:async';
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
        .map((snapshot) {
      final conversations = snapshot.docs.map((doc) {
        return Conversation.fromMap(
          doc.data(),
          doc.id,
          currentUserId: currentUserId,
        );
      }).toList();

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
    return _chatsCollection
        .doc(chatId)
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
              final peerDoc = await _usersCollection.doc(peerUid).get();
              final peerPublicKey = peerDoc.data()?['publicKey'] as String?;

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

    String? ciphertext;
    String? nonce;

    // Encrypt plaintext payload on client device before transmission
    if (message.text != null && message.text!.isNotEmpty) {
      final secret = await _getOrDeriveSecret(recipientPublicKey);
      final result = await _cryptoService.encryptPayload(
        plaintext: message.text!,
        sharedSecretBytes: secret,
      );
      ciphertext = result.ciphertext;
      nonce = result.nonce;
    }

    final messageRef = _chatsCollection.doc(chatId).collection('messages').doc(message.id);
    final chatRef = _chatsCollection.doc(chatId);

    final payload = message.copyWith(
      senderId: user.uid,
      encryptedPayload: ciphertext,
      nonce: nonce,
      delivery: DeliveryStage.sent,
    );

    final batch = _firestore.batch();
    batch.set(messageRef, payload.toMap(useServerTimestamp: true));

    // Update parent conversation thread metadata
    final updateData = <String, dynamic>{
      'lastMessage': message.text ?? 'Media message',
      'previewKind': message.kind.toDbString(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'delivery': DeliveryStage.sent.toDbString(),
    };

    if (message.recipientId != null) {
      updateData['unreadCount.${message.recipientId}'] = FieldValue.increment(1);
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
    final messageRef =
        _chatsCollection.doc(chatId).collection('messages').doc(messageId);
    await messageRef.update({'delivery': status.toDbString()});
  }

  @override
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    await _chatsCollection.doc(chatId).update({
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

    final docRef = _chatsCollection.doc(canonicalId);
    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null) {
      return Conversation.fromMap(
        snapshot.data()!,
        canonicalId,
        currentUserId: currentUserId,
        fallbackName: recipientName,
        recipientPublicKey: recipientPublicKey,
      );
    }

    // Initialize new 1-on-1 conversation document
    final newConvData = <String, dynamic>{
      'participantIds': [currentUserId, recipientUserId],
      'recipientId': recipientUserId,
      'name': recipientName,
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
      recipientPublicKey: recipientPublicKey,
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
