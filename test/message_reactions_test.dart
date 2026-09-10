import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class _ReactionTestRepository extends Fake implements IChatRepository {
  final List<({String chatId, String messageId, String userId, String? reaction})>
      reactionCalls = [];

  final StreamController<List<Conversation>> _convs =
      StreamController<List<Conversation>>.broadcast();
  final StreamController<List<RelayMessage>> _msgs =
      StreamController<List<RelayMessage>>.broadcast();

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) => _convs.stream;

  @override
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId) => _msgs.stream;

  @override
  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String? reaction,
  }) async {
    reactionCalls.add((
      chatId: chatId,
      messageId: messageId,
      userId: userId,
      reaction: reaction,
    ));
  }
}

void main() {
  group('Message Reactions Engine', () {
    late _ReactionTestRepository repository;

    setUp(() {
      repository = _ReactionTestRepository();
    });

    test('ChatMessageReactionToggled adds, toggles, and updates reactions correctly', () async {
      final bloc = ChatBloc(
        chatRepository: repository,
        currentUserId: 'user_navid',
        demoMode: false,
      );

      final initialMessage = RelayMessage(
        id: 'msg_react_101',
        senderId: 'user_sadman',
        recipientId: 'user_navid',
        sentAt: DateTime.utc(2026, 9, 10, 10, 0),
        kind: MessageKind.text,
        text: 'Let us grab coffee today',
      );

      bloc.emit(bloc.state.copyWith(
        activeId: 'chat_navid_sadman',
        threads: {
          'chat_navid_sadman': [initialMessage],
        },
      ));

      // 1. Add reaction 'thumbs up'
      bloc.add(const ChatMessageReactionToggled(
        'chat_navid_sadman',
        'msg_react_101',
        '\u{1F44D}',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      var thread = bloc.state.threads['chat_navid_sadman'];
      expect(thread, isNotNull);
      expect(thread!.first.reactions, isNotNull);
      expect(thread.first.reactions!['user_navid'], '\u{1F44D}');
      expect(repository.reactionCalls.length, 1);
      expect(repository.reactionCalls.last.reaction, '\u{1F44D}');

      // 2. Tap the same reaction again to toggle off
      bloc.add(const ChatMessageReactionToggled(
        'chat_navid_sadman',
        'msg_react_101',
        '\u{1F44D}',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      thread = bloc.state.threads['chat_navid_sadman'];
      expect(thread!.first.reactions!['user_navid'], isNull);
      expect(repository.reactionCalls.length, 2);
      expect(repository.reactionCalls.last.reaction, isNull);

      // 3. Add a different reaction 'heart'
      bloc.add(const ChatMessageReactionToggled(
        'chat_navid_sadman',
        'msg_react_101',
        '\u{2764}\u{FE0F}',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      thread = bloc.state.threads['chat_navid_sadman'];
      expect(thread!.first.reactions!['user_navid'], '\u{2764}\u{FE0F}');
      expect(repository.reactionCalls.length, 3);
      expect(repository.reactionCalls.last.reaction, '\u{2764}\u{FE0F}');

      await bloc.close();
    });

    test('RelayMessage reactions serialize and deserialize accurately in document schema', () {
      final msg = RelayMessage(
        id: 'msg_schema_test',
        senderId: 'user_a',
        sentAt: DateTime.utc(2026, 9, 10, 11, 0),
        kind: MessageKind.text,
        text: 'React to this',
        reactions: const {
          'user_a': '\u{1F44D}',
          'user_b': '\u{2764}\u{FE0F}',
        },
      );

      final map = msg.toMap();
      expect(map['reactions'], isA<Map<String, String>>());
      expect(map['reactions']['user_a'], '\u{1F44D}');
      expect(map['reactions']['user_b'], '\u{2764}\u{FE0F}');

      final parsed = RelayMessage.fromMap(map, 'msg_schema_test');
      expect(parsed.reactions, isNotNull);
      expect(parsed.reactions!['user_a'], '\u{1F44D}');
      expect(parsed.reactions!['user_b'], '\u{2764}\u{FE0F}');
    });
  });
}
