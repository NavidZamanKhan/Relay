import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'chat_models.dart';
import 'demo_data.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

final class ChatOpened extends ChatEvent {
  const ChatOpened(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

final class ChatSearchChanged extends ChatEvent {
  const ChatSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

final class ChatFilterChanged extends ChatEvent {
  const ChatFilterChanged(this.filter);
  final InboxFilter filter;
  @override
  List<Object?> get props => [filter];
}

final class ChatComposerChanged extends ChatEvent {
  const ChatComposerChanged(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

final class ChatTextSent extends ChatEvent {
  const ChatTextSent();
}

final class ChatMediaSent extends ChatEvent {
  const ChatMediaSent(this.kind);
  final MessageKind kind;
  @override
  List<Object?> get props => [kind];
}

final class ChatDeliveryAdvanced extends ChatEvent {
  const ChatDeliveryAdvanced(this.chatId, this.messageId, this.stage);
  final String chatId, messageId;
  final DeliveryStage stage;
  @override
  List<Object?> get props => [chatId, messageId, stage];
}

final class ChatReplyArrived extends ChatEvent {
  const ChatReplyArrived(this.chatId);
  final String chatId;
  @override
  List<Object?> get props => [chatId];
}

final class ChatVoiceToggled extends ChatEvent {
  const ChatVoiceToggled(this.messageId);
  final String messageId;
  @override
  List<Object?> get props => [messageId];
}

final class ChatVoiceSeeked extends ChatEvent {
  const ChatVoiceSeeked(this.id, this.progress);
  final String id;
  final double progress;
  @override
  List<Object?> get props => [id, progress];
}

final class ChatVoiceTicked extends ChatEvent {
  const ChatVoiceTicked();
}

final class ChatVoiceSpeedChanged extends ChatEvent {
  const ChatVoiceSpeedChanged();
}

final class ChatRecordingStarted extends ChatEvent {
  const ChatRecordingStarted();
}

final class ChatRecordingTicked extends ChatEvent {
  const ChatRecordingTicked();
}

final class ChatRecordingDragged extends ChatEvent {
  const ChatRecordingDragged(this.cancelProgress);
  final double cancelProgress;
  @override
  List<Object?> get props => [cancelProgress];
}

final class ChatRecordingLocked extends ChatEvent {
  const ChatRecordingLocked();
}

final class ChatRecordingReleased extends ChatEvent {
  const ChatRecordingReleased();
}

final class ChatRecordingSent extends ChatEvent {
  const ChatRecordingSent();
}

final class ChatRecordingCancelled extends ChatEvent {
  const ChatRecordingCancelled();
}

final class ChatHistoryCleared extends ChatEvent {
  const ChatHistoryCleared();
}

final class ChatMuteToggled extends ChatEvent {
  const ChatMuteToggled();
}

final class ChatGroupCreated extends ChatEvent {
  const ChatGroupCreated(this.id, this.name, this.members);
  final String id, name;
  final List<String> members;
  @override
  List<Object?> get props => [id, name, members];
}

final class ChatState extends Equatable {
  const ChatState({
    required this.conversations,
    required this.threads,
    this.activeId = 'aisha',
    this.searchQuery = '',
    this.filter = InboxFilter.all,
    this.composerText = '',
    this.typingIds = const {},
    this.playingMessageId,
    this.voicePaused = true,
    this.voiceProgress = 0,
    this.voiceSpeed = 1,
    this.isRecording = false,
    this.recordingLocked = false,
    this.recordingSeconds = 0,
    this.cancelProgress = 0,
  });
  final List<Conversation> conversations;
  final Map<String, List<RelayMessage>> threads;
  final String activeId, searchQuery, composerText;
  final InboxFilter filter;
  final Set<String> typingIds;
  final String? playingMessageId;
  final bool voicePaused, isRecording, recordingLocked;
  final double voiceProgress, voiceSpeed, cancelProgress;
  final int recordingSeconds;
  List<RelayMessage> get messages => threads[activeId] ?? const [];
  bool get typing => typingIds.contains(activeId);
  List<Conversation> get filteredConversations {
    final q = searchQuery.trim().toLowerCase();
    return conversations
        .where((c) {
          final matchesFilter = switch (filter) {
            InboxFilter.all => true,
            InboxFilter.unread => c.unread > 0,
            InboxFilter.groups => c.isGroup,
          };
          return matchesFilter &&
              (q.isEmpty ||
                  c.name.toLowerCase().contains(q) ||
                  c.lastMessage.toLowerCase().contains(q) ||
                  (threads[c.id] ?? []).any(
                    (m) => (m.text ?? '').toLowerCase().contains(q),
                  ));
        })
        .toList(growable: false);
  }

  ChatState copyWith({
    List<Conversation>? conversations,
    Map<String, List<RelayMessage>>? threads,
    String? activeId,
    String? searchQuery,
    InboxFilter? filter,
    String? composerText,
    Set<String>? typingIds,
    String? playingMessageId,
    bool clearPlayingMessage = false,
    bool? voicePaused,
    double? voiceProgress,
    double? voiceSpeed,
    bool? isRecording,
    bool? recordingLocked,
    int? recordingSeconds,
    double? cancelProgress,
  }) => ChatState(
    conversations: conversations ?? this.conversations,
    threads: threads ?? this.threads,
    activeId: activeId ?? this.activeId,
    searchQuery: searchQuery ?? this.searchQuery,
    filter: filter ?? this.filter,
    composerText: composerText ?? this.composerText,
    typingIds: typingIds ?? this.typingIds,
    playingMessageId: clearPlayingMessage
        ? null
        : playingMessageId ?? this.playingMessageId,
    voicePaused: voicePaused ?? this.voicePaused,
    voiceProgress: voiceProgress ?? this.voiceProgress,
    voiceSpeed: voiceSpeed ?? this.voiceSpeed,
    isRecording: isRecording ?? this.isRecording,
    recordingLocked: recordingLocked ?? this.recordingLocked,
    recordingSeconds: recordingSeconds ?? this.recordingSeconds,
    cancelProgress: cancelProgress ?? this.cancelProgress,
  );
  @override
  List<Object?> get props => [
    conversations,
    threads,
    activeId,
    searchQuery,
    filter,
    composerText,
    typingIds,
    playingMessageId,
    voicePaused,
    voiceProgress,
    voiceSpeed,
    isRecording,
    recordingLocked,
    recordingSeconds,
    cancelProgress,
  ];
}

/// Owns the prototype's semantic state. Controllers in the presentation layer
/// interpolate pixels only; every send/seek/record/filter action arrives here.
/// Timers simulate transport and audio; no microphone or network is accessed.
final class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc()
    : super(
        ChatState(
          conversations: DemoData.inbox(),
          threads: {
            for (final c in DemoData.conversations)
              c.id: DemoData.messagesFor(c.id),
          },
        ),
      ) {
    on<ChatOpened>((e, emit) {
      _voiceTimer?.cancel();
      _recordingTimer?.cancel();
      emit(
        state.copyWith(
          activeId: e.id,
          composerText: '',
          isRecording: false,
          recordingLocked: false,
          recordingSeconds: 0,
          cancelProgress: 0,
          clearPlayingMessage: true,
          voicePaused: true,
          voiceProgress: 0,
          conversations: [
            for (final c in state.conversations)
              c.id == e.id ? c.copyWith(unread: 0) : c,
          ],
        ),
      );
    });
    on<ChatSearchChanged>(
      (e, emit) => emit(state.copyWith(searchQuery: e.query)),
    );
    on<ChatFilterChanged>((e, emit) => emit(state.copyWith(filter: e.filter)));
    on<ChatComposerChanged>(
      (e, emit) => emit(state.copyWith(composerText: e.text)),
    );
    on<ChatTextSent>((e, emit) {
      final text = state.composerText.trim();
      if (text.isEmpty) return;
      final id = state.activeId;
      _append(emit, id, _outgoing(MessageKind.text, text: text));
      emit(
        state.copyWith(composerText: '', typingIds: {...state.typingIds, id}),
      );
      // Debounce the simulated reply: rapid sends produce one reply, and every
      // callback retains its conversation identity when the user changes chats.
      _replyTimers[id]?.cancel();
      _replyTimers[id] = Timer(const Duration(milliseconds: 2100), () {
        if (!isClosed) add(ChatReplyArrived(id));
      });
    });
    on<ChatMediaSent>(
      (e, emit) => _append(
        emit,
        state.activeId,
        _outgoing(
          e.kind,
          text: e.kind == MessageKind.document
              ? 'Weekend-plan.pdf'
              : 'Thought you’d like this.',
          asset: e.kind == MessageKind.image
              ? 'assets/images/sylhet_evening.png'
              : null,
        ),
      ),
    );
    on<ChatDeliveryAdvanced>((e, emit) {
      final thread = state.threads[e.chatId];
      if (thread == null) return;
      emit(
        state.copyWith(
          conversations: thread.isNotEmpty && thread.last.id == e.messageId
              ? [
                  for (final c in state.conversations)
                    c.id == e.chatId ? c.copyWith(delivery: e.stage) : c,
                ]
              : state.conversations,
          threads: {
            ...state.threads,
            e.chatId: [
              for (final m in thread)
                m.id == e.messageId ? m.copyWith(delivery: e.stage) : m,
            ],
          },
        ),
      );
    });
    on<ChatReplyArrived>((e, emit) {
      _append(
        emit,
        e.chatId,
        RelayMessage(
          id: _id('reply'),
          senderId: e.chatId,
          sentAt: DateTime.now(),
          kind: MessageKind.text,
          text: 'I’ll tell you the rest when I see you.',
        ),
      );
      emit(state.copyWith(typingIds: {...state.typingIds}..remove(e.chatId)));
    });
    on<ChatVoiceToggled>(_togglePlayback);
    on<ChatVoiceSeeked>((e, emit) {
      if (state.playingMessageId != e.id) _voiceTimer?.cancel();
      emit(
        state.copyWith(
          playingMessageId: e.id,
          voiceProgress: e.progress.clamp(0.0, 1.0).toDouble(),
          voicePaused: state.playingMessageId != e.id
              ? true
              : state.voicePaused,
        ),
      );
      _playbackClock.reset();
    });
    on<ChatVoiceTicked>((e, emit) {
      if (state.voicePaused || state.playingMessageId == null) return;
      final message = state.messages
          .where((m) => m.id == state.playingMessageId)
          .firstOrNull;
      if (message == null) return;
      final elapsed = _playbackClock.elapsedMicroseconds / 1000000;
      _playbackClock.reset();
      final duration = message.duration.inMilliseconds / 1000;
      final next =
          state.voiceProgress +
          elapsed * state.voiceSpeed / (duration > 0 ? duration : 1);
      if (next >= 1) {
        _voiceTimer?.cancel();
        emit(state.copyWith(voiceProgress: 1, voicePaused: true));
      } else {
        emit(state.copyWith(voiceProgress: next));
      }
    });
    on<ChatVoiceSpeedChanged>(
      (e, emit) => emit(
        state.copyWith(
          voiceSpeed: switch (state.voiceSpeed) {
            1 => 1.5,
            1.5 => 2,
            _ => 1,
          },
        ),
      ),
    );
    on<ChatRecordingStarted>((e, emit) {
      if (state.isRecording) return;
      _voiceTimer?.cancel();
      _recordingTimer?.cancel();
      emit(
        state.copyWith(
          isRecording: true,
          recordingLocked: false,
          recordingSeconds: 0,
          cancelProgress: 0,
          voicePaused: true,
        ),
      );
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isClosed) add(const ChatRecordingTicked());
      });
    });
    on<ChatRecordingTicked>((e, emit) {
      if (state.isRecording) {
        emit(state.copyWith(recordingSeconds: state.recordingSeconds + 1));
      }
    });
    on<ChatRecordingDragged>((e, emit) {
      if (!state.isRecording || state.recordingLocked) return;
      emit(
        state.copyWith(
          cancelProgress: e.cancelProgress.clamp(0.0, 1.0).toDouble(),
        ),
      );
    });
    on<ChatRecordingLocked>((e, emit) {
      if (state.isRecording) {
        emit(state.copyWith(recordingLocked: true, cancelProgress: 0));
      }
    });
    on<ChatRecordingReleased>((e, emit) {
      if (!state.isRecording || state.recordingLocked) return;
      if (state.cancelProgress >= .95) {
        _cancelRecording(emit);
      } else {
        _finishRecording(emit);
      }
    });
    on<ChatRecordingSent>((e, emit) {
      if (state.isRecording) _finishRecording(emit);
    });
    on<ChatRecordingCancelled>((e, emit) => _cancelRecording(emit));
    on<ChatHistoryCleared>((e, emit) {
      _replyTimers.remove(state.activeId)?.cancel();
      _voiceTimer?.cancel();
      _recordingTimer?.cancel();
      emit(
        state.copyWith(
          threads: {...state.threads, state.activeId: []},
          isRecording: false,
          recordingLocked: false,
          clearPlayingMessage: true,
          voicePaused: true,
          typingIds: {...state.typingIds}..remove(state.activeId),
        ),
      );
    });
    on<ChatMuteToggled>(
      (e, emit) => emit(
        state.copyWith(
          conversations: [
            for (final c in state.conversations)
              c.id == state.activeId ? c.copyWith(muted: !c.muted) : c,
          ],
        ),
      ),
    );
    on<ChatGroupCreated>((e, emit) {
      final c = Conversation(
        id: e.id,
        name: e.name,
        avatarAsset: null,
        lastMessage: 'You created this group',
        timeLabel: 'Now',
        isGroup: true,
      );
      emit(
        state.copyWith(
          conversations: [...state.conversations, c],
          threads: {...state.threads, e.id: []},
        ),
      );
    });
  }
  Timer? _voiceTimer, _recordingTimer;
  final _deliveryTimers = <Timer>{};
  final _replyTimers = <String, Timer>{};
  final _playbackClock = Stopwatch();
  int _sequence = 0;
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  RelayMessage _outgoing(
    MessageKind kind, {
    String? text,
    String? asset,
    Duration duration = Duration.zero,
  }) => RelayMessage(
    id: _id('local'),
    senderId: 'me',
    sentAt: DateTime.now(),
    kind: kind,
    text: text,
    asset: asset,
    duration: duration,
    isMine: true,
    delivery: DeliveryStage.sending,
  );
  void _append(Emitter<ChatState> emit, String chatId, RelayMessage message) {
    final preview = switch (message.kind) {
      MessageKind.text => message.text ?? '',
      MessageKind.image => 'Photo',
      MessageKind.voice => 'Voice message',
      MessageKind.document => message.text ?? 'Document',
    };
    emit(
      state.copyWith(
        threads: {
          ...state.threads,
          chatId: [...?state.threads[chatId], message],
        },
        conversations: [
          for (final c in state.conversations)
            c.id == chatId
                ? c.copyWith(
                    lastMessage: preview,
                    previewKind: message.kind,
                    timeLabel: 'Now',
                    delivery: message.isMine ? message.delivery : null,
                    clearDelivery: !message.isMine,
                    unread: !message.isMine && chatId != state.activeId
                        ? c.unread + 1
                        : c.unread,
                  )
                : c,
        ],
      ),
    );
    if (message.isMine) {
      for (final (delay, stage) in const [
        (320, DeliveryStage.sent),
        (800, DeliveryStage.delivered),
        (1400, DeliveryStage.read),
      ]) {
        late final Timer timer;
        timer = Timer(Duration(milliseconds: delay), () {
          _deliveryTimers.remove(timer);
          if (!isClosed) add(ChatDeliveryAdvanced(chatId, message.id, stage));
        });
        _deliveryTimers.add(timer);
      }
    }
  }

  void _togglePlayback(ChatVoiceToggled e, Emitter<ChatState> emit) {
    if (state.isRecording) return;
    _voiceTimer?.cancel();
    final same = state.playingMessageId == e.messageId;
    if (same && !state.voicePaused) {
      emit(state.copyWith(voicePaused: true));
      return;
    }
    emit(
      state.copyWith(
        playingMessageId: e.messageId,
        voicePaused: false,
        voiceProgress: same && state.voiceProgress < 1
            ? state.voiceProgress
            : 0,
      ),
    );
    _playbackClock
      ..reset()
      ..start();
    _voiceTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!isClosed) add(const ChatVoiceTicked());
    });
  }

  void _cancelRecording(Emitter<ChatState> emit) {
    _recordingTimer?.cancel();
    emit(
      state.copyWith(
        isRecording: false,
        recordingLocked: false,
        recordingSeconds: 0,
        cancelProgress: 0,
      ),
    );
  }

  void _finishRecording(Emitter<ChatState> emit) {
    final duration = Duration(
      seconds: state.recordingSeconds.clamp(1, 3599).toInt(),
    );
    _cancelRecording(emit);
    _append(
      emit,
      state.activeId,
      _outgoing(MessageKind.voice, duration: duration),
    );
  }

  @override
  Future<void> close() {
    _voiceTimer?.cancel();
    _recordingTimer?.cancel();
    _playbackClock.stop();
    for (final timer in _deliveryTimers) {
      timer.cancel();
    }
    for (final timer in _replyTimers.values) {
      timer.cancel();
    }
    return super.close();
  }
}
