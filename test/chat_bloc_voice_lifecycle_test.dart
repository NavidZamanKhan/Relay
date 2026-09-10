import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/audio_service.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

const _chatId = 'chat_alice_bob';
const _userId = 'alice';

class _ControlledChatRepository extends Fake implements IChatRepository {
  final messages = StreamController<List<RelayMessage>>.broadcast();
  final sendCompleted = Completer<void>();
  String? sentMessageId;

  @override
  Stream<List<RelayMessage>> watchMessages(
    String chatId,
    String currentUserId,
  ) => messages.stream;

  @override
  Future<void> markConversationRead({
    required String chatId,
    required String readerUserId,
  }) async {}

  @override
  Future<void> updateDeliveryStatus({
    required String chatId,
    required String messageId,
    required DeliveryStage status,
  }) async {}

  @override
  Future<void> sendVoiceMessage({
    required String chatId,
    required String localFilePath,
    required Duration duration,
    required List<double> waveform,
    required String recipientPublicKey,
    String? messageId,
    String? replyTo,
  }) {
    sentMessageId = messageId;
    return sendCompleted.future;
  }
}

class _RecordedAudioService extends NoOpAudioService {
  @override
  Future<({String path, Duration duration, List<double> waveform})?>
  stopRecording() async => (
    path: '/tmp/relay-voice-test.m4a',
    duration: const Duration(seconds: 5),
    waveform: [0.2, 0.4, 0.8],
  );
}

Future<RelayMessage> _recordVoice(WidgetTester tester, ChatBloc bloc) async {
  bloc.add(const ChatRecordingStarted());
  await tester.pump();
  bloc.add(const ChatRecordingSent());
  await tester.pump();
  return bloc.state.messages.single;
}

void main() {
  late _ControlledChatRepository repository;
  late ChatBloc bloc;

  Future<void> openChat(WidgetTester tester) async {
    repository = _ControlledChatRepository();
    bloc = ChatBloc(
      chatRepository: repository,
      currentUserId: _userId,
      audioService: _RecordedAudioService(),
      demoMode: false,
    );
    addTearDown(() async {
      await bloc.close();
      await repository.messages.close();
    });
    bloc.add(const ChatOpened(_chatId));
    await tester.pump();
  }

  testWidgets('sent voice survives missing snapshots until confirmed once', (
    tester,
  ) async {
    await openChat(tester);
    final outgoing = await _recordVoice(tester, bloc);
    expect(outgoing.delivery, DeliveryStage.sending);
    expect(repository.sentMessageId, outgoing.id);

    final emissions = <ChatState>[];
    final subscription = bloc.stream.listen(emissions.add);
    addTearDown(subscription.cancel);

    repository.messages.add([]);
    await tester.pump();
    expect(bloc.state.messages.single, outgoing);

    repository.sendCompleted.complete();
    await tester.pump();
    expect(bloc.state.messages.single.delivery, DeliveryStage.sent);

    final incoming = RelayMessage(
      id: 'incoming',
      senderId: 'bob',
      sentAt: outgoing.sentAt.add(const Duration(milliseconds: 1)),
      kind: MessageKind.text,
      text: 'Listening now',
      delivery: DeliveryStage.read,
    );
    for (final snapshot in <List<RelayMessage>>[
      [],
      [incoming],
      [],
    ]) {
      repository.messages.add(snapshot);
      await tester.pump();
      expect(
        bloc.state.messages.where((m) => m.id == outgoing.id),
        hasLength(1),
      );
      expect(bloc.state.messages.first.id, outgoing.id);
    }

    bloc.add(const ChatSearchChanged('voice'));
    await tester.pump();

    final confirmed = RelayMessage(
      id: outgoing.id,
      senderId: _userId,
      recipientId: 'bob',
      sentAt: outgoing.sentAt,
      kind: MessageKind.voice,
      duration: outgoing.duration,
      waveform: outgoing.waveform,
      audioData: 'confirmed-audio-bytes',
      delivery: DeliveryStage.sent,
      isMine: true,
    );
    repository.messages.add([confirmed, incoming]);
    await tester.pump();
    expect(bloc.state.messages, [confirmed, incoming]);
    expect(bloc.state.messages.first.asset, isNull);
    expect(emissions, isNotEmpty);
    expect(
      emissions.every(
        (state) => state.messages.where((m) => m.id == outgoing.id).length == 1,
      ),
      isTrue,
    );
  });

  testWidgets(
    'missing snapshot drops expired, received and delivered messages',
    (tester) async {
      await openChat(tester);
      final outgoing = await _recordVoice(tester, bloc);
      repository.sendCompleted.complete();
      await tester.pump();

      final oldTime = DateTime.now().subtract(const Duration(seconds: 31));
      repository.messages.add([
        outgoing.copyWith(id: 'expired-sending', sentAt: oldTime),
        outgoing.copyWith(
          id: 'expired-sent',
          sentAt: oldTime,
          delivery: DeliveryStage.sent,
        ),
        outgoing.copyWith(
          id: 'received',
          senderId: 'bob',
          isMine: false,
          delivery: DeliveryStage.sent,
        ),
        outgoing.copyWith(id: 'delivered', delivery: DeliveryStage.delivered),
        outgoing.copyWith(id: 'read', delivery: DeliveryStage.read),
      ]);
      await tester.pump();

      repository.messages.add([]);
      await tester.pump();
      expect(bloc.state.messages.map((m) => m.id), [outgoing.id]);
    },
  );

  testWidgets('failed voice upload removes its optimistic message', (
    tester,
  ) async {
    await openChat(tester);
    await _recordVoice(tester, bloc);

    repository.sendCompleted.completeError(StateError('Upload failed'));
    await tester.pump();
    expect(bloc.state.messages, isEmpty);

    repository.messages.add([]);
    await tester.pump();
    expect(bloc.state.messages, isEmpty);
  });
}
