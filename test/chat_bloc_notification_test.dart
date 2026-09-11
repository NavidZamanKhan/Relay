import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/notification_service.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

import 'dart:async';

class MockNotificationChatRepository extends Fake implements IChatRepository {
  final convsController = StreamController<List<Conversation>>.broadcast();

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      convsController.stream;

  @override
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId) =>
      const Stream.empty();

  @override
  Future<void> markConversationRead({
    required String chatId,
    required String readerUserId,
  }) async {}

  @override
  Future<void> markConversationDelivered({
    required String chatId,
    required String recipientUserId,
  }) async {}
}

void main() {
  group('ChatBloc Incoming Notification Tests', () {
    late IChatRepository chatRepo;
    late MockNotificationService notificationService;

    setUp(() {
      chatRepo = MockNotificationChatRepository();
      notificationService = MockNotificationService();
    });

    tearDown(() {
      notificationService.dispose();
    });

    test('emits incomingNotification when a new message arrives from another chat', () async {
      final chatBloc = ChatBloc(
        chatRepository: chatRepo,
        currentUserId: 'me',
        notificationService: notificationService,
        demoMode: true,
      );

      // User is currently viewing 'aisha' thread
      chatBloc.emit(
        chatBloc.state.copyWith(
          activeId: 'aisha',
          threads: {
            'aisha': [],
            'rahim': [],
          },
        ),
      );

      expect(chatBloc.state.incomingNotification, isNull);

      // An incoming message arrives in 'rahim' thread
      final incomingMessage = RelayMessage(
        id: 'msg_rahim_1',
        senderId: 'rahim',
        recipientId: 'me',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Are we meeting at Dhanmondi?',
      );

      chatBloc.add(
        ChatNotificationReceived(
          NotificationPayload(
            id: incomingMessage.id,
            chatId: 'rahim',
            title: 'Rahim',
            body: incomingMessage.text!,
            timestamp: incomingMessage.sentAt,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(chatBloc.state.incomingNotification, isNotNull);
      expect(chatBloc.state.incomingNotification?.chatId, 'rahim');
      expect(
        chatBloc.state.incomingNotification?.body,
        'Are we meeting at Dhanmondi?',
      );

      // Clear the notification
      chatBloc.add(const ChatIncomingNotificationCleared());
      await Future<void>.delayed(Duration.zero);
      expect(chatBloc.state.incomingNotification, isNull);

      await chatBloc.close();
    });

    test('notification tap triggers ChatOpened in ChatBloc', () async {
      final chatBloc = ChatBloc(
        chatRepository: chatRepo,
        currentUserId: 'me',
        notificationService: notificationService,
        demoMode: true,
      );

      expect(chatBloc.state.activeId, 'aisha');

      // Simulate tapping a notification for 'marina'
      notificationService.simulateNotificationTapped(
        NotificationPayload(
          id: 'notif_tap_99',
          chatId: 'marina',
          title: 'Marina',
          body: 'Check the design preview',
          timestamp: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(chatBloc.state.activeId, Conversation.directChatId('me', 'marina'));

      await chatBloc.close();
    });

    test('ChatConversationsUpdated triggers incomingNotification when incoming message arrives', () async {
      final chatBloc = ChatBloc(
        chatRepository: chatRepo,
        currentUserId: 'user_sadman',
        notificationService: notificationService,
        demoMode: false,
      );

      final initialConv = Conversation(
        id: 'chat_navid_sadman',
        name: 'Navid',
        avatarAsset: null,
        lastMessage: 'Hello',
        timeLabel: '04:26',
        lastMessageAt: DateTime(2026, 9, 12, 4, 26),
        lastMessageSenderId: 'user_navid',
        unread: 0,
      );

      chatBloc.add(const ChatStreamStarted('user_sadman'));
      await Future<void>.delayed(Duration.zero);

      chatBloc.emit(
        chatBloc.state.copyWith(
          conversations: [initialConv],
          activeId: '', // Viewing inbox, not in this chat
        ),
      );

      expect(chatBloc.state.incomingNotification, isNull);

      // Navid sends a new message "What is your problem?"
      final updatedConv = initialConv.copyWith(
        lastMessage: 'What is your problem?',
        timeLabel: '04:34',
        lastMessageAt: DateTime(2026, 9, 12, 4, 34),
        lastMessageSenderId: 'user_navid',
        unread: 0, // Unread might still be 0 if not incremented, but sender is peer
      );

      (chatRepo as MockNotificationChatRepository).convsController.add([updatedConv]);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(chatBloc.state.incomingNotification, isNotNull);
      expect(chatBloc.state.incomingNotification?.title, 'Navid');
      expect(chatBloc.state.incomingNotification?.body, 'What is your problem?');

      await chatBloc.close();
    });
  });
}
