import '../models/conversation.dart';
import '../models/delivery_stage.dart';
import '../models/relay_contact.dart';
import '../models/relay_message.dart';

/// Contract for real-time conversation streaming, message transport,
/// client-side encryption dispatch, and contact matching.
abstract interface class IChatRepository {
  /// Streams real-time conversations involving [currentUserId],
  /// ordered by most recent activity with offline-first persistence.
  Stream<List<Conversation>> watchConversations(String currentUserId);

  /// Streams the chronological message timeline for [chatId].
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId);

  /// Dispatches an end-to-end encrypted message into [chatId].
  Future<void> sendMessage({
    required String chatId,
    required RelayMessage message,
    required String recipientPublicKey,
  });

  /// Transitions the delivery lifecycle for a message (sent, delivered, read).
  Future<void> updateDeliveryStatus({
    required String chatId,
    required String messageId,
    required DeliveryStage status,
  });

  /// Acknowledges delivery of unread messages in [chatId] for [recipientUserId].
  Future<void> markConversationDelivered({
    required String chatId,
    required String recipientUserId,
  });

  /// Marks unread messages in [chatId] as read for [readerUserId] and resets unread count.
  Future<void> markConversationRead({
    required String chatId,
    required String readerUserId,
  });

  /// Updates typing presence indicator in [chatId].
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  });

  /// Retrieves an existing direct conversation or initializes a new thread.
  Future<Conversation> getOrCreateDirectConversation({
    required String currentUserId,
    required String recipientUserId,
    required String recipientName,
    String? recipientPublicKey,
  });

  /// Discovers registered Relay users among local device phone numbers.
  Future<List<RelayContact>> matchContacts(List<String> normalizedPhoneNumbers);

  /// Searches registered users by name or phone query.
  Future<List<RelayContact>> searchUsers(String query);
}
