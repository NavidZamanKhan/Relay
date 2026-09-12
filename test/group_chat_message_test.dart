import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class _FakeGroupChatRepository implements IChatRepository {
  final List<String> calls = [];
  String? capturedGroupId;
  String? capturedChatId;
  RelayMessage? capturedMessage;

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
  Future<void> sendMessage({
    required String chatId,
    required RelayMessage message,
    required String recipientPublicKey,
  }) async {
    calls.add('sendMessage:$chatId');
    capturedChatId = chatId;
    capturedMessage = message;
  }

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
  }) async {}

  @override
  Future<void> sendImageMessage({
    required String chatId,
    required String localFilePath,
    required String recipientPublicKey,
    String? caption,
    String? messageId,
    String? replyTo,
    String? replyToId,
  }) async {}

  @override
  Future<String> getOrDownloadVoiceAudio({
    required String chatId,
    required String messageId,
    required String audioUrl,
    String? audioData,
    required String peerPublicKey,
    required String nonce,
  }) async =>
      audioUrl;

  @override
  Future<String> getOrDownloadImage({
    required String chatId,
    required String messageId,
    required String imageUrl,
    String? imageData,
  }) async =>
      imageUrl;

  @override
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
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
  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String? reaction,
  }) async {}

  @override
  Future<Conversation> getOrCreateDirectConversation({
    required String currentUserId,
    required String recipientUserId,
    required String recipientName,
    String? recipientPublicKey,
  }) async =>
      const Conversation(
        id: 'chat_test',
        name: 'Direct Test',
        avatarAsset: null,
        lastMessage: '',
        timeLabel: '',
      );

  @override
  Future<List<RelayContact>> matchContacts(
    List<String> normalizedPhoneNumbers,
  ) async =>
      [];

  @override
  Future<List<RelayContact>> searchUsers(String query) async => [];

  @override
  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberIds,
    required String adminId,
    String? groupId,
    String? description,
    String? avatarUrl,
  }) async {
    capturedGroupId = groupId;
    calls.add('createGroupConversation:${groupId ?? name}');
    return Conversation(
      id: groupId ?? 'group_test_fallback',
      name: name,
      description: description,
      avatarAsset: avatarUrl,
      lastMessage: 'Group created',
      timeLabel: 'Now',
      isGroup: true,
      adminIds: [adminId],
      participantIds: [adminId, ...memberIds],
    );
  }

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

  @override
  Future<void> sendSystemMessage({
    required String groupId,
    required String text,
  }) async {}

  @override
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {}

  @override
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {}

  @override
  Future<void> clearChat({
    required String chatId,
    required String userId,
  }) async {}

  Future<void> cleanup() async {
    await _messagesController.close();
  }
}

void main() {
  group('Group Chat Message Delivery and Retention Tests', () {
    late _FakeGroupChatRepository fakeRepo;
    late ChatBloc bloc;

    setUp(() {
      fakeRepo = _FakeGroupChatRepository();
      bloc = ChatBloc(
        chatRepository: fakeRepo,
        currentUserId: 'user_alice',
        demoMode: false,
      );
    });

    tearDown(() async {
      await bloc.close();
      await fakeRepo.cleanup();
    });

    test('ChatGroupCreated passes client generated groupId to repository', () async {
      const customGroupId = 'group_1726000000000';
      bloc.add(
        const ChatGroupCreated(
          customGroupId,
          'Test Group',
          ['user_bob', 'user_carol'],
          adminId: 'user_alice',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeRepo.capturedGroupId, equals(customGroupId));
      expect(fakeRepo.calls, contains('createGroupConversation:$customGroupId'));
    });

    test('Group message send dispatches to repository with matching group ID', () async {
      const groupId = 'group_project_sync';
      bloc.add(
        const ChatGroupCreated(
          groupId,
          'Project Sync',
          ['user_bob', 'user_carol'],
          adminId: 'user_alice',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const ChatOpened(groupId));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const ChatComposerChanged('Hello team'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(const ChatTextSent());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeRepo.capturedChatId, equals(groupId));
      expect(fakeRepo.capturedMessage?.text, equals('Hello team'));
      expect(fakeRepo.capturedMessage?.isMine, isTrue);

      final currentMessages = bloc.state.threads[groupId];
      expect(currentMessages, isNotNull);
      expect(currentMessages!.any((m) => m.text == 'Hello team'), isTrue);
    });

    test('Incoming stream update does not delete local pending messages in group', () async {
      const groupId = 'group_dev_ops';
      bloc.add(
        const ChatGroupCreated(
          groupId,
          'Dev Ops',
          ['user_bob'],
          adminId: 'user_alice',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const ChatOpened(groupId));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const ChatComposerChanged('Pending deployment notice'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(const ChatTextSent());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pendingMsg = bloc.state.threads[groupId]?.firstWhere(
        (m) => m.text == 'Pending deployment notice',
      );
      expect(pendingMsg, isNotNull);

      // Simulate remote stream snapshot containing a message from Bob
      final remoteMsg = RelayMessage(
        id: 'remote_msg_1',
        senderId: 'user_bob',
        recipientId: groupId,
        sentAt: DateTime.now(),
        text: 'Acknowledged',
        delivery: DeliveryStage.sent,
        isMine: false,
        kind: MessageKind.text,
      );
      fakeRepo.emitMessages([remoteMsg]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updatedMessages = bloc.state.threads[groupId];
      expect(updatedMessages, isNotNull);
      // Both the incoming remote message and the pending sending message must be retained
      expect(updatedMessages!.any((m) => m.id == 'remote_msg_1'), isTrue);
      expect(updatedMessages.any((m) => m.text == 'Pending deployment notice'), isTrue);
    });
  });
}
