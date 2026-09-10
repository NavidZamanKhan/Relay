import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/message_bubble.dart';
import 'package:relay/features/chats/message_composer.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class _FakeChatRepository extends Fake implements IChatRepository {
  @override
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId) =>
      const Stream.empty();

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      const Stream.empty();
}

void main() {
  testWidgets('MessageComposer renders reply bar correctly with peer name and dismisses', (
    tester,
  ) async {
    final bloc = ChatBloc(
      chatRepository: _FakeChatRepository(),
      currentUserId: 'me_user',
      demoMode: true,
    );
    addTearDown(bloc.close);

    final replyingMessage = RelayMessage(
      id: 'msg_target_01',
      senderId: 'peer_user',
      sentAt: DateTime.utc(2026, 9, 10, 10, 0),
      kind: MessageKind.text,
      text: 'Where do you wanna go?',
      delivery: DeliveryStage.read,
      isMine: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ChatBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MessageComposer(contactName: 'Sadman'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Set replyingTo in ChatBloc
    bloc.add(ChatReplyTargetSet(replyingMessage));
    await tester.pumpAndSettle();

    // Verify reply bar texts and icons
    expect(find.text('Replying to Sadman'), findsOneWidget);
    expect(find.text('Where do you wanna go?'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.reply), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);

    // Tap dismiss
    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await tester.pumpAndSettle();

    expect(find.text('Replying to Sadman'), findsNothing);
    expect(bloc.state.replyingTo, isNull);
  });

  testWidgets('MessageComposer renders reply bar for self messages', (
    tester,
  ) async {
    final bloc = ChatBloc(
      chatRepository: _FakeChatRepository(),
      currentUserId: 'me_user',
      demoMode: true,
    );
    addTearDown(bloc.close);

    final selfMessage = RelayMessage(
      id: 'msg_self_01',
      senderId: 'me_user',
      sentAt: DateTime.utc(2026, 9, 10, 10, 5),
      kind: MessageKind.image,
      text: 'Scenic waterfall',
      delivery: DeliveryStage.read,
      isMine: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ChatBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MessageComposer(contactName: 'Sadman'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    bloc.add(ChatReplyTargetSet(selfMessage));
    await tester.pumpAndSettle();

    expect(find.text('Replying to yourself'), findsOneWidget);
    expect(find.text('Scenic waterfall'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.photo), findsOneWidget);
  });

  testWidgets('MessageComposer renders reply bar for voice note with mic icon', (
    tester,
  ) async {
    final bloc = ChatBloc(
      chatRepository: _FakeChatRepository(),
      currentUserId: 'me_user',
      demoMode: true,
    );
    addTearDown(bloc.close);

    final voiceMessage = RelayMessage(
      id: 'msg_voice_01',
      senderId: 'peer_user',
      sentAt: DateTime.utc(2026, 9, 10, 10, 8),
      kind: MessageKind.voice,
      delivery: DeliveryStage.read,
      isMine: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ChatBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MessageComposer(contactName: 'Sadman'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    bloc.add(ChatReplyTargetSet(voiceMessage));
    await tester.pumpAndSettle();

    expect(find.text('Replying to Sadman'), findsOneWidget);
    expect(find.text('Voice note'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == CupertinoIcons.mic && w.size == 13,
      ),
      findsOneWidget,
    );
  });

  testWidgets('MessageBubble renders reply preview snippet cleanly', (
    tester,
  ) async {
    final messageWithReply = RelayMessage(
      id: 'msg_with_reply_01',
      senderId: 'me_user',
      sentAt: DateTime.utc(2026, 9, 10, 10, 12),
      kind: MessageKind.text,
      text: 'I am on my way!',
      replyTo: 'Where do you wanna go?',
      delivery: DeliveryStage.delivered,
      isMine: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: messageWithReply,
            grouped: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Where do you wanna go?'), findsOneWidget);
    expect(find.text('I am on my way!'), findsOneWidget);
  });
}
