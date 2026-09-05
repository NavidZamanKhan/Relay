import 'package:equatable/equatable.dart';

enum MessageKind { text, image, voice, document }

enum InboxFilter { all, unread, groups }

enum DeliveryStage { sending, sent, delivered, read }

class RelayMessage extends Equatable {
  const RelayMessage({
    required this.id,
    required this.senderId,
    required this.sentAt,
    required this.kind,
    this.text,
    this.asset,
    this.duration = Duration.zero,
    this.isMine = false,
    this.delivery = DeliveryStage.read,
    this.replyTo,
  });

  final String id;
  final String senderId;
  final DateTime sentAt;
  final MessageKind kind;
  final String? text;
  final String? asset;
  final Duration duration;
  final bool isMine;
  final DeliveryStage delivery;
  final String? replyTo;

  RelayMessage copyWith({DeliveryStage? delivery}) => RelayMessage(
    id: id,
    senderId: senderId,
    sentAt: sentAt,
    kind: kind,
    text: text,
    asset: asset,
    duration: duration,
    isMine: isMine,
    delivery: delivery ?? this.delivery,
    replyTo: replyTo,
  );

  @override
  List<Object?> get props => [
    id,
    senderId,
    sentAt,
    kind,
    text,
    asset,
    duration,
    isMine,
    delivery,
    replyTo,
  ];
}

class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.name,
    required this.avatarAsset,
    required this.lastMessage,
    required this.timeLabel,
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
  final bool online;
  final int unread;
  final MessageKind previewKind;
  final DeliveryStage? delivery;
  final bool pinned;
  final bool isGroup;
  final bool muted;

  Conversation copyWith({
    String? lastMessage,
    String? timeLabel,
    int? unread,
    MessageKind? previewKind,
    DeliveryStage? delivery,
    bool? muted,
    bool clearDelivery = false,
  }) => Conversation(
    id: id,
    name: name,
    avatarAsset: avatarAsset,
    lastMessage: lastMessage ?? this.lastMessage,
    timeLabel: timeLabel ?? this.timeLabel,
    online: online,
    unread: unread ?? this.unread,
    previewKind: previewKind ?? this.previewKind,
    delivery: clearDelivery ? null : delivery ?? this.delivery,
    pinned: pinned,
    isGroup: isGroup,
    muted: muted ?? this.muted,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    avatarAsset,
    lastMessage,
    timeLabel,
    online,
    unread,
    previewKind,
    delivery,
    pinned,
    isGroup,
    muted,
  ];
}
