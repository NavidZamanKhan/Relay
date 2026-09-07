import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/firestore_chat_repository.dart';

class FakeUser extends Fake implements User {
  FakeUser({required this.uid});
  @override
  final String uid;
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  FakeFirebaseAuth({this.user});
  User? user;
  @override
  User? get currentUser => user;
}

void main() {
  group('FirestoreChatRepository Anti-Spoofing & Validation', () {
    test('rejects sendMessage when unauthenticated', () async {
      final fakeAuth = FakeFirebaseAuth(user: null);
      final repo = FirestoreChatRepository(auth: fakeAuth);

      final message = RelayMessage(
        id: 'msg_test',
        senderId: 'user_spoofed',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Hello world',
      );

      expect(
        () => repo.sendMessage(
          chatId: 'chat_123',
          message: message,
          recipientPublicKey: 'PEER_PUBKEY',
        ),
        throwsStateError,
      );
    });

    test('matchContacts returns empty list when given empty input', () async {
      final fakeAuth = FakeFirebaseAuth(user: FakeUser(uid: 'user_alice'));
      final repo = FirestoreChatRepository(auth: fakeAuth);

      final result = await repo.matchContacts([]);
      expect(result, isEmpty);
    });
  });
}
