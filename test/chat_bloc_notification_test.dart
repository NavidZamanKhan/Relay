import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/notification_service.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class MockNotificationChatRepository extends Fake implements IChatRepository {
  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      const Stream.empty();

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
  });
}
