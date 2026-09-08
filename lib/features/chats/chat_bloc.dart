import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'chat_models.dart';
import 'demo_data.dart';
import 'repositories/i_chat_repository.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

final class ChatStreamStarted extends ChatEvent {
  const ChatStreamStarted(this.userId);
  final String userId;
  @override
  List<Object?> get props => [userId];
}

final class _ChatConversationsUpdated extends ChatEvent {
  const _ChatConversationsUpdated(this.conversations);
  final List<Conversation> conversations;
  @override
  List<Object?> get props => [conversations];
}

final class _ChatMessagesUpdated extends ChatEvent {
  const _ChatMessagesUpdated(this.chatId, this.messages);
  final String chatId;
  final List<RelayMessage> messages;
  @override
  List<Object?> get props => [chatId, messages];
}

final class ChatDirectConversationStarted extends ChatEvent {
  const ChatDirectConversationStarted({
    required this.recipientUserId,
    required this.recipientName,
    this.recipientPublicKey,
  });
  final String recipientUserId;
  final String recipientName;
  final String? recipientPublicKey;
  @override
  List<Object?> get props => [recipientUserId, recipientName, recipientPublicKey];
}

final class ChatOpened extends ChatEvent {
  const ChatOpened(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

final class ChatClosed extends ChatEvent {
  const ChatClosed(this.id);
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
  ChatBloc({
    IChatRepository? chatRepository,
    String? currentUserId,
    bool? demoMode,
  })  : _chatRepository = chatRepository,
        _currentUserId = currentUserId,
        _demoMode = demoMode ?? (chatRepository == null),
        super(
          ChatState(
            conversations:
                (demoMode ?? (chatRepository == null)) ? DemoData.inbox() : const [],
            threads: (demoMode ?? (chatRepository == null))
                ? {
                    for (final c in DemoData.conversations)
                      c.id: DemoData.messagesFor(c.id),
                  }
                : const {},
            activeId: (demoMode ?? (chatRepository == null)) ? 'aisha' : '',
          ),
        ) {
    on<ChatStreamStarted>((e, emit) async {
      _currentUserId = e.userId;
      await _conversationsSubscription?.cancel();
      if (_chatRepository != null) {
        _conversationsSubscription = _chatRepository
            .watchConversations(e.userId)
            .listen((convs) {
          add(_ChatConversationsUpdated(convs));
        });
      }
    });

    on<_ChatConversationsUpdated>((e, emit) {
      emit(state.copyWith(conversations: e.conversations));
      if (_chatRepository != null && _currentUserId != null) {
        for (final conv in e.conversations) {
          if (conv.unread > 0 && conv.delivery == DeliveryStage.sent) {
            _chatRepository.markConversationDelivered(
              chatId: conv.id,
              recipientUserId: _currentUserId!,
            );
          }
        }
      }
    });

    on<_ChatMessagesUpdated>((e, emit) {
      emit(
        state.copyWith(
          threads: {
            ...state.threads,
            e.chatId: e.messages,
          },
        ),
      );
      if (_chatRepository != null && _currentUserId != null) {
        final isChatActive = state.activeId == e.chatId;
        for (final m in e.messages) {
          if (m.senderId != _currentUserId) {
            if (isChatActive) {
              if (m.delivery != DeliveryStage.read) {
                _chatRepository.updateDeliveryStatus(
                  chatId: e.chatId,
                  messageId: m.id,
                  status: DeliveryStage.read,
                );
              }
            } else {
              if (m.delivery == DeliveryStage.sent ||
                  m.delivery == DeliveryStage.sending) {
                _chatRepository.updateDeliveryStatus(
                  chatId: e.chatId,
                  messageId: m.id,
                  status: DeliveryStage.delivered,
                );
              }
            }
          }
        }
      }
    });

    on<ChatDirectConversationStarted>((e, emit) async {
      if (_chatRepository != null && _currentUserId != null) {
        try {
          final conv = await _chatRepository.getOrCreateDirectConversation(
            currentUserId: _currentUserId!,
            recipientUserId: e.recipientUserId,
            recipientName: e.recipientName,
            recipientPublicKey: e.recipientPublicKey,
          );
          emit(
            state.copyWith(
              conversations: [
                conv,
                for (final c in state.conversations)
                  if (c.id != conv.id) c,
              ],
            ),
          );
          add(ChatOpened(conv.id));
        } catch (_) {}
      }
    });

    on<ChatOpened>((e, emit) async {
      _voiceTimer?.cancel();
      _recordingTimer?.cancel();
      await _messagesSubscription?.cancel();
      final effectiveChatId = (_currentUserId != null &&
              !e.id.startsWith('chat_') &&
              !e.id.startsWith('group_') &&
              e.id.isNotEmpty)
          ? Conversation.directChatId(_currentUserId!, e.id)
          : e.id;

      if (_chatRepository != null && _currentUserId != null) {
        _chatRepository.markConversationRead(
          chatId: effectiveChatId,
          readerUserId: _currentUserId!,
        );

        _messagesSubscription = _chatRepository
            .watchMessages(effectiveChatId, _currentUserId!)
            .listen((msgs) {
          add(_ChatMessagesUpdated(effectiveChatId, msgs));
        });
      }
      emit(
        state.copyWith(
          activeId: effectiveChatId,
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
              (c.id == effectiveChatId || c.id == e.id)
                  ? c.copyWith(unread: 0)
                  : c,
          ],
        ),
      );
    });

    on<ChatClosed>((e, emit) async {
      final effectiveChatId = (_currentUserId != null &&
              !e.id.startsWith('chat_') &&
              !e.id.startsWith('group_') &&
              e.id.isNotEmpty)
          ? Conversation.directChatId(_currentUserId!, e.id)
          : e.id;

      if (state.activeId == effectiveChatId || state.activeId == e.id) {
        await _messagesSubscription?.cancel();
        _messagesSubscription = null;
        emit(state.copyWith(activeId: ''));
      }
    });
    on<ChatSearchChanged>(
      (e, emit) => emit(state.copyWith(searchQuery: e.query)),
    );
    on<ChatFilterChanged>((e, emit) => emit(state.copyWith(filter: e.filter)));
    on<ChatComposerChanged>(
      (e, emit) => emit(state.copyWith(composerText: e.text)),
    );
    on<ChatTextSent>((e, emit) async {
      final text = state.composerText.trim();
      if (text.isEmpty) return;
      final id = state.activeId;

      if (_chatRepository != null && _currentUserId != null) {
        final conv = state.conversations
            .where((c) => c.id == id || c.recipientId == id)
            .firstOrNull;

        final effectiveChatId = (id.startsWith('chat_') || id.startsWith('group_'))
            ? id
            : (conv != null && conv.id.startsWith('chat_')
                ? conv.id
                : Conversation.directChatId(_currentUserId!, id));

        final recipientId = conv?.recipientId ??
            (effectiveChatId.startsWith('chat_')
                ? effectiveChatId
                    .replaceFirst('chat_', '')
                    .split('_')
                    .where((u) => u != _currentUserId)
                    .firstOrNull
                : null);

        final outgoing = RelayMessage(
          id: _id('msg'),
          senderId: _currentUserId!,
          recipientId: recipientId,
          sentAt: DateTime.now(),
          kind: MessageKind.text,
          text: text,
          delivery: DeliveryStage.sending,
          isMine: true,
        );

        _appendLocal(emit, effectiveChatId, outgoing);
        if (id != effectiveChatId) {
          _appendLocal(emit, id, outgoing);
        }
        emit(state.copyWith(composerText: ''));

        try {
          await _chatRepository.sendMessage(
            chatId: effectiveChatId,
            message: outgoing,
            recipientPublicKey: conv?.recipientPublicKey ?? '',
          );
        } catch (_) {}
        return;
      }

      _append(emit, id, _outgoing(MessageKind.text, text: text));
      emit(
        state.copyWith(composerText: '', typingIds: {...state.typingIds, id}),
      );
      if (_demoMode) {
        _replyTimers[id]?.cancel();
        _replyTimers[id] = Timer(const Duration(milliseconds: 2100), () {
          if (!isClosed) add(ChatReplyArrived(id));
        });
      }
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

  final IChatRepository? _chatRepository;
  String? _currentUserId;
  String? get currentUserId => _currentUserId;
  final bool _demoMode;
  StreamSubscription<List<Conversation>>? _conversationsSubscription;
  StreamSubscription<List<RelayMessage>>? _messagesSubscription;
  Timer? _voiceTimer, _recordingTimer;
  final _deliveryTimers = <Timer>{};
  final _replyTimers = <String, Timer>{};
  final _playbackClock = Stopwatch();
  int _sequence = 0;

  void _appendLocal(Emitter<ChatState> emit, String chatId, RelayMessage message) {
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
                    delivery: message.delivery,
                  )
                : c,
        ],
      ),
    );
  }
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
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
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
