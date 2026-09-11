import 'package:equatable/equatable.dart';

import 'relay_message.dart';

/// Represents a queued outgoing message waiting to be synchronized to Firestore
/// when network connectivity is restored.
class OutboxItem extends Equatable {
  const OutboxItem({
    required this.chatId,
    required this.message,
    required this.recipientPublicKey,
    this.attempts = 0,
    required this.queuedAt,
    this.lastAttemptAt,
  });

  final String chatId;
  final RelayMessage message;
  final String recipientPublicKey;
  final int attempts;
  final DateTime queuedAt;
  final DateTime? lastAttemptAt;

  OutboxItem copyWith({
    String? chatId,
    RelayMessage? message,
    String? recipientPublicKey,
    int? attempts,
    DateTime? queuedAt,
    DateTime? lastAttemptAt,
  }) =>
      OutboxItem(
        chatId: chatId ?? this.chatId,
        message: message ?? this.message,
        recipientPublicKey: recipientPublicKey ?? this.recipientPublicKey,
        attempts: attempts ?? this.attempts,
        queuedAt: queuedAt ?? this.queuedAt,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      );

  @override
  List<Object?> get props => [
        chatId,
        message.id,
        recipientPublicKey,
        attempts,
        queuedAt,
        lastAttemptAt,
      ];
}
