import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/firestore_chat_repository.dart';

typedef _Data = Map<String, dynamic>;

class _Firestore extends Fake implements FirebaseFirestore {
  final messageSnapshots = StreamController<QuerySnapshot<_Data>>.broadcast();
  final writes = _Batch();
  final documents = <String, _Data>{
    'chats/chat_alice_bob': {
      'participantIds': ['alice', 'bob'],
    },
    'users/alice': {'displayName': 'Alice'},
    'users/bob': {'displayName': 'Bob', 'publicKey': 'peer-key'},
  };

  @override
  CollectionReference<_Data> collection(String collectionPath) =>
      _Collection(this, collectionPath);

  @override
  WriteBatch batch() => writes;
}

// These SDK boundary fakes are test-only; production uses the sealed SDK types.
// ignore: subtype_of_sealed_class
class _Collection extends Fake implements CollectionReference<_Data> {
  _Collection(this.database, this.path);
  final _Firestore database;
  @override
  final String path;

  @override
  DocumentReference<_Data> doc([String? path]) =>
      _Document(database, '${this.path}/$path');

  @override
  Query<_Data> orderBy(Object field, {bool descending = false}) => this;

  @override
  Stream<QuerySnapshot<_Data>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => database.messageSnapshots.stream;
}

// ignore: subtype_of_sealed_class
class _Document extends Fake implements DocumentReference<_Data> {
  _Document(this.database, this.path);
  final _Firestore database;
  @override
  final String path;

  @override
  CollectionReference<_Data> collection(String collectionPath) =>
      _Collection(database, '$path/$collectionPath');

  @override
  Future<DocumentSnapshot<_Data>> get([GetOptions? options]) async =>
      _Snapshot(path.split('/').last, database.documents[path]!);
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements QueryDocumentSnapshot<_Data> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final _Data value;

  @override
  bool get exists => true;

  @override
  _Data data() => value;
}

class _QuerySnapshot extends Fake implements QuerySnapshot<_Data> {
  _QuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<_Data>> docs;
}

class _Batch extends Fake implements WriteBatch {
  final messages = <String, _Data>{};
  bool committed = false;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    messages[document.path] = data as _Data;
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {}

  @override
  Future<void> commit() async {
    committed = true;
  }
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'alice';
}

class _UnavailableStorage extends Fake implements FirebaseStorage {
  @override
  Reference ref([String? path]) => throw StateError('Storage unavailable');
}

class _Crypto extends Fake implements CryptoService {
  final textPayloads = <String>[];

  @override
  Future<List<int>> deriveSharedSecret({
    required String peerPublicKeyBase64,
  }) async => [1, 2, 3];

  @override
  Future<String> decryptPayload({
    required String ciphertextBase64,
    required String nonceBase64,
    required List<int> sharedSecretBytes,
  }) async {
    textPayloads.add(ciphertextBase64);
    return 'Decrypted text';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'voice write has an immediate timestamp and preserves inline audio',
    () async {
      final database = _Firestore();
      // Exercise the existing inline transport without provisioning cloud storage.
      database.documents['users/bob']!.remove('publicKey');
      final repository = FirestoreChatRepository(
        firestore: database,
        auth: _Auth(),
        storage: _UnavailableStorage(),
      );
      final directory = await Directory.systemTemp.createTemp('relay-voice-');
      addTearDown(() => directory.delete(recursive: true));
      addTearDown(database.messageSnapshots.close);
      final file = File('${directory.path}/recording.m4a');
      final bytes = [0, 255, 48, 128, 32];
      await file.writeAsBytes(bytes);
      final startedAt = DateTime.now();

      await repository.sendVoiceMessage(
        chatId: 'chat_alice_bob',
        messageId: 'client-voice-id',
        localFilePath: file.path,
        duration: const Duration(seconds: 5),
        waveform: [0.2, 0.4, 0.8],
        recipientPublicKey: '',
      );

      final data = database
          .writes
          .messages['chats/chat_alice_bob/messages/client-voice-id']!;
      expect(database.writes.committed, isTrue);
      expect(data['sentAt'], isA<Timestamp>());
      final sentAt = (data['sentAt'] as Timestamp).toDate();
      expect(sentAt.isBefore(startedAt), isFalse);
      expect(sentAt.isAfter(DateTime.now()), isFalse);
      expect(data['audioData'], base64Encode(bytes));
      expect(data['kind'], 'voice');
      expect(data['durationMs'], 5000);
    },
  );

  test(
    'voice snapshots keep audio payloads while text still decrypts',
    () async {
      final database = _Firestore();
      final crypto = _Crypto();
      final repository = FirestoreChatRepository(
        firestore: database,
        cryptoService: crypto,
      );
      addTearDown(database.messageSnapshots.close);
      final voice = RelayMessage(
        id: 'voice-inline',
        senderId: 'bob',
        recipientId: 'alice',
        sentAt: DateTime.now(),
        kind: MessageKind.voice,
        encryptedPayload: 'binary-audio-payload',
        nonce: 'audio-nonce',
        audioData: 'binary-audio-payload',
        duration: const Duration(seconds: 5),
        waveform: [0.2, 0.4, 0.8],
      );
      const audioUrl = 'https://example.com/voice.enc';
      final text = voice.copyWith(
        id: 'text',
        kind: MessageKind.text,
        encryptedPayload: 'encrypted-text',
      );
      final result = repository.watchMessages('chat_alice_bob', 'alice').first;
      database.messageSnapshots.add(
        _QuerySnapshot([
          _Snapshot(voice.id, voice.toMap()),
          _Snapshot(
            'voice-url',
            {
              ...voice.toMap(),
              'encryptedPayload': audioUrl,
              'audioUrl': audioUrl,
            }..remove('audioData'),
          ),
          _Snapshot(text.id, text.toMap()),
        ]),
      );

      final messages = await result;
      expect(messages, hasLength(3));
      expect(messages[0], voice);
      expect(messages[1].audioUrl, audioUrl);
      expect(messages[1].encryptedPayload, audioUrl);
      expect(messages[1].text, isNull);
      expect(messages[1].waveform, voice.waveform);
      expect(messages[2].text, 'Decrypted text');
      expect(crypto.textPayloads, ['encrypted-text']);
    },
  );
}
