import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/message_bubble.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';
import 'package:relay/features/chats/widgets/message_context_menu.dart';

class _FakeDeletionChatRepository extends Fake implements IChatRepository {
  final List<String> calls = [];
  String? deletedForMeChatId;
  String? deletedForMeMessageId;
  String? deletedForEveryoneChatId;
  String? deletedForEveryoneMessageId;

  final StreamController<List<RelayMessage>> _messagesController =
      StreamController<List<RelayMessage>>.broadcast();

  void emitMessages(List<RelayMessage> messages) {
    _messagesController.add(messages);
  }

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      const Stream.empty();

  @override
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId) =>
      _messagesController.stream;

  @override
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {}

  @override
  Future<void> markConversationRead({
    required String chatId,
    required String readerUserId,
  }) async {}

  @override
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    calls.add('deleteMessageForMe:$chatId:$messageId');
    deletedForMeChatId = chatId;
    deletedForMeMessageId = messageId;
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    calls.add('deleteMessageForEveryone:$chatId:$messageId');
    deletedForEveryoneChatId = chatId;
    deletedForEveryoneMessageId = messageId;
  }

  @override
  Future<void> clearChat({
    required String chatId,
    required String userId,
  }) async {
    calls.add('clearChat:$chatId:$userId');
  }

  Future<void> cleanup() async {
    await _messagesController.close();
  }
}

