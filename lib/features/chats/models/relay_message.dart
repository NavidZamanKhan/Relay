import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'delivery_stage.dart';
import 'message_kind.dart';

/// Immutable domain model representing a message in Relay.
class RelayMessage extends Equatable {
  const RelayMessage({
    required this.id,
    required this.senderId,
    required this.sentAt,
    required this.kind,
    this.recipientId,
    this.text,
    this.encryptedPayload,
    this.nonce,
    this.ephemeralPublicKey,
    this.asset,
    this.duration = Duration.zero,
    this.waveform,
    this.audioUrl,
    this.audioData,
    this.imageUrl,
    this.imageData,
    this.reactions,
    this.isMine = false,
    this.delivery = DeliveryStage.read,
    this.replyTo,
  });

  final String id;
  final String senderId;
  final String? recipientId;
  final DateTime sentAt;
  final MessageKind kind;
  final String? text;
  final String? encryptedPayload;
  final String? nonce;
  final String? ephemeralPublicKey;
  final String? asset;
  final Duration duration;
  final List<double>? waveform;
  final String? audioUrl;
  final String? audioData;
  final String? imageUrl;
  final String? imageData;
  final Map<String, String>? reactions;
  final bool isMine;
  final DeliveryStage delivery;
  final String? replyTo;

  RelayMessage copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    DateTime? sentAt,
    MessageKind? kind,
    String? text,
    String? encryptedPayload,
    String? nonce,
    String? ephemeralPublicKey,
    String? asset,
    Duration? duration,
    List<double>? waveform,
    String? audioUrl,
    String? audioData,
    String? imageUrl,
    String? imageData,
    Map<String, String>? reactions,
    bool? isMine,
    DeliveryStage? delivery,
    String? replyTo,
  }) =>
      RelayMessage(
        id: id ?? this.id,
        senderId: senderId ?? this.senderId,
        recipientId: recipientId ?? this.recipientId,
        sentAt: sentAt ?? this.sentAt,
        kind: kind ?? this.kind,
        text: text ?? this.text,
        encryptedPayload: encryptedPayload ?? this.encryptedPayload,
        nonce: nonce ?? this.nonce,
        ephemeralPublicKey: ephemeralPublicKey ?? this.ephemeralPublicKey,
        asset: asset ?? this.asset,
        duration: duration ?? this.duration,
        waveform: waveform ?? this.waveform,
        audioUrl: audioUrl ?? this.audioUrl,
        audioData: audioData ?? this.audioData,
        imageUrl: imageUrl ?? this.imageUrl,
        imageData: imageData ?? this.imageData,
        reactions: reactions ?? this.reactions,
        isMine: isMine ?? this.isMine,
        delivery: delivery ?? this.delivery,
        replyTo: replyTo ?? this.replyTo,
      );

  /// Serializes message state to Firestore document schema.
  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'senderId': senderId,
      if (recipientId != null) 'recipientId': recipientId,
      'kind': kind.toDbString(),
      'sentAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(sentAt),
      'delivery': delivery.toDbString(),
      if (text != null) 'text': text,
      if (encryptedPayload != null) 'encryptedPayload': encryptedPayload,
      if (nonce != null) 'nonce': nonce,
      if (ephemeralPublicKey != null)
        'ephemeralPublicKey': ephemeralPublicKey,
      if (asset != null && (asset!.startsWith('assets/') || !asset!.startsWith('/')))
        'asset': asset,
      if (duration != Duration.zero)
        'durationMs': duration.inMilliseconds,
      if (waveform != null && waveform!.isNotEmpty) 'waveform': waveform,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (audioData != null) 'audioData': audioData,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageData != null) 'imageData': imageData,
      if (reactions != null && reactions!.isNotEmpty) 'reactions': reactions,
      if (replyTo != null) 'replyTo': replyTo,
    };
  }

  /// Deserializes a Firestore document snapshot into a RelayMessage.
  factory RelayMessage.fromMap(
    Map<String, dynamic> map,
    String id, {
    String? currentUserId,
  }) {
    final sender = (map['senderId'] as String?)?.trim() ?? '';
    final rawSentAt = map['sentAt'];
    DateTime parsedDate;

    if (rawSentAt is Timestamp) {
      parsedDate = rawSentAt.toDate();
    } else if (rawSentAt is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawSentAt);
    } else if (rawSentAt is String) {
      parsedDate = DateTime.tryParse(rawSentAt) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final kind = MessageKind.fromString(map['kind'] as String?);
    final delivery = DeliveryStage.fromString(map['delivery'] as String?);
    final durationMs = (map['durationMs'] as num?)?.toInt() ?? 0;
    final rawWaveform = map['waveform'] as List<dynamic>?;
    final waveform = rawWaveform
        ?.map((e) => (e as num).toDouble())
        .toList(growable: false);
    final audioUrl = map['audioUrl'] as String?;
    final audioData = map['audioData'] as String?;
    final imageUrl = map['imageUrl'] as String?;
    final imageData = map['imageData'] as String?;

    final rawReactions = map['reactions'];
    Map<String, String>? reactions;
    if (rawReactions is Map) {
      reactions = rawReactions.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    return RelayMessage(
      id: id,
      senderId: sender,
      recipientId: map['recipientId'] as String?,
      sentAt: parsedDate,
      kind: kind,
      text: map['text'] as String?,
      encryptedPayload: map['encryptedPayload'] as String?,
      nonce: map['nonce'] as String?,
      ephemeralPublicKey: map['ephemeralPublicKey'] as String?,
      asset: map['asset'] as String?,
      duration: Duration(milliseconds: durationMs),
      waveform: waveform,
      audioUrl: audioUrl,
      audioData: audioData,
      imageUrl: imageUrl,
      imageData: imageData,
      reactions: reactions,
      isMine: currentUserId != null ? (sender == currentUserId) : false,
      delivery: delivery,
      replyTo: map['replyTo'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        recipientId,
        sentAt,
        kind,
        text,
        encryptedPayload,
        nonce,
        ephemeralPublicKey,
        asset,
        duration,
        waveform,
        audioUrl,
        audioData,
        imageUrl,
        imageData,
        reactions,
        isMine,
        delivery,
        replyTo,
      ];
}
