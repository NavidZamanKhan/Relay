/// The payload format carried by a Relay message.
enum MessageKind {
  text,
  image,
  voice,
  document;

  static MessageKind fromString(String? value) {
    return switch (value?.toLowerCase().trim()) {
      'text' => MessageKind.text,
      'image' => MessageKind.image,
      'voice' => MessageKind.voice,
      'document' => MessageKind.document,
      _ => MessageKind.text,
    };
  }

  String toDbString() => name;
}
