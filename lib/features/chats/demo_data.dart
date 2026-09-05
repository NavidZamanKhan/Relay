import 'chat_models.dart';
import 'package:intl/intl.dart';

/// Fictional, bundled conversations. Every contact has an independent thread.
abstract final class DemoData {
  static const conversations = <Conversation>[
    Conversation(
      id: 'aisha',
      name: 'Aisha Rahman',
      avatarAsset: 'assets/images/aisha.png',
      lastMessage: 'Okay, listen to this first',
      timeLabel: '18:42',
      online: true,
      unread: 2,
      pinned: true,
    ),
    Conversation(
      id: 'mom',
      name: 'Mom',
      avatarAsset: 'assets/images/mom.png',
      lastMessage: 'Come home before it rains.',
      timeLabel: '18:36',
      pinned: true,
    ),
    Conversation(
      id: 'home',
      name: 'The home team',
      avatarAsset: null,
      lastMessage: 'Sami: Dinner at 9. Be there.',
      timeLabel: '18:28',
      unread: 5,
      isGroup: true,
    ),
    Conversation(
      id: 'sami',
      name: 'Sami Ahmed',
      avatarAsset: 'assets/images/sami.png',
      lastMessage: 'Voice message · 0:18',
      timeLabel: '17:54',
      previewKind: MessageKind.voice,
      delivery: DeliveryStage.read,
    ),
    Conversation(
      id: 'rafi',
      name: 'Rafi',
      avatarAsset: 'assets/images/rafi.png',
      lastMessage: 'Sent a photo',
      timeLabel: '17:30',
      online: true,
      unread: 1,
      previewKind: MessageKind.image,
    ),
    Conversation(
      id: 'nabila',
      name: 'Nabila',
      avatarAsset: null,
      lastMessage: 'I saved you a seat.',
      timeLabel: 'Yesterday',
      delivery: DeliveryStage.read,
    ),
    Conversation(
      id: 'weekend',
      name: 'Weekend plans',
      avatarAsset: null,
      lastMessage: 'You: Saturday works for me',
      timeLabel: 'Yesterday',
      isGroup: true,
      muted: true,
      delivery: DeliveryStage.delivered,
    ),
    Conversation(
      id: 'arif',
      name: 'Arif Hasan',
      avatarAsset: null,
      lastMessage: 'That looks really good, man.',
      timeLabel: 'Thu',
    ),
  ];

  static List<Conversation> inbox() {
    final now = DateTime.now();
    const minutes = [0, 6, 14, 48, 72];
    return [
      for (var i = 0; i < conversations.length; i++)
        i < 5
            ? conversations[i].copyWith(
                timeLabel: DateFormat(
                  'HH:mm',
                ).format(now.subtract(Duration(minutes: minutes[i]))),
              )
            : conversations[i],
    ];
  }

  static List<RelayMessage> messagesFor(String id) {
    final today = DateTime.now();
    DateTime at(int minute) => today.subtract(Duration(minutes: 42 - minute));
    if (id == 'aisha') {
      return [
        RelayMessage(
          id: 'a2',
          senderId: 'me',
          sentAt: at(35),
          kind: MessageKind.text,
          text: 'Tell me you went for that walk.',
          isMine: true,
        ),
        RelayMessage(
          id: 'a3',
          senderId: id,
          sentAt: at(36),
          kind: MessageKind.image,
          asset: 'assets/images/sylhet_evening.png',
          text: 'Took the long way home.',
        ),
        RelayMessage(
          id: 'a4',
          senderId: 'me',
          sentAt: at(38),
          kind: MessageKind.text,
          text: 'This is my favourite version of Sylhet.',
          isMine: true,
        ),
        RelayMessage(
          id: 'a5',
          senderId: id,
          sentAt: at(41),
          kind: MessageKind.text,
          text: 'Okay, listen to this first',
        ),
        RelayMessage(
          id: 'a6',
          senderId: id,
          sentAt: at(42),
          kind: MessageKind.voice,
          duration: const Duration(seconds: 18),
        ),
      ];
    }
    final (incoming, outgoing) = switch (id) {
      'mom' => ('Come home before it rains.', 'On my way. Need anything?'),
      'sami' => ('I have an idea for the weekend.', 'Go on. I’m listening.'),
      'rafi' => ('Found a new place to shoot.', 'Send me a photo.'),
      'home' => ('Sami: Dinner at 9. Be there.', 'I’ll bring something.'),
      'nabila' => ('I saved you a seat.', 'You’re the best. Five minutes.'),
      'weekend' => ('Rafi: Who’s free this weekend?', 'Saturday works for me'),
      _ => (
        'That looks really good, man.',
        'Thanks! Still working on the details.',
      ),
    };
    return [
      RelayMessage(
        id: '$id-1',
        senderId: id,
        sentAt: at(12),
        kind: MessageKind.text,
        text: incoming,
      ),
      RelayMessage(
        id: '$id-2',
        senderId: 'me',
        sentAt: at(13),
        kind: MessageKind.text,
        text: outgoing,
        isMine: true,
      ),
      if (id == 'sami')
        RelayMessage(
          id: '$id-3',
          senderId: id,
          sentAt: at(14),
          kind: MessageKind.voice,
          duration: const Duration(seconds: 18),
        ),
      if (id == 'rafi')
        RelayMessage(
          id: '$id-3',
          senderId: id,
          sentAt: at(14),
          kind: MessageKind.image,
          asset: 'assets/images/sylhet_evening.png',
        ),
    ];
  }
}
