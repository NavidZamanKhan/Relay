import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/widgets/group_system_event_pill.dart';

import 'group_chat_admin_test.dart';

void main() {
  group('GroupSystemEventPill Widget Tests', () {
    testWidgets('renders correct icon and text for admin appointment', (tester) async {
      final message = RelayMessage(
        id: 'sys-1',
        senderId: 'system',
        sentAt: DateTime(2026, 9, 12, 10, 0),
        kind: MessageKind.system,
        text: 'Aisha appointed Rafi as an admin',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupSystemEventPill(message: message),
          ),
        ),
      );

      expect(find.text('Aisha appointed Rafi as an admin'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.shield_fill), findsOneWidget);
    });

    testWidgets('renders correct icon for member additions', (tester) async {
      final message = RelayMessage(
        id: 'sys-2',
        senderId: 'system',
        sentAt: DateTime(2026, 9, 12, 10, 5),
        kind: MessageKind.system,
        text: 'Aisha added Sami, Nabila',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupSystemEventPill(message: message),
          ),
        ),
      );

      expect(find.text('Aisha added Sami, Nabila'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.person_badge_plus), findsOneWidget);
    });

    testWidgets('renders correct icon for member removal', (tester) async {
      final message = RelayMessage(
        id: 'sys-3',
        senderId: 'system',
        sentAt: DateTime(2026, 9, 12, 10, 10),
        kind: MessageKind.system,
        text: 'Aisha removed Sami',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupSystemEventPill(message: message),
          ),
        ),
      );

      expect(find.text('Aisha removed Sami'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.person_badge_minus), findsOneWidget);
    });

    testWidgets('renders correct icon for leaving group', (tester) async {
      final message = RelayMessage(
        id: 'sys-4',
        senderId: 'system',
        sentAt: DateTime(2026, 9, 12, 10, 15),
        kind: MessageKind.system,
        text: 'Rafi left the group',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupSystemEventPill(message: message),
          ),
        ),
      );

      expect(find.text('Rafi left the group'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.arrow_right_square), findsOneWidget);
    });

    testWidgets('renders correct icon for metadata update', (tester) async {
      final message = RelayMessage(
        id: 'sys-5',
        senderId: 'system',
        sentAt: DateTime(2026, 9, 12, 10, 20),
        kind: MessageKind.system,
        text: 'Group name changed to "Relay Core"',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupSystemEventPill(message: message),
          ),
        ),
      );

      expect(find.text('Group name changed to "Relay Core"'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);
    });
  });

  group('ChatBloc Group System Events Pipeline', () {
    test('ChatGroupMemberPromoted emits in-chat system message', () async {
      final bloc = ChatBloc(
        currentUserId: 'user_alice',
        demoMode: true,
      );

      // Set initial conversation
      const groupConv = Conversation(
        id: 'group_test',
        name: 'Relay Devs',
        avatarAsset: null,
        lastMessage: '',
        timeLabel: 'Now',
        isGroup: true,
        adminIds: ['user_alice'],
        participantIds: ['user_alice', 'user_bob'],
        participantNames: {
          'user_alice': 'Alice',
          'user_bob': 'Bob',
        },
      );

      bloc.emit(
        bloc.state.copyWith(
          conversations: [groupConv],
          activeId: 'group_test',
          threads: {'group_test': []},
        ),
      );

      bloc.add(const ChatGroupMemberPromoted(
        groupId: 'group_test',
        targetUserId: 'user_bob',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ChatState>((state) {
            final msgs = state.messages;
            return msgs.any((m) =>
                m.kind == MessageKind.system &&
                m.text != null &&
                m.text!.contains('Bob was appointed as an admin'));
          }),
        ),
      );

      await bloc.close();
    });

    test('ChatGroupMembersAdded emits in-chat system message', () async {
      final bloc = ChatBloc(
        currentUserId: 'user_alice',
        demoMode: true,
      );

      const groupConv = Conversation(
        id: 'group_test',
        name: 'Relay Devs',
        avatarAsset: null,
        lastMessage: '',
        timeLabel: 'Now',
        isGroup: true,
        adminIds: ['user_alice'],
        participantIds: ['user_alice'],
        participantNames: {'user_alice': 'Alice'},
      );

      bloc.emit(
        bloc.state.copyWith(
          conversations: [groupConv],
          activeId: 'group_test',
          threads: {'group_test': []},
        ),
      );

      bloc.add(const ChatGroupMembersAdded(
        groupId: 'group_test',
        newMembers: [
          RelayContact(
            id: 'user_carol',
            displayName: 'Carol',
            phoneNumber: '+15551234',
            isRegistered: true,
          ),
        ],
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ChatState>((state) {
            final msgs = state.messages;
            return msgs.any((m) =>
                m.kind == MessageKind.system &&
                m.text != null &&
                m.text!.contains('Added Carol'));
          }),
        ),
      );

      await bloc.close();
    });
  });
}
