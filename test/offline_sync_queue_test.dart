import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/connectivity_service.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';
import 'package:relay/features/chats/widgets/connectivity_status_pill.dart';

class _FakeOfflineRepo extends Fake implements IChatRepository {
  final List<RelayMessage> sentMessages = [];
  bool failSends = false;

  final StreamController<List<Conversation>> convsController =
      StreamController<List<Conversation>>.broadcast();
  final StreamController<List<RelayMessage>> msgsController =
      StreamController<List<RelayMessage>>.broadcast();

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      convsController.stream;

  @override
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId) =>
      msgsController.stream;

  @override
  Future<void> sendMessage({
    required String chatId,
    required RelayMessage message,
    required String recipientPublicKey,
  }) async {
    if (failSends) {
      throw Exception('Network unreachable');
    }
    sentMessages.add(message);
  }

  @override
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {}

  @override
  Future<void> updateDeliveryStatus({
    required String chatId,
    required String messageId,
    required DeliveryStage status,
  }) async {}

  void dispose() {
    convsController.close();
    msgsController.close();
  }
}

class _TestConnectivityService implements IConnectivityService {
  final _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _current = NetworkStatus.online;

  @override
  Stream<NetworkStatus> get statusStream => _controller.stream;

  @override
  NetworkStatus get currentStatus => _current;

  void setStatus(NetworkStatus status) {
    _current = status;
    _controller.add(status);
  }

  @override
  Future<bool> checkReachability() async => _current == NetworkStatus.online;

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  group('RelayConnectivityService Unit Tests', () {
    test('setStatusForTesting updates status and notifies stream listeners', () async {
      final service = RelayConnectivityService();
      addTearDown(service.dispose);

      final statuses = <NetworkStatus>[];
      final sub = service.statusStream.listen(statuses.add);
      addTearDown(sub.cancel);

      service.setStatusForTesting(NetworkStatus.offline);
      expect(service.currentStatus, equals(NetworkStatus.offline));

      service.setStatusForTesting(NetworkStatus.online);
      expect(service.currentStatus, equals(NetworkStatus.online));

      await pumpEventQueue();
      expect(statuses, equals([NetworkStatus.offline, NetworkStatus.online]));
    });
  });