void main() {
  group('Dual Message Deletion Unit Tests (Delete for Me and Delete for Everyone)', () {
    late _FakeDeletionChatRepository fakeRepo;
    late ChatBloc bloc;
    const testChatId = 'chat_alice_bob';
    const currentUserId = 'user_alice';

    setUp(() {
      fakeRepo = _FakeDeletionChatRepository();
      bloc = ChatBloc(
        chatRepository: fakeRepo,
        currentUserId: currentUserId,
        demoMode: false,
      );
    });

    tearDown(() async {
      await bloc.close();
      await fakeRepo.cleanup();
    });

    test('RelayMessage model serializes and deserializes deletion fields correctly', () {
      final original = RelayMessage(
        id: 'msg_del_test_1',
        senderId: currentUserId,
        sentAt: DateTime.utc(2026, 9, 13, 2, 0),
        kind: MessageKind.text,
        text: 'This message will be deleted',
        isDeleted: true,
        deletedBy: currentUserId,
        deletedFor: const ['user_bob'],
      );

      final map = original.toMap();
      expect(map['isDeleted'], isTrue);
      expect(map['deletedBy'], equals(currentUserId));
      expect(map['deletedFor'], equals(['user_bob']));

      final deserialized = RelayMessage.fromMap(
        map,
        'msg_del_test_1',
        currentUserId: currentUserId,
      );
      expect(deserialized.isDeleted, isTrue);
      expect(deserialized.deletedBy, equals(currentUserId));
      expect(deserialized.deletedFor, equals(['user_bob']));
      expect(deserialized.isMine, isTrue);
    });

    test('ChatMessageDeleted with forMe removes message and invokes repository', () async {
      final msg1 = RelayMessage(
        id: 'msg_to_delete_for_me',
        senderId: 'user_bob',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Message to remove for me only',
        isMine: false,
      );
      final msg2 = RelayMessage(
        id: 'msg_to_keep',
        senderId: currentUserId,
        sentAt: DateTime.now().add(const Duration(seconds: 1)),
        kind: MessageKind.text,
        text: 'Staying alive',
        isMine: true,
      );

      bloc.add(const ChatOpened(testChatId));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      fakeRepo.emitMessages([msg1, msg2]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.threads[testChatId]?.length, equals(2));

      // Dispatch delete for me
      bloc.add(
        const ChatMessageDeleted(
          chatId: testChatId,
          messageId: 'msg_to_delete_for_me',
          mode: MessageDeleteMode.forMe,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final threadAfterDelete = bloc.state.threads[testChatId] ?? [];
      expect(threadAfterDelete.length, equals(1));
      expect(threadAfterDelete.any((m) => m.id == 'msg_to_delete_for_me'), isFalse);
      expect(threadAfterDelete.first.id, equals('msg_to_keep'));

      expect(fakeRepo.deletedForMeChatId, equals(testChatId));
      expect(fakeRepo.deletedForMeMessageId, equals('msg_to_delete_for_me'));
      expect(fakeRepo.calls, contains('deleteMessageForMe:$testChatId:msg_to_delete_for_me'));

      // Simulate a subsequent remote snapshot that still contains msg1 before remote update completes
      fakeRepo.emitMessages([msg1, msg2]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // msg1 must still be filtered out and NOT restored
      final threadAfterSnapshot = bloc.state.threads[testChatId] ?? [];
      expect(threadAfterSnapshot.length, equals(1));
      expect(threadAfterSnapshot.any((m) => m.id == 'msg_to_delete_for_me'), isFalse);
    });

    test('ChatMessageDeleted with forEveryone updates tombstone and invokes repository', () async {
      final msg = RelayMessage(
        id: 'msg_to_delete_for_everyone',
        senderId: currentUserId,
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Sent by mistake to all',
        isMine: true,
      );

      bloc.add(const ChatOpened(testChatId));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      fakeRepo.emitMessages([msg]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.threads[testChatId]?.length, equals(1));

      // Dispatch delete for everyone
      bloc.add(
        const ChatMessageDeleted(
          chatId: testChatId,
          messageId: 'msg_to_delete_for_everyone',
          mode: MessageDeleteMode.forEveryone,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final threadAfterDelete = bloc.state.threads[testChatId] ?? [];
      expect(threadAfterDelete.length, equals(1));
      final tombstone = threadAfterDelete.first;
      expect(tombstone.isDeleted, isTrue);
      expect(tombstone.text, equals('You deleted this message'));

      expect(fakeRepo.deletedForEveryoneChatId, equals(testChatId));
      expect(fakeRepo.deletedForEveryoneMessageId, equals('msg_to_delete_for_everyone'));
      expect(fakeRepo.calls, contains('deleteMessageForEveryone:$testChatId:msg_to_delete_for_everyone'));
    });

    test('Remote snapshot with isDeleted displays tombstone text for incoming message', () async {
      bloc.add(const ChatOpened(testChatId));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final remoteDeletedMsg = RelayMessage(
        id: 'msg_peer_retracted',
        senderId: 'user_bob',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'This message was deleted',
        isDeleted: true,
        deletedBy: 'user_bob',
        isMine: false,
      );

      fakeRepo.emitMessages([remoteDeletedMsg]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final thread = bloc.state.threads[testChatId] ?? [];
      expect(thread.length, equals(1));
      expect(thread.first.isDeleted, isTrue);
      expect(thread.first.text, equals('This message was deleted'));
      expect(thread.first.isMine, isFalse);
    });

    test('ChatHistoryCleared clears thread, removes conversation, and invokes repository clearChat', () async {
      bloc.add(const ChatOpened(testChatId));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final msg1 = RelayMessage(
        id: 'msg_clear_1',
        senderId: currentUserId,
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Message to be cleared',
        isMine: true,
      );

      fakeRepo.emitMessages([msg1]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.threads[testChatId]?.length, equals(1));

      bloc.add(const ChatHistoryCleared(chatId: testChatId));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.threads[testChatId], isEmpty);
      expect(fakeRepo.calls, contains('clearChat:$testChatId:$currentUserId'));

      fakeRepo.emitMessages([msg1]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.threads[testChatId], isEmpty);
    });

    testWidgets('Tapping delete on own message shows both Delete for everyone and Delete for me', (tester) async {
      final ownMsg = RelayMessage(
        id: 'widget_own_msg',
        senderId: currentUserId,
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'My own message to delete',
        isMine: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: MessageBubble(
                message: ownMsg,
                grouped: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('My own message to delete'), findsOneWidget);

      await tester.longPress(find.text('My own message to delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.byType(MessageContextOverlay), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageContextOverlay), findsNothing);
      expect(find.text('Delete for everyone'), findsOneWidget);
      expect(find.text('Delete for me'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping delete on peer message shows only Delete for me', (tester) async {
      final peerMsg = RelayMessage(
        id: 'widget_peer_msg',
        senderId: 'user_bob',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Bob message to delete',
        isMine: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: MessageBubble(
                message: peerMsg,
                grouped: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bob message to delete'), findsOneWidget);

      await tester.longPress(find.text('Bob message to delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.byType(MessageContextOverlay), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageContextOverlay), findsNothing);
      expect(find.text('Delete for everyone'), findsNothing);
      expect(find.text('Delete for me'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Deleted message renders tombstone and disables reply/copy in context menu', (tester) async {
      final deletedMsg = RelayMessage(
        id: 'widget_deleted_msg',
        senderId: currentUserId,
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'This message was deleted',
        isDeleted: true,
        isMine: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: MessageBubble(
                message: deletedMsg,
                grouped: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('You deleted this message'), findsOneWidget);

      await tester.longPress(find.text('You deleted this message'));
      await tester.pumpAndSettle();

      expect(find.text('Reply'), findsNothing);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete for everyone'), findsNothing);
      expect(find.text('Delete for me'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
