/// The 4-stage lifecycle of a Relay message from client dispatch to recipient read.
enum DeliveryStage {
  /// Message is queued or actively writing to local cache/network.
  sending,

  /// Message has reached Cloud Firestore servers (single check).
  sent,

  /// Message has been downloaded to the recipient device (double grey check).
  delivered,

  /// Message has been opened and rendered on the recipient screen (double colored check).
  read;

  static DeliveryStage fromString(String? value) {
    return switch (value?.toLowerCase().trim()) {
      'sending' => DeliveryStage.sending,
      'sent' => DeliveryStage.sent,
      'delivered' => DeliveryStage.delivered,
      'read' => DeliveryStage.read,
      _ => DeliveryStage.sent,
    };
  }

  String toDbString() => name;
}
