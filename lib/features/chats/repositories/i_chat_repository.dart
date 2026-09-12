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

  /// Uploads an end-to-end encrypted push-to-talk voice note to Cloud Storage
  /// and writes the message document with 32-bar waveform metadata.
  Future<void> sendVoiceMessage({
    required String chatId,
    required String localFilePath,
    required Duration duration,
    required List<double> waveform,
    required String recipientPublicKey,
    String? messageId,
    String? replyTo,
    String? replyToId,
  });

  /// Resolves the local playback file for a voice message, downloading
  /// and decrypting the Cloud Storage ciphertext if not already cached.
  Future<String> getOrDownloadVoiceAudio({
    required String chatId,
    required String messageId,
    required String audioUrl,
    String? audioData,
    required String peerPublicKey,
    required String nonce,
  });

  /// Uploads a locally compressed image to Cloud Storage (with resilient inline
  /// fallback) and writes the image message document into Firestore.
  Future<void> sendImageMessage({
    required String chatId,
    required String localFilePath,
    required String recipientPublicKey,
    String? caption,
    String? messageId,
    String? replyTo,
    String? replyToId,
  });

  /// Resolves the local image file for an image message, downloading from
  /// Cloud Storage (or decoding inline data) if not already cached.
  Future<String> getOrDownloadImage({
    required String chatId,
    required String messageId,
    required String imageUrl,
    String? imageData,
  });

  /// Sets or removes an emoji reaction on a message in [chatId].
  /// If [reaction] is null, removes the user's reaction.
  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String? reaction,
  });

  /// Creates a group conversation in Firestore with [adminId] as initial admin.
  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> memberIds,
    required String adminId,
    String? groupId,
    String? description,
    String? avatarUrl,
  });

  /// Updates group metadata (title, description, avatar).
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? avatarUrl,
  });

  /// Promotes [targetUserId] to an admin in [groupId].
  Future<void> promoteToAdmin({
    required String groupId,
    required String targetUserId,
  });

  /// Demotes [targetUserId] from admin status in [groupId].
  Future<void> demoteAdmin({
    required String groupId,
    required String targetUserId,
  });

  /// Adds [newMembers] to [groupId].
  Future<void> addGroupMembers({
    required String groupId,
    required List<RelayContact> newMembers,
  });

  /// Removes [targetUserId] from [groupId].
  Future<void> removeGroupMember({
    required String groupId,
    required String targetUserId,
  });

  /// Allows [currentUserId] to leave [groupId], auto-promoting another member if last admin.
  Future<void> leaveGroup({
    required String groupId,
    required String currentUserId,
  });

  /// Dispatches an in-chat system event message to [groupId].
  Future<void> sendSystemMessage({
    required String groupId,
    required String text,
  });

  /// Deletes a message for the current user ("delete for me").
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String userId,
  });

  /// Deletes a message for all conversation participants ("delete for everyone").
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String userId,
  });

  /// Clears all messages in [chatId] for [userId] and hides the conversation.
  Future<void> clearChat({
    required String chatId,
    required String userId,
  });
}