  group('ChatBloc Offline Synchronization Queue Pipeline', () {
    late _FakeOfflineRepo repo;
    late _TestConnectivityService connectivity;
    late ChatBloc bloc;

    setUp(() {
      repo = _FakeOfflineRepo();
      connectivity = _TestConnectivityService();
      bloc = ChatBloc(
        chatRepository: repo,
        currentUserId: 'user_me',
        demoMode: false,
        connectivityService: connectivity,
      );
    });

    tearDown(() async {
      await bloc.close();
      repo.dispose();
      connectivity.dispose();
    });

    test('queues outgoing message when networkStatus is offline', () async {
      // Simulate going offline
      connectivity.setStatus(NetworkStatus.offline);
      await pumpEventQueue();
      expect(bloc.state.networkStatus, equals(NetworkStatus.offline));

      // Set active conversation
      const conv = Conversation(
        id: 'chat_user_me_peer',
        name: 'Peer Contact',
        avatarAsset: null,
        lastMessage: '',
        timeLabel: 'Now',
        recipientId: 'peer',
      );

      bloc.emit(bloc.state.copyWith(
        conversations: [conv],
        activeId: 'chat_user_me_peer',
        threads: {'chat_user_me_peer': []},
      ));

      // Attempt to send a message while offline
      bloc.add(const ChatComposerChanged('Hello while offline!'));
      bloc.add(const ChatTextSent());
      await pumpEventQueue();

      // Verify message is appended locally in sending state
      expect(bloc.state.messages.length, equals(1));
      expect(bloc.state.messages.first.text, equals('Hello while offline!'));
      expect(bloc.state.messages.first.delivery, equals(DeliveryStage.sending));

      // Verify message is queued in outbox
      expect(bloc.state.outboxQueue.length, equals(1));
      expect(bloc.state.outboxQueue.first.message.text, equals('Hello while offline!'));
      expect(repo.sentMessages, isEmpty);

      // Transition back online
      connectivity.setStatus(NetworkStatus.online);
      await pumpEventQueue();

      // Verify queue is flushed and message was sent to repository
      expect(repo.sentMessages.length, equals(1));
      expect(repo.sentMessages.first.text, equals('Hello while offline!'));
      expect(bloc.state.outboxQueue, isEmpty);
    });

    test('manual ChatOutboxFlushRequested flushes pending queue', () async {
      const conv = Conversation(
        id: 'chat_user_me_peer',
        name: 'Peer Contact',
        avatarAsset: null,
        lastMessage: '',
        timeLabel: 'Now',
        recipientId: 'peer',
      );

      final queuedMsg = RelayMessage(
        id: 'msg_queued_1',
        senderId: 'user_me',
        recipientId: 'peer',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Queued text',
        delivery: DeliveryStage.sending,
      );

      bloc.emit(bloc.state.copyWith(
        conversations: [conv],
        activeId: 'chat_user_me_peer',
        threads: {'chat_user_me_peer': [queuedMsg]},
        outboxQueue: [
          OutboxItem(
            chatId: 'chat_user_me_peer',
            message: queuedMsg,
            recipientPublicKey: 'key_123',
            queuedAt: DateTime.now(),
          ),
        ],
      ));

      expect(bloc.state.outboxQueue.length, equals(1));

      // Request flush
      bloc.add(const ChatOutboxFlushRequested());
      await pumpEventQueue();

      expect(repo.sentMessages.length, equals(1));
      expect(repo.sentMessages.first.id, equals('msg_queued_1'));
      expect(bloc.state.outboxQueue, isEmpty);
    });
  });

  group('ConnectivityStatusPill Widget Tests', () {
    late _FakeOfflineRepo repo;
    late _TestConnectivityService connectivity;
    late ChatBloc bloc;

    setUp(() {
      repo = _FakeOfflineRepo();
      connectivity = _TestConnectivityService();
      bloc = ChatBloc(
        chatRepository: repo,
        currentUserId: 'user_me',
        demoMode: false,
        connectivityService: connectivity,
      );
    });

    tearDown(() async {
      await bloc.close();
      repo.dispose();
      connectivity.dispose();
    });

    testWidgets('renders nothing when network is online and outbox is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(
              body: ConnectivityStatusPill(),
            ),
          ),
        ),
      );

      expect(find.text('Waiting for network...'), findsNothing);
      expect(find.text('Connecting...'), findsNothing);
    });

    testWidgets('renders offline banner when networkStatus is offline', (tester) async {
      bloc.emit(bloc.state.copyWith(networkStatus: NetworkStatus.offline));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(
              body: ConnectivityStatusPill(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for network...'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.wifi_slash), findsOneWidget);
    });

    testWidgets('renders queued count and triggers flush on tap', (tester) async {
      final queuedMsg = RelayMessage(
        id: 'msg_test_tap',
        senderId: 'user_me',
        recipientId: 'peer',
        sentAt: DateTime.now(),
        kind: MessageKind.text,
        text: 'Pending tap message',
        delivery: DeliveryStage.sending,
      );

      bloc.emit(bloc.state.copyWith(
        networkStatus: NetworkStatus.offline,
        outboxQueue: [
          OutboxItem(
            chatId: 'chat_test',
            message: queuedMsg,
            recipientPublicKey: 'key_abc',
            queuedAt: DateTime.now(),
          ),
        ],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(
              body: ConnectivityStatusPill(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline (1 queued: tap to retry)'), findsOneWidget);

      // Tap the pill to trigger flush retry
      await tester.tap(find.text('Offline (1 queued: tap to retry)'));
      await tester.pumpAndSettle();

      // Repo should have received the message now
      expect(repo.sentMessages.length, equals(1));
      expect(repo.sentMessages.first.id, equals('msg_test_tap'));
    });
  });
}
