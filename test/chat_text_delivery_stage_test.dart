import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/connectivity_service.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class _FakeDeliveryRepo extends Fake implements IChatRepository {
  final List<RelayMessage> sentMessages = [];
  Completer<void>? sendCompleter;

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
    if (sendCompleter != null) {
      await sendCompleter!.future;
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

class _TestConnectivity implements IConnectivityService {
  final _controller = StreamController<NetworkStatus>.broadcast();
  @override
  Stream<NetworkStatus> get statusStream => _controller.stream;
  @override
  NetworkStatus get currentStatus => NetworkStatus.online;
  @override
  Future<bool> checkReachability() async => true;
  @override
  void dispose() => _controller.close();
}

void main() {
  group('ChatTextSent Delivery Stage and Non-Blocking Tests', () {
    late _FakeDeliveryRepo repo;
    late _TestConnectivity connectivity;
    late ChatBloc bloc;

    setUp(() {
      repo = _FakeDeliveryRepo();
      connectivity = _TestConnectivity();
      bloc = ChatBloc(
        chatRepository: repo,
        connectivityService: connectivity,
        currentUserId: 'me',
      );
    });

    tearDown(() async {
      await bloc.close();
      connectivity.dispose();
      repo.dispose();
    });

    test('ChatTextSent immediately appends with DeliveryStage.sending and advances to DeliveryStage.sent on send completion', () async {
      const chatId = 'chat_me_peer';
      const conv = Conversation(
        id: chatId,
        name: 'Peer User',
        avatarAsset: null,
        lastMessage: '',
        timeLabel: 'Now',
        recipientId: 'peer',
      );

      bloc.emit(bloc.state.copyWith(
        conversations: [conv],
        activeId: chatId,
        threads: {chatId: []},
      ));

      repo.sendCompleter = Completer<void>();

      // User types and sends message
      bloc.add(const ChatComposerChanged('Fast optimistic message'));
      bloc.add(const ChatTextSent());
      await pumpEventQueue();

      // Verify message is immediately shown with DeliveryStage.sending (clock)
      expect(bloc.state.messages.length, equals(1));
      final pendingMsg = bloc.state.messages.first;
      expect(pendingMsg.text, equals('Fast optimistic message'));
      expect(pendingMsg.delivery, equals(DeliveryStage.sending));
      expect(bloc.state.composerText, isEmpty);

      // Complete the network write
      repo.sendCompleter!.complete();
      await pumpEventQueue();

      // Verify delivery stage automatically advanced to sent (single check)
      expect(bloc.state.messages.length, equals(1));
      final sentMsg = bloc.state.messages.first;
      expect(sentMsg.delivery, equals(DeliveryStage.sent));

      // Verify conversation delivery status also updated to sent
      final updatedConv = bloc.state.conversations.firstWhere((c) => c.id == chatId);
      expect(updatedConv.delivery, equals(DeliveryStage.sent));
    });

    test('ChatTextSent does not block subsequent composer interactions while network write is pending', () async {
      const chatId = 'chat_me_peer';
      const conv = Conversation(
        id: chatId,
        name: 'Peer User',
        avatarAsset: null,
        lastMessage: '',
        timeLabel: 'Now',
        recipientId: 'peer',
      );

      bloc.emit(bloc.state.copyWith(
        conversations: [conv],
        activeId: chatId,
        threads: {chatId: []},
      ));

      repo.sendCompleter = Completer<void>();

      // Send first message
      bloc.add(const ChatComposerChanged('First message'));
      bloc.add(const ChatTextSent());
      await pumpEventQueue();

      expect(bloc.state.messages.length, equals(1));
      expect(bloc.state.messages.first.text, equals('First message'));

      // While first message write is pending, user can immediately type second message
      bloc.add(const ChatComposerChanged('Typing second message immediately'));
      await pumpEventQueue();
      expect(bloc.state.composerText, equals('Typing second message immediately'));

      // Complete first write
      repo.sendCompleter!.complete();
      await pumpEventQueue();

      expect(bloc.state.messages.first.delivery, equals(DeliveryStage.sent));
    });
  });
}
