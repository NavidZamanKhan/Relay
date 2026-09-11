import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/audio_service.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/message_bubble.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class _MockLocateChatRepository implements IChatRepository {
  final sentMessages = <RelayMessage>[];

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
  }) async {
    sentMessages.add(message);
  }
}

void main() {
  group('RelayMessage replyToId Serialization & Deserialization', () {
    test('serializes and deserializes replyToId cleanly', () {
      final message = RelayMessage(
        id: 'msg_100',
        senderId: 'user_a',
        sentAt: DateTime.utc(2026, 9, 11, 10, 0),
        kind: MessageKind.text,
        text: 'This is a reply',
        replyTo: 'Hello original',
        replyToId: 'msg_050',
      );

      final map = message.toMap();
      expect(map['replyTo'], 'Hello original');
      expect(map['replyToId'], 'msg_050');

      final deserialized = RelayMessage.fromMap(map, 'msg_100');
      expect(deserialized.replyTo, 'Hello original');
      expect(deserialized.replyToId, 'msg_050');
    });

    test('copyWith preserves or overrides replyToId', () {
      final original = RelayMessage(
        id: 'msg_1',
        senderId: 'user_a',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        replyToId: 'target_1',
      );

      final copySame = original.copyWith(text: 'Updated text');
      expect(copySame.replyToId, 'target_1');

      final copyOverridden = original.copyWith(replyToId: 'target_2');
      expect(copyOverridden.replyToId, 'target_2');
    });
  });

  group('ChatBloc Touch-to-Locate and Highlight Engine', () {
    late ChatBloc chatBloc;
    late _MockLocateChatRepository mockRepo;

    setUp(() {
      mockRepo = _MockLocateChatRepository();
      chatBloc = ChatBloc(
        chatRepository: mockRepo,
        audioService: NoOpAudioService(),
        currentUserId: 'user_me',
      );
    });

    tearDown(() {
      chatBloc.close();
    });

    test('ChatLocateMessageRequested sets highlightedMessageId and auto-clears', () async {
      expect(chatBloc.state.highlightedMessageId, isNull);

      chatBloc.add(const ChatLocateMessageRequested('msg_target_77'));
      await pumpEventQueue();

      expect(chatBloc.state.highlightedMessageId, 'msg_target_77');

      // Emitting clear directly
      chatBloc.add(const ChatHighlightCleared());
      await pumpEventQueue();

      expect(chatBloc.state.highlightedMessageId, isNull);
    });

    test('ChatTextSent quotes message and attaches replyToId', () async {
      final quotedTarget = RelayMessage(
        id: 'original_msg_123',
        senderId: 'peer_user',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Initial question',
      );

      chatBloc.add(ChatReplyTargetSet(quotedTarget));
      chatBloc.add(const ChatComposerChanged('My response'));
      chatBloc.add(const ChatTextSent());
      await pumpEventQueue();

      expect(mockRepo.sentMessages.isNotEmpty, isTrue);
      final sent = mockRepo.sentMessages.first;
      expect(sent.text, 'My response');
      expect(sent.replyTo, 'Initial question');
      expect(sent.replyToId, 'original_msg_123');
      expect(chatBloc.state.replyingTo, isNull);
    });
  });

  group('Interactive Quoted Reply Widget Tests', () {
    testWidgets('tapping _ReplyPreview navigates to target message via ChatLocateMessageRequested',
        (tester) async {
      final mockRepo = _MockLocateChatRepository();
      final chatBloc = ChatBloc(
        chatRepository: mockRepo,
        audioService: NoOpAudioService(),
        currentUserId: 'me',
      );

      final replyMessage = RelayMessage(
        id: 'reply_msg_1',
        senderId: 'me',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'I agree with this',
        replyTo: 'Hello there',
        replyToId: 'target_msg_42',
        isMine: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: chatBloc,
              child: MessageBubble(
                message: replyMessage,
                grouped: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Hello there'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.chevron_right), findsOneWidget);

      await tester.tap(find.text('Hello there'));
      await tester.pump(const Duration(milliseconds: 350));
      await null;
      await tester.pump();

      expect(chatBloc.state.highlightedMessageId, 'target_msg_42');

      chatBloc.close();
    });

    testWidgets('tapping _ReplyPreview without replyToId resolves matching message in thread',
        (tester) async {
      final mockRepo = _MockLocateChatRepository();
      final chatBloc = ChatBloc(
        chatRepository: mockRepo,
        audioService: NoOpAudioService(),
        currentUserId: 'me',
      );

      // Prepopulate thread in chatBloc
      final originalTarget = RelayMessage(
        id: 'legacy_matched_id_99',
        senderId: 'peer',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Legacy original message',
      );

      final replyMessage = RelayMessage(
        id: 'reply_msg_2',
        senderId: 'me',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Replying to legacy',
        replyTo: 'Legacy original message',
        replyToId: null, // Legacy message with missing ID
        isMine: true,
      );

      chatBloc.emit(chatBloc.state.copyWith(
        threads: {
          chatBloc.state.activeId: [originalTarget, replyMessage],
        },
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: chatBloc,
              child: MessageBubble(
                message: replyMessage,
                grouped: false,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Legacy original message'));
      await tester.pump(const Duration(milliseconds: 350));
      await null;
      await tester.pump();

      expect(chatBloc.state.highlightedMessageId, 'legacy_matched_id_99');

      chatBloc.close();
    });

    testWidgets('MessageBubble renders highlight animation when isHighlighted is true',
        (tester) async {
      final message = RelayMessage(
        id: 'highlight_test_msg',
        senderId: 'peer',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Look at me',
        isMine: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              grouped: false,
              isHighlighted: true,
            ),
          ),
        ),
      );

      // Step the animation controller forward
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
