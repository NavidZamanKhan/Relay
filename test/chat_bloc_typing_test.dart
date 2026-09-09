import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class MockChatRepository implements IChatRepository {
  final List<({String chatId, String userId, bool isTyping})> typingCalls = [];
  final StreamController<List<Conversation>> conversationsController =
      StreamController<List<Conversation>>.broadcast();
  final StreamController<List<RelayMessage>> messagesController =
      StreamController<List<RelayMessage>>.broadcast();

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      conversationsController.stream;

  @override
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId) =>
      messagesController.stream;

  @override
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    typingCalls.add((chatId: chatId, userId: userId, isTyping: isTyping));
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required RelayMessage message,
    required String recipientPublicKey,
  }) async {}

  @override
  Future<void> updateDeliveryStatus({
    required String chatId,
    required String messageId,
    required DeliveryStage status,
  }) async {}

  @override
  Future<void> markConversationDelivered({
    required String chatId,
    required String recipientUserId,
  }) async {}

  @override
  Future<void> markConversationRead({
    required String chatId,
    required String readerUserId,
  }) async {}

  @override
  Future<Conversation> getOrCreateDirectConversation({
    required String currentUserId,
    required String recipientUserId,
    required String recipientName,
    String? recipientPublicKey,
  }) async {
    return const Conversation(
      id: 'chat_test',
      name: 'Test Peer',
      avatarAsset: null,
      lastMessage: '',
      timeLabel: 'now',
    );
  }

  @override
  Future<List<RelayContact>> matchContacts(List<String> normalizedPhoneNumbers) async => [];

  @override
  Future<List<RelayContact>> searchUsers(String query) async => [];

  @override
  Future<void> sendVoiceMessage({
    required String chatId,
    required String localFilePath,
    required Duration duration,
    required List<double> waveform,
    required String recipientPublicKey,
    String? replyTo,
  }) async {}

  @override
  Future<String> getOrDownloadVoiceAudio({
    required String chatId,
    required String messageId,
    required String audioUrl,
    required String peerPublicKey,
    required String nonce,
  }) async => audioUrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatBloc Real-Time Typing Indicator Engine', () {
    late MockChatRepository mockRepo;
    late ChatBloc bloc;
    const currentUserId = 'user_alice';
    const testChatId = 'chat_alice_bob';

    setUp(() {
      mockRepo = MockChatRepository();
      bloc = ChatBloc(
        chatRepository: mockRepo,
        currentUserId: currentUserId,
        demoMode: false,
      );
    });

    tearDown(() async {
      await bloc.close();
      await mockRepo.conversationsController.close();
      await mockRepo.messagesController.close();
    });

    test('ChatComposerChanged triggers setTypingStatus true and debounces to false', () async {
      bloc.add(const ChatOpened(testChatId));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const ChatComposerChanged('H'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(mockRepo.typingCalls.length, equals(1));
      expect(mockRepo.typingCalls.first.chatId, equals(testChatId));
      expect(mockRepo.typingCalls.first.userId, equals(currentUserId));
      expect(mockRepo.typingCalls.first.isTyping, isTrue);

      // Typing more does not send redundant true calls
      bloc.add(const ChatComposerChanged('Hey there'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.typingCalls.length, equals(1));

      // Wait for debounce timer (1500ms) to fire
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(mockRepo.typingCalls.length, equals(2));
      expect(mockRepo.typingCalls.last.isTyping, isFalse);
    });

    test('clearing composer immediately triggers setTypingStatus false', () async {
      bloc.add(const ChatOpened(testChatId));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const ChatComposerChanged('Typing a draft'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.typingCalls.last.isTyping, isTrue);

      bloc.add(const ChatComposerChanged(''));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.typingCalls.last.isTyping, isFalse);
    });

    test('ChatTextSent immediately clears typing status and cancels debounce', () async {
      bloc.add(const ChatOpened(testChatId));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const ChatComposerChanged('Ready to send'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.typingCalls.last.isTyping, isTrue);

      bloc.add(const ChatTextSent());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.typingCalls.last.isTyping, isFalse);

      // Verify no extra false calls happen after the 1500ms debounce
      final callCount = mockRepo.typingCalls.length;
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(mockRepo.typingCalls.length, equals(callCount));
    });

    test('peer typing status in incoming conversation updates state.typingIds and state.typing', () async {
      bloc.add(const ChatStreamStarted(currentUserId));
      bloc.add(const ChatOpened(testChatId));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.typing, isFalse);

      const convWithPeerTyping = Conversation(
        id: testChatId,
        name: 'Bob',
        avatarAsset: null,
        lastMessage: 'Hey',
        timeLabel: 'now',
        recipientId: 'user_bob',
        isPeerTyping: true,
      );

      mockRepo.conversationsController.add([convWithPeerTyping]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.typingIds.contains(testChatId), isTrue);
      expect(bloc.state.typing, isTrue);

      const convPeerStoppedTyping = Conversation(
        id: testChatId,
        name: 'Bob',
        avatarAsset: null,
        lastMessage: 'Hey',
        timeLabel: 'now',
        recipientId: 'user_bob',
        isPeerTyping: false,
      );

      mockRepo.conversationsController.add([convPeerStoppedTyping]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.typingIds.contains(testChatId), isFalse);
      expect(bloc.state.typing, isFalse);
    });
  });
}
