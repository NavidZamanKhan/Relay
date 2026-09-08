import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import 'delivery_stage.dart';
import 'message_kind.dart';

/// Immutable domain model representing a conversation thread in Relay.
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.name,
    required this.avatarAsset,
    required this.lastMessage,
    required this.timeLabel,
    this.lastMessageAt,
    this.participantIds = const [],
    this.recipientId,
    this.recipientPublicKey,
    this.participantNames,
    this.online = false,
    this.unread = 0,
    this.previewKind = MessageKind.text,
    this.delivery,
    this.pinned = false,
    this.isGroup = false,
    this.muted = false,
  });

  final String id;
  final String name;
  final String? avatarAsset;
  final String lastMessage;
  final String timeLabel;
  final DateTime? lastMessageAt;
  final List<String> participantIds;
  final String? recipientId;
  final String? recipientPublicKey;
  final Map<String, String>? participantNames;
  final bool online;
  final int unread;
  final MessageKind previewKind;
  final DeliveryStage? delivery;
  final bool pinned;
  final bool isGroup;
  final bool muted;

  Conversation copyWith({
    String? id,
    String? name,
    String? avatarAsset,
    String? lastMessage,
    String? timeLabel,
    DateTime? lastMessageAt,
    List<String>? participantIds,
    String? recipientId,
    String? recipientPublicKey,
    Map<String, String>? participantNames,
    bool? online,
    int? unread,
    MessageKind? previewKind,
    DeliveryStage? delivery,
    bool? pinned,
    bool? isGroup,
    bool? muted,
    bool clearDelivery = false,
  }) =>
      Conversation(
        id: id ?? this.id,
        name: name ?? this.name,
        avatarAsset: avatarAsset ?? this.avatarAsset,
        lastMessage: lastMessage ?? this.lastMessage,
        timeLabel: timeLabel ?? this.timeLabel,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        participantIds: participantIds ?? this.participantIds,
        recipientId: recipientId ?? this.recipientId,
        recipientPublicKey: recipientPublicKey ?? this.recipientPublicKey,
        participantNames: participantNames ?? this.participantNames,
        online: online ?? this.online,
        unread: unread ?? this.unread,
        previewKind: previewKind ?? this.previewKind,
        delivery: clearDelivery ? null : (delivery ?? this.delivery),
        pinned: pinned ?? this.pinned,
        isGroup: isGroup ?? this.isGroup,
        muted: muted ?? this.muted,
      );

  /// Serializes conversation state for Firestore storage.
  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'participantIds': participantIds,
      if (recipientId != null) 'recipientId': recipientId,
      if (participantNames != null) 'participantNames': participantNames,
      'lastMessage': lastMessage,
      'previewKind': previewKind.toDbString(),
      'lastMessageAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : (lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null),
      if (delivery != null) 'delivery': delivery!.toDbString(),
      'isGroup': isGroup,
      if (isGroup) 'name': name,
    };
  }

  /// Deserializes Firestore document snapshot into a Conversation.
  factory Conversation.fromMap(
    Map<String, dynamic> map,
    String id, {
    String? currentUserId,
    String? fallbackName,
    String? fallbackAvatar,
    String? recipientPublicKey,
  }) {
    final participants = (map['participantIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    String? otherParticipantId;
    if (currentUserId != null && participants.isNotEmpty) {
      final others = participants.where((p) => p != currentUserId).toList();
      if (others.isNotEmpty) {
        otherParticipantId = others.first;
      }
    }

    final rawTimestamp = map['lastMessageAt'];
    DateTime? messageTime;
    if (rawTimestamp is Timestamp) {
      messageTime = rawTimestamp.toDate();
    } else if (rawTimestamp is int) {
      messageTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else if (rawTimestamp is String) {
      messageTime = DateTime.tryParse(rawTimestamp);
    }

    final timeString = messageTime != null
        ? _formatTimeLabel(messageTime)
        : (map['timeLabel'] as String? ?? '');

    final isGroup = (map['isGroup'] as bool?) ?? false;
    final rawNames = map['participantNames'] as Map<dynamic, dynamic>?;
    final parsedNames = rawNames
        ?.map((k, v) => MapEntry(k.toString(), v.toString()));

    String name;
    if (isGroup) {
      name = map['name'] as String? ?? fallbackName ?? 'Group';
    } else if (otherParticipantId != null &&
        parsedNames?[otherParticipantId]?.trim().isNotEmpty == true) {
      name = parsedNames![otherParticipantId]!.trim();
    } else {
      name = fallbackName ?? (map['name'] as String? ?? 'Relay Contact');
    }

    final deliveryStr = map['delivery'] as String?;
    final delivery = deliveryStr != null
        ? DeliveryStage.fromString(deliveryStr)
        : null;

    final unreadMap = map['unreadCount'];
    int unread = 0;
    if (unreadMap is Map && currentUserId != null) {
      unread = (unreadMap[currentUserId] as num?)?.toInt() ?? 0;
    } else if (map['unread'] is num) {
      unread = (map['unread'] as num).toInt();
    }

    final keysMap = map['participantPublicKeys'] as Map<dynamic, dynamic>?;
    final resolvedPublicKey = recipientPublicKey ??
        (otherParticipantId != null && keysMap != null
            ? keysMap[otherParticipantId]?.toString()
            : null);

    return Conversation(
      id: id,
      name: name,
      avatarAsset: fallbackAvatar ?? map['avatarAsset'] as String?,
      lastMessage: map['lastMessage'] as String? ?? '',
      timeLabel: timeString,
      lastMessageAt: messageTime,
      participantIds: participants,
      recipientId: otherParticipantId ?? map['recipientId'] as String?,
      recipientPublicKey: resolvedPublicKey,
      participantNames: parsedNames,
      online: (map['online'] as bool?) ?? false,
      unread: unread,
      previewKind: MessageKind.fromString(map['previewKind'] as String?),
      delivery: delivery,
      pinned: (map['pinned'] as bool?) ?? false,
      isGroup: isGroup,
      muted: (map['muted'] as bool?) ?? false,
    );
  }

  /// Generates the canonical composite document ID for a 1-on-1 thread.
  static String directChatId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return 'chat_${sorted[0]}_${sorted[1]}';
  }

  static String _formatTimeLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0 && now.day == date.day) {
      return DateFormat('HH:mm').format(date);
    }
    if (diff.inDays < 7) {
      return DateFormat('E').format(date);
    }
    return DateFormat('MMM d').format(date);
  }

  @override
  List<Object?> get props => [
        id,
        name,
        avatarAsset,
        lastMessage,
        timeLabel,
        lastMessageAt,
        participantIds,
        recipientId,
        recipientPublicKey,
        participantNames,
        online,
        unread,
        previewKind,
        delivery,
        pinned,
        isGroup,
        muted,
      ];
}
