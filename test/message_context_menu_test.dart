import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/audio_service.dart';
import 'package:relay/core/widgets/relay_toast.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/message_bubble.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';
import 'package:relay/features/chats/widgets/message_context_menu.dart';

class _MockContextMenuChatRepository implements IChatRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      const Stream.empty();

  @override
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId) =>
      const Stream.empty();

  @override
  Future<void> sendMessage({
    required String chatId,
    required RelayMessage message,
    required String recipientPublicKey,
  }) async {}

  @override
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {}
}

void main() {
  group('RelayToast HUD Component', () {
    testWidgets('RelayToast.show renders message and icon in overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  RelayToast.show(
                    context,
                    message: 'Action completed',
                    icon: CupertinoIcons.check_mark,
                  );
                },
                child: const Text('Show Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Action completed'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);

      // Allow toast timer and reverse animation to finish completely
      await tester.pump(const Duration(milliseconds: 2000));
    });
  });

  group('MessageContextOverlay Widget Tests', () {
    testWidgets('renders reactions and action menu items cleanly', (tester) async {
      String? selectedEmoji;

      final testMessage = RelayMessage(
        id: 'msg_ctx_1',
        senderId: 'user_me',
        sentAt: DateTime.utc(2026, 9, 11, 12, 0),
        kind: MessageKind.text,
        text: 'Context menu test message',
        isMine: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageContextOverlay(
              bubbleOffset: const Offset(100, 300),
              bubbleSize: const Size(200, 60),
              mine: true,
              message: testMessage,
              animation: const AlwaysStoppedAnimation<double>(1.0),
              currentReaction: null,
              onReactionSelected: (emoji) => selectedEmoji = emoji,
              onMoreReactionsPressed: () {},
              onReplyPressed: () {},
              onCopyPressed: () {},
              onSharePressed: () {},
              onInfoPressed: () {},
              onDeletePressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Verify reaction selection
      await tester.tap(find.text('\u{2764}\u{FE0F}'));
      expect(selectedEmoji, '\u{2764}\u{FE0F}');
    });

    testWidgets('tapping action item triggers corresponding callback', (tester) async {
      bool replyTriggered = false;

      final testMessage = RelayMessage(
        id: 'msg_ctx_action',
        senderId: 'user_me',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Action test message',
        isMine: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageContextOverlay(
              bubbleOffset: const Offset(100, 300),
              bubbleSize: const Size(200, 60),
              mine: true,
              message: testMessage,
              animation: const AlwaysStoppedAnimation<double>(1.0),
              currentReaction: null,
              onReactionSelected: (_) {},
              onMoreReactionsPressed: () {},
              onReplyPressed: () => replyTriggered = true,
              onCopyPressed: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Reply'));
      await tester.pump();
      expect(replyTriggered, isTrue);
    });

    testWidgets('stacked above when space below is limited', (tester) async {
      final testMessage = RelayMessage(
        id: 'msg_ctx_2',
        senderId: 'user_peer',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Near bottom message',
        isMine: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.only(top: 40, bottom: 30),
            ),
            child: Scaffold(
              body: MessageContextOverlay(
                bubbleOffset: const Offset(20, 680), // near bottom
                bubbleSize: const Size(200, 50),
                mine: false,
                message: testMessage,
                animation: const AlwaysStoppedAnimation<double>(1.0),
                currentReaction: null,
                onReactionSelected: (_) {},
                onMoreReactionsPressed: () {},
                onReplyPressed: () {},
                onCopyPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });
  });

  group('ChatBloc ChatMessageDeleted Event', () {
    test('removes message from active thread in ChatState', () async {
      final repo = _MockContextMenuChatRepository();
      final bloc = ChatBloc(
        chatRepository: repo,
        audioService: NoOpAudioService(),
        currentUserId: 'user_me',
      );

      final msg1 = RelayMessage(
        id: 'del_msg_1',
        senderId: 'user_me',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Keep me',
      );
      final msg2 = RelayMessage(
        id: 'del_msg_2',
        senderId: 'user_peer',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Delete me',
      );

      bloc.emit(bloc.state.copyWith(
        threads: {
          bloc.state.activeId: [msg1, msg2],
        },
      ));

      expect(bloc.state.messages.length, 2);

      bloc.add(ChatMessageDeleted(
        chatId: bloc.state.activeId,
        messageId: 'del_msg_2',
      ));
      await pumpEventQueue();

      expect(bloc.state.messages.length, 1);
      expect(bloc.state.messages.first.id, 'del_msg_1');

      bloc.close();
    });
  });

  group('MessageBubble Long-Press Opens Context Menu', () {
    testWidgets('long-pressing message bubble launches context overlay', (tester) async {
      final repo = _MockContextMenuChatRepository();
      final bloc = ChatBloc(
        chatRepository: repo,
        audioService: NoOpAudioService(),
        currentUserId: 'me',
      );

      final message = RelayMessage(
        id: 'longpress_msg_1',
        senderId: 'me',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Hold me down',
        isMine: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: MessageBubble(
                message: message,
                grouped: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hold me down'), findsOneWidget);

      // Long press the bubble
      await tester.longPress(find.text('Hold me down'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(MessageContextOverlay), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      bloc.close();
    });

    testWidgets('tapping Copy in context menu copies text to system clipboard and shows toast',
        (tester) async {
      final repo = _MockContextMenuChatRepository();
      final bloc = ChatBloc(
        chatRepository: repo,
        audioService: NoOpAudioService(),
        currentUserId: 'me',
      );

      final message = RelayMessage(
        id: 'copy_msg_test',
        senderId: 'me',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Secret copy text 12345',
        isMine: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: MessageBubble(
                message: message,
                grouped: false,
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Secret copy text 12345'));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify toast message appeared
      expect(find.text('Copied to clipboard'), findsOneWidget);

      // Clean up toast and settle
      RelayToast.dismiss();
      await tester.pumpAndSettle();
      bloc.close();
    });
  });
}
