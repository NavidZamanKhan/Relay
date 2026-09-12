import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/audio_service.dart';
import 'package:relay/core/widgets/relay_badge.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/message_bubble.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';
import 'package:relay/features/chats/views/group_details_page.dart';
import 'package:relay/features/chats/widgets/group_member_tile.dart';

class _FakeChatRepo implements IChatRepository {
  final List<String> calls = [];

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
  }) async => audioUrl;

  @override
  Future<String> getOrDownloadImage({
    required String chatId,
    required String messageId,
    required String imageUrl,
    String? imageData,
  }) async => imageUrl;

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
  }) async => const Conversation(
    id: 'chat_test',
    name: 'Test',
    avatarAsset: null,
    lastMessage: '',
    timeLabel: '',
  );

  @override
  Future<List<RelayContact>> matchContacts(List<String> normalizedPhoneNumbers) async => [];

  @override
  Future<List<RelayContact>> searchUsers(String query) async => [
    const RelayContact(
      id: 'user_carol',
      displayName: 'Carol',
      phoneNumber: '+15550003',
      isRegistered: true,
    ),
  ];

  @override
  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberIds,
    required String adminId,
    String? groupId,
    String? description,
    String? avatarUrl,
  }) async {
    calls.add('createGroupConversation:$name');
    return Conversation(
      id: groupId ?? 'group_123',
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
  }) async {
    calls.add('updateGroupInfo:$groupId:$name');
  }

  @override
  Future<void> promoteToAdmin({
    required String groupId,
    required String targetUserId,
  }) async {
    calls.add('promoteToAdmin:$groupId:$targetUserId');
  }

  @override
  Future<void> demoteAdmin({
    required String groupId,
    required String targetUserId,
  }) async {
    calls.add('demoteAdmin:$groupId:$targetUserId');
  }

  @override
  Future<void> addGroupMembers({
    required String groupId,
    required List<RelayContact> newMembers,
  }) async {
    calls.add('addGroupMembers:$groupId:${newMembers.length}');
  }

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String targetUserId,
  }) async {
    calls.add('removeGroupMember:$groupId:$targetUserId');
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String currentUserId,
  }) async {
    calls.add('leaveGroup:$groupId:$currentUserId');
  }

  @override
  Future<void> sendSystemMessage({
    required String groupId,
    required String text,
  }) async {
    calls.add('sendSystemMessage:$groupId:$text');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Conversation Group & Admin Domain Model Tests', () {
    test('isAdmin checks correctly based on adminIds', () {
      const conv = Conversation(
        id: 'group_test',
        name: 'Relay Devs',
        avatarAsset: null,
        lastMessage: '',
        timeLabel: 'Now',
        isGroup: true,
        participantIds: ['user_alice', 'user_bob', 'user_carol'],
        adminIds: ['user_alice'],
      );

      expect(conv.isAdmin('user_alice'), isTrue);
      expect(conv.isAdmin('user_bob'), isFalse);
      expect(conv.isAdmin('unknown'), isFalse);
      expect(conv.isAdmin(null), isFalse);
      expect(conv.memberCount, 3);
    });

    test('toMap and fromMap serialize and deserialize adminIds and description', () {
      const original = Conversation(
        id: 'group_abc',
        name: 'Relay Core',
        avatarAsset: 'assets/images/group.png',
        lastMessage: 'Hello team',
        timeLabel: '10:00',
        description: 'Official core team channel',
        isGroup: true,
        participantIds: ['u1', 'u2'],
        adminIds: ['u1'],
        participantNames: {'u1': 'Alice', 'u2': 'Bob'},
        participantAvatars: {'u1': 'avatar1.png', 'u2': 'avatar2.png'},
      );

      final map = original.toMap();
      expect(map['isGroup'], isTrue);
      expect(map['name'], 'Relay Core');
      expect(map['description'], 'Official core team channel');
      expect(map['adminIds'], ['u1']);
      expect(map['avatarUrl'], 'assets/images/group.png');

      final deserialized = Conversation.fromMap(map, 'group_abc', currentUserId: 'u1');
      expect(deserialized.id, 'group_abc');
      expect(deserialized.name, 'Relay Core');
      expect(deserialized.description, 'Official core team channel');
      expect(deserialized.adminIds, ['u1']);
      expect(deserialized.isAdmin('u1'), isTrue);
      expect(deserialized.isAdmin('u2'), isFalse);
      expect(deserialized.participantNames?['u1'], 'Alice');
      expect(deserialized.participantAvatars?['u2'], 'avatar2.png');
    });
  });

  group('ChatBloc Group Administration Tests', () {
    late _FakeChatRepo fakeRepo;

    setUp(() {
      fakeRepo = _FakeChatRepo();
    });

    test('ChatGroupCreated creates group with creator as admin', () async {
      final bloc = ChatBloc(
        chatRepository: fakeRepo,
        demoMode: false,
      );

      bloc.add(
        const ChatGroupCreated(
          'group_test1',
          'Team Alpha',
          ['user_bob'],
          adminId: 'user_alice',
          description: 'Alpha team',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final group = bloc.state.conversations
          .firstWhere((c) => c.id == 'group_test1');
      expect(group.name, 'Team Alpha');
      expect(group.description, 'Alpha team');
      expect(group.isAdmin('user_alice'), isTrue);
      expect(group.isAdmin('user_bob'), isFalse);
      expect(group.participantIds, containsAll(['user_alice', 'user_bob']));
      expect(fakeRepo.calls, contains('createGroupConversation:Team Alpha'));

      await bloc.close();
    });

    test('ChatGroupInfoUpdated updates name, description, and avatar', () async {
      final bloc = ChatBloc(
        chatRepository: fakeRepo,
        demoMode: false,
      );

      bloc.add(
        const ChatGroupCreated(
          'group_test2',
          'Initial Name',
          ['user_bob'],
          adminId: 'user_alice',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(
        const ChatGroupInfoUpdated(
          groupId: 'group_test2',
          name: 'Renamed Group',
          description: 'New Description',
          avatarUrl: 'https://example.com/avatar.png',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final group = bloc.state.conversations
          .firstWhere((c) => c.id == 'group_test2');
      expect(group.name, 'Renamed Group');
      expect(group.description, 'New Description');
      expect(group.avatarAsset, 'https://example.com/avatar.png');
      expect(fakeRepo.calls, contains('updateGroupInfo:group_test2:Renamed Group'));

      await bloc.close();
    });

    test('Promote and Demote admin updates adminIds', () async {
      final bloc = ChatBloc(
        chatRepository: fakeRepo,
        demoMode: false,
      );

      bloc.add(
        const ChatGroupCreated(
          'group_test3',
          'Guild',
          ['user_bob'],
          adminId: 'user_alice',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Promote Bob
      bloc.add(
        const ChatGroupMemberPromoted(
          groupId: 'group_test3',
          targetUserId: 'user_bob',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var group = bloc.state.conversations
          .firstWhere((c) => c.id == 'group_test3');
      expect(group.isAdmin('user_bob'), isTrue);
      expect(fakeRepo.calls, contains('promoteToAdmin:group_test3:user_bob'));

      // Demote Bob
      bloc.add(
        const ChatGroupMemberDemoted(
          groupId: 'group_test3',
          targetUserId: 'user_bob',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      group = bloc.state.conversations
          .firstWhere((c) => c.id == 'group_test3');
      expect(group.isAdmin('user_bob'), isFalse);
      expect(fakeRepo.calls, contains('demoteAdmin:group_test3:user_bob'));

      await bloc.close();
    });

    test('Add members and remove member updates participants', () async {
      final bloc = ChatBloc(
        chatRepository: fakeRepo,
        demoMode: false,
      );

      bloc.add(
        const ChatGroupCreated(
          'group_test4',
          'Tribe',
          ['user_bob'],
          adminId: 'user_alice',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Add Carol
      bloc.add(
        const ChatGroupMembersAdded(
          groupId: 'group_test4',
          newMembers: [
            RelayContact(
              id: 'user_carol',
              displayName: 'Carol',
              phoneNumber: '+15550003',
            ),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var group = bloc.state.conversations
          .firstWhere((c) => c.id == 'group_test4');
      expect(group.participantIds, contains('user_carol'));
      expect(group.participantNames?['user_carol'], 'Carol');
      expect(fakeRepo.calls, contains('addGroupMembers:group_test4:1'));

      // Remove Bob
      bloc.add(
        const ChatGroupMemberRemoved(
          groupId: 'group_test4',
          targetUserId: 'user_bob',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      group = bloc.state.conversations
          .firstWhere((c) => c.id == 'group_test4');
      expect(group.participantIds.contains('user_bob'), isFalse);
      expect(fakeRepo.calls, contains('removeGroupMember:group_test4:user_bob'));

      // Leave group
      bloc.add(
        const ChatGroupLeft(
          groupId: 'group_test4',
          currentUserId: 'user_alice',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final exists = bloc.state.conversations
          .any((c) => c.id == 'group_test4');
      expect(exists, isFalse);
      expect(fakeRepo.calls, contains('leaveGroup:group_test4:user_alice'));

      await bloc.close();
    });
  });

  group('Group Message Sender Attribution Tests', () {
    testWidgets('MessageBubble displays sender display name and author color in groups', (tester) async {
      final message = RelayMessage(
        id: 'msg_1',
        senderId: 'user_bob',
        senderName: 'Bob Vance',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Hello group members!',
        isMine: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: MessageBubble(
              message: message,
              showSenderAttribution: true,
              senderDisplayName: 'Bob Vance',
            ),
          ),
        ),
      );

      expect(find.text('Bob Vance'), findsOneWidget);
      expect(find.text('Hello group members!'), findsOneWidget);
    });
  });

  group('GroupDetailsPage & Member Tile Widget Tests', () {
    testWidgets('GroupMemberTile displays Admin badge when isAdmin is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroupMemberTile(
              userId: 'u_admin',
              displayName: 'Alice Admin',
              isAdmin: true,
              isCurrentUser: true,
              canManage: false,
            ),
          ),
        ),
      );

      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('(You)'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.byType(RelayBadge), findsOneWidget);
    });

    testWidgets('GroupDetailsPage renders group info, roster, and leave group option', (tester) async {
      final fakeRepo = _FakeChatRepo();
      final bloc = ChatBloc(
        chatRepository: fakeRepo,
        audioService: NoOpAudioService(),
        currentUserId: 'u_alice',
        demoMode: false,
      );

      bloc.emit(
        bloc.state.copyWith(
          conversations: [
            const Conversation(
              id: 'group_view_test',
              name: 'Flutter Builders',
              avatarAsset: null,
              lastMessage: 'Welcome',
              timeLabel: 'Now',
              description: 'Discussing Flutter architecture',
              isGroup: true,
              participantIds: ['u_alice', 'u_bob'],
              adminIds: ['u_alice'],
              participantNames: {'u_alice': 'Alice', 'u_bob': 'Bob'},
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<IChatRepository>.value(value: fakeRepo),
          ],
          child: BlocProvider<ChatBloc>.value(
            value: bloc,
            child: const MaterialApp(
              home: GroupDetailsPage(groupId: 'group_view_test'),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Group Info'), findsOneWidget);
      expect(find.text('Flutter Builders'), findsOneWidget);
      expect(find.text('Discussing Flutter architecture'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
      expect(find.text('Leave group'), findsOneWidget);

      bloc.close();
    });
  });
}
