import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class MockChatRepository implements IChatRepository {
  final List<RelayMessage> sentMessages = [];
  final List<({String chatId, String? replyTo, String? caption})> imageCalls = [];
  final List<({String chatId, String? replyTo})> voiceCalls = [];

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
  }) async {}

  @override
  Future<void> sendMessage({
    required String chatId,
    required RelayMessage message,
    required String recipientPublicKey,
  }) async {
    sentMessages.add(message);
  }

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
    String? messageId,
    String? replyTo,
    String? replyToId,
  }) async {
    voiceCalls.add((chatId: chatId, replyTo: replyTo));
  }

  @override
  Future<String> getOrDownloadVoiceAudio({
    required String chatId,
    required String messageId,
    required String audioUrl,
    String? audioData,
    required String peerPublicKey,
    required String nonce,
  }) async => audioUrl;

  @override
  Future<void> sendImageMessage({
    required String chatId,
    required String localFilePath,
    required String recipientPublicKey,
    String? caption,
    String? messageId,
    String? replyTo,
    String? replyToId,
  }) async {
    imageCalls.add((chatId: chatId, replyTo: replyTo, caption: caption));
  }

  @override
  Future<String> getOrDownloadImage({
    required String chatId,
    required String messageId,
    required String imageUrl,
    String? imageData,
  }) async => imageUrl;

  @override
  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String? reaction,
  }) async {}

  @override
  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberIds,
    required String adminId,
    String? description,
    String? avatarUrl,
  }) async =>
      Conversation(
        id: 'group_test',
        name: name,
        description: description,
        avatarAsset: avatarUrl,
        lastMessage: '',
        timeLabel: 'now',
        isGroup: true,
        adminIds: [adminId],
        participantIds: [adminId, ...memberIds],
      );

  @override
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? avatarUrl,
  }) async {}

  @override
  Future<void> promoteToAdmin({
    required String groupId,
    required String targetUserId,
  }) async {}

  @override
  Future<void> demoteAdmin({
    required String groupId,
    required String targetUserId,
  }) async {}

  @override
  Future<void> addGroupMembers({
    required String groupId,
    required List<RelayContact> newMembers,
  }) async {}

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String targetUserId,
  }) async {}

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String currentUserId,
  }) async {}

  void dispose() {
    conversationsController.close();
    messagesController.close();
  }
}

void main() {
  group('ChatBloc Swipe-to-Reply and Quoting', () {
    late MockChatRepository mockRepo;
    late ChatBloc bloc;

    final targetMessage = RelayMessage(
      id: 'msg_target_01',
      senderId: 'peer_user',
      sentAt: DateTime.utc(2026, 9, 10, 10, 0),
      kind: MessageKind.text,
      text: 'Are you joining the meeting?',
      delivery: DeliveryStage.read,
      isMine: false,
    );

    setUp(() {
      mockRepo = MockChatRepository();
      bloc = ChatBloc(
        chatRepository: mockRepo,
        currentUserId: 'me_user',
        demoMode: false,
      );
    });

    tearDown(() {
      bloc.close();
      mockRepo.dispose();
    });

    test('ChatReplyTargetSet updates and clears replyingTo in state', () async {
      expect(bloc.state.replyingTo, isNull);

      bloc.add(ChatReplyTargetSet(targetMessage));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.replyingTo, equals(targetMessage));

      bloc.add(const ChatReplyTargetSet(null));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.replyingTo, isNull);
    });

    test('ChatTextSent includes quoted snippet and clears replyingTo', () async {
      bloc.add(ChatReplyTargetSet(targetMessage));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(const ChatComposerChanged('Yes, I will be there shortly'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(const ChatTextSent());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(mockRepo.sentMessages, isNotEmpty);
      final sent = mockRepo.sentMessages.first;
      expect(sent.text, 'Yes, I will be there shortly');
      expect(sent.replyTo, 'Are you joining the meeting?');
      expect(bloc.state.replyingTo, isNull);
    });

    test('ChatImagePicked includes quoted snippet and clears replyingTo', () async {
      bloc.add(ChatReplyTargetSet(targetMessage));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(const ChatImagePicked('/dummy/path.jpg', caption: 'Road preview'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(mockRepo.imageCalls, isNotEmpty);
      final call = mockRepo.imageCalls.first;
      expect(call.replyTo, 'Are you joining the meeting?');
      expect(call.caption, 'Road preview');
      expect(bloc.state.replyingTo, isNull);
    });

    test('ChatOpened resets active replyingTo target', () async {
      bloc.add(ChatReplyTargetSet(targetMessage));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.replyingTo, equals(targetMessage));

      bloc.add(const ChatOpened('other_chat_id'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.replyingTo, isNull);
    });
  });
}
