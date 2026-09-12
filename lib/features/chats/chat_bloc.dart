import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/audio_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/notification_service.dart';
import 'chat_models.dart';
import 'demo_data.dart';
import 'repositories/i_chat_repository.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

final class _ChatAudioPlaybackTicked extends ChatEvent {
  const _ChatAudioPlaybackTicked({
    required this.progress,
    required this.isCompleted,
  });
  final double progress;
  final bool isCompleted;
  @override
  List<Object?> get props => [progress, isCompleted];
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

final class _ChatVoiceSendFailed extends ChatEvent {
  const _ChatVoiceSendFailed(this.chatId, this.messageId);
  final String chatId;
  final String messageId;
  @override
  List<Object?> get props => [chatId, messageId];
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
  const ChatOpened(this.id, {this.markAsRead = true});
  final String id;
  final bool markAsRead;
  @override
  List<Object?> get props => [id, markAsRead];
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

final class ChatTypingStatusChanged extends ChatEvent {
  const ChatTypingStatusChanged({
    required this.chatId,
    required this.isTyping,
  });
  final String chatId;
  final bool isTyping;
  @override
  List<Object?> get props => [chatId, isTyping];
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

final class ChatImagePicked extends ChatEvent {
  const ChatImagePicked(this.filePath, {this.caption});
  final String filePath;
  final String? caption;
  @override
  List<Object?> get props => [filePath, caption];
}

final class ChatMessageReactionToggled extends ChatEvent {
  const ChatMessageReactionToggled(this.chatId, this.messageId, this.reaction);
  final String chatId;
  final String messageId;
  final String reaction;
  @override
  List<Object?> get props => [chatId, messageId, reaction];
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

final class ChatIncomingNotificationCleared extends ChatEvent {
  const ChatIncomingNotificationCleared();
}

final class ChatNotificationReceived extends ChatEvent {
  const ChatNotificationReceived(this.payload);
  final NotificationPayload payload;
  @override
  List<Object?> get props => [payload];
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
  const ChatRecordingStarted({this.locked = false});
  final bool locked;
  @override
  List<Object?> get props => [locked];
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
  const ChatGroupCreated(
    this.id,
    this.name,
    this.members, {
    this.description,
    this.avatarUrl,
    this.adminId,
  });

  final String id;
  final String name;
  final List<String> members;
  final String? description;
  final String? avatarUrl;
  final String? adminId;

  @override
  List<Object?> get props => [id, name, members, description, avatarUrl, adminId];
}

final class ChatGroupInfoUpdated extends ChatEvent {
  const ChatGroupInfoUpdated({
    required this.groupId,
    this.name,
    this.description,
    this.avatarUrl,
  });

  final String groupId;
  final String? name;
  final String? description;
  final String? avatarUrl;

  @override
  List<Object?> get props => [groupId, name, description, avatarUrl];
}

final class ChatGroupMemberPromoted extends ChatEvent {
  const ChatGroupMemberPromoted({
    required this.groupId,
    required this.targetUserId,
  });

  final String groupId;
  final String targetUserId;

  @override
  List<Object?> get props => [groupId, targetUserId];
}

final class ChatGroupMemberDemoted extends ChatEvent {
  const ChatGroupMemberDemoted({
    required this.groupId,
    required this.targetUserId,
  });

  final String groupId;
  final String targetUserId;

  @override
  List<Object?> get props => [groupId, targetUserId];
}

final class ChatGroupMembersAdded extends ChatEvent {
  const ChatGroupMembersAdded({
    required this.groupId,
    required this.newMembers,
  });

  final String groupId;
  final List<RelayContact> newMembers;

  @override
  List<Object?> get props => [groupId, newMembers];
}

final class ChatGroupMemberRemoved extends ChatEvent {
  const ChatGroupMemberRemoved({
    required this.groupId,
    required this.targetUserId,
  });

  final String groupId;
  final String targetUserId;

  @override
  List<Object?> get props => [groupId, targetUserId];
}

final class ChatGroupLeft extends ChatEvent {
  const ChatGroupLeft({
    required this.groupId,
    required this.currentUserId,
  });

  final String groupId;
  final String currentUserId;

  @override
  List<Object?> get props => [groupId, currentUserId];
}

final class ChatReplyTargetSet extends ChatEvent {
  const ChatReplyTargetSet(this.message);
  final RelayMessage? message;
  @override
  List<Object?> get props => [message];
}

final class ChatLocateMessageRequested extends ChatEvent {
  const ChatLocateMessageRequested(this.messageId);
  final String messageId;
  @override
  List<Object?> get props => [messageId];
}

final class ChatHighlightCleared extends ChatEvent {
  const ChatHighlightCleared();
}

enum MessageDeleteMode {
  forMe,
  forEveryone,
}

final class ChatMessageDeleted extends ChatEvent {
  const ChatMessageDeleted({
    required this.chatId,
    required this.messageId,
    this.mode = MessageDeleteMode.forMe,
  });
  final String chatId;
  final String messageId;
  final MessageDeleteMode mode;

  @override
  List<Object?> get props => [chatId, messageId, mode];
}

final class ChatConnectivityChanged extends ChatEvent {
  const ChatConnectivityChanged(this.status);
  final NetworkStatus status;

  @override
  List<Object?> get props => [status];
}

final class ChatOutboxFlushRequested extends ChatEvent {
  const ChatOutboxFlushRequested();
}

final class ChatRetryOutboxItem extends ChatEvent {
  const ChatRetryOutboxItem(this.messageId);
  final String messageId;

  @override
  List<Object?> get props => [messageId];
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
    this.replyingTo,
    this.highlightedMessageId,
    this.networkStatus = NetworkStatus.online,
    this.outboxQueue = const [],
    this.incomingNotification,
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
  final RelayMessage? replyingTo;
  final String? highlightedMessageId;
  final NetworkStatus networkStatus;
  final List<OutboxItem> outboxQueue;
  final NotificationPayload? incomingNotification;
  List<RelayMessage> get messages => threads[activeId] ?? const [];
  bool get typing => typingIds.contains(activeId);
  List<Conversation> get filteredConversations {
    final q = searchQuery.trim().toLowerCase();
    return conversations
        .where((c) {
          final matchesFilter = switch (filter) {
            InboxFilter.all => true,
            InboxFilter.unread => c.unread > 0,
            InboxFilter.favorites => c.pinned,
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
    RelayMessage? replyingTo,
    bool clearReplyingTo = false,
    String? highlightedMessageId,
    bool clearHighlightedMessage = false,
    NetworkStatus? networkStatus,
    List<OutboxItem>? outboxQueue,
    NotificationPayload? incomingNotification,
    bool clearIncomingNotification = false,
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
    replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
    highlightedMessageId: clearHighlightedMessage
        ? null
        : (highlightedMessageId ?? this.highlightedMessageId),
    networkStatus: networkStatus ?? this.networkStatus,
    outboxQueue: outboxQueue ?? this.outboxQueue,
    incomingNotification: clearIncomingNotification
        ? null
        : (incomingNotification ?? this.incomingNotification),
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
    replyingTo,
    highlightedMessageId,
    networkStatus,
    outboxQueue,
    incomingNotification,
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
    IAudioService? audioService,
    IConnectivityService? connectivityService,
    INotificationService? notificationService,
  })  : _chatRepository = chatRepository,
        _currentUserId = currentUserId,
        _demoMode = demoMode ?? (chatRepository == null),
        _connectivityService = connectivityService,
        _notificationService = notificationService,
        _audioService = audioService ??
            (((demoMode ?? (chatRepository == null)) ||
                    Platform.environment.containsKey('FLUTTER_TEST'))
                ? NoOpAudioService()
                : RelayAudioService()),
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
    if (_connectivityService != null) {
      _connectivitySubscription = _connectivityService.statusStream.listen((status) {
        if (!isClosed) add(ChatConnectivityChanged(status));
      });
    }

    _notificationOpenedSubscription =
        _notificationService?.onNotificationOpened.listen((payload) {
      if (!isClosed && payload.chatId.isNotEmpty) {
        add(ChatOpened(payload.chatId));
      }
    });

    on<ChatIncomingNotificationCleared>((e, emit) {
      emit(state.copyWith(clearIncomingNotification: true));
    });

    on<ChatNotificationReceived>((e, emit) {
      emit(state.copyWith(incomingNotification: e.payload));
    });

    _audioPositionSubscription = _audioService.positionStream.listen((pos) {
      if (state.playingMessageId != null) {
        final msg = state.messages
            .where((m) => m.id == state.playingMessageId)
            .firstOrNull;
        if (msg != null && msg.duration.inMilliseconds > 0) {
          final p = (pos.inMilliseconds / msg.duration.inMilliseconds).clamp(0.0, 1.0);
          add(_ChatAudioPlaybackTicked(progress: p, isCompleted: p >= 1.0));
        }
      }
    });

    _audioStateSubscription = _audioService.playerStateStream.listen((ps) {
      if (ps == PlayerState.completed) {
        add(const _ChatAudioPlaybackTicked(progress: 1.0, isCompleted: true));
      }
    });

    on<_ChatAudioPlaybackTicked>((e, emit) {
      if (e.isCompleted) {
        _voiceTimer?.cancel();
        emit(state.copyWith(voiceProgress: 1.0, voicePaused: true));
      } else {
        emit(state.copyWith(voiceProgress: e.progress));
      }
    });

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
      final activeTyping = <String>{};
      for (final conv in e.conversations) {
        if (conv.isPeerTyping) {
          activeTyping.add(conv.id);
          if (conv.recipientId != null && conv.recipientId!.isNotEmpty) {
            activeTyping.add(conv.recipientId!);
          }
        }
      }

      NotificationPayload? incomingNotification;
      if (state.conversations.isNotEmpty && _currentUserId != null) {
        final previousUnreads = {
          for (final c in state.conversations) c.id: c.unread,
        };
        final previousTimes = {
          for (final c in state.conversations) c.id: c.lastMessageAt,
        };
        final previousMessages = {
          for (final c in state.conversations) c.id: c.lastMessage,
        };

        for (final conv in e.conversations) {
          final prevUnread = previousUnreads[conv.id] ?? 0;
          final prevTime = previousTimes[conv.id];
          final prevMsg = previousMessages[conv.id];

          final isIncoming = conv.lastMessageSenderId != null &&
              conv.lastMessageSenderId != _currentUserId;
          final isNewMessage = (conv.unread > prevUnread) ||
              (isIncoming &&
                  (conv.lastMessageAt != prevTime ||
                      conv.lastMessage != prevMsg));

          if (isNewMessage && conv.id != state.activeId && !conv.muted) {
            incomingNotification = NotificationPayload(
              id: '${conv.id}_${DateTime.now().millisecondsSinceEpoch}',
              chatId: conv.id,
              title: conv.name,
              body: conv.lastMessage,
              avatarUrl: conv.avatarAsset,
              timestamp: conv.lastMessageAt ?? DateTime.now(),
            );
            break;
          }
        }
      }

      final sanitizedConvs = [
        for (final c in e.conversations)
          (c.lastMessageSenderId != null && c.lastMessageSenderId == _currentUserId)
              ? (c.unread != 0 ? c.copyWith(unread: 0) : c)
              : c,
      ];

      emit(
        state.copyWith(
          conversations: sanitizedConvs,
          typingIds: activeTyping,
          incomingNotification: incomingNotification,
        ),
      );
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
      final currentMessages = state.threads[e.chatId] ?? const [];
      final now = DateTime.now();
      final snapshotIds = e.messages.map((message) => message.id).toSet();
      // Send completion can arrive before the snapshot includes our message.
      final pendingSending = currentMessages.where(
        (m) =>
            (m.delivery == DeliveryStage.sending ||
                (m.delivery == DeliveryStage.sent && m.isMine)) &&
            !snapshotIds.contains(m.id) &&
            now.difference(m.sentAt) < const Duration(seconds: 30),
      );
      final filteredMessages = e.messages
          .where((m) => !_deletedForMeMessageIds.contains(m.id));
      final merged = [...filteredMessages, ...pendingSending]
          .where((m) => !_deletedForMeMessageIds.contains(m.id))
          .toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

      NotificationPayload? incomingNotification;
      if (e.chatId != state.activeId && _currentUserId != null && currentMessages.isNotEmpty) {
        final existingIds = currentMessages.map((m) => m.id).toSet();
        final brandNewIncoming = e.messages.where(
          (m) => !existingIds.contains(m.id) && m.senderId != _currentUserId,
        );
        if (brandNewIncoming.isNotEmpty) {
          final latest = brandNewIncoming.last;
          final conv = state.conversations.where((c) => c.id == e.chatId).firstOrNull;
          if (conv == null || !conv.muted) {
            incomingNotification = NotificationPayload(
              id: latest.id,
              chatId: e.chatId,
              title: conv?.name ?? 'Relay',
              body: latest.text ??
                  (latest.kind == MessageKind.voice
                      ? 'Voice note'
                      : 'Photo attachment'),
              avatarUrl: conv?.avatarAsset,
              timestamp: latest.sentAt,
            );
          }
        }
      }

      emit(
        state.copyWith(
          threads: {
            ...state.threads,
            e.chatId: merged,
          },
          incomingNotification: incomingNotification,
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
        if (e.markAsRead) {
          _chatRepository.markConversationRead(
            chatId: effectiveChatId,
            readerUserId: _currentUserId!,
          );
        }

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
          clearReplyingTo: true,
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

    on<ChatReplyTargetSet>((e, emit) {
      emit(
        state.copyWith(
          replyingTo: e.message,
          clearReplyingTo: e.message == null,
        ),
      );
    });

    on<ChatLocateMessageRequested>((e, emit) {
      _highlightTimer?.cancel();
      emit(state.copyWith(highlightedMessageId: e.messageId));
      _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!isClosed) {
          add(const ChatHighlightCleared());
        }
      });
    });

    on<ChatHighlightCleared>((e, emit) {
      emit(state.copyWith(clearHighlightedMessage: true));
    });

    on<ChatMessageDeleted>((e, emit) async {
      final currentList = state.threads[e.chatId] ??
          (state.activeId == e.chatId ? state.messages : const <RelayMessage>[]);
      final currentUserId = _currentUserId;

      if (e.mode == MessageDeleteMode.forMe) {
        _deletedForMeMessageIds.add(e.messageId);
        final updatedList =
            currentList.where((m) => m.id != e.messageId).toList();
        emit(
          state.copyWith(
            threads: {...state.threads, e.chatId: updatedList},
            clearHighlightedMessage: state.highlightedMessageId == e.messageId,
            clearReplyingTo: state.replyingTo?.id == e.messageId,
          ),
        );

        if (_chatRepository != null && !_demoMode && currentUserId != null) {
          try {
            await _chatRepository.deleteMessageForMe(
              chatId: e.chatId,
              messageId: e.messageId,
              userId: currentUserId,
            );
          } catch (_) {}
        }
      } else {
        final updatedList = currentList.map((m) {
          if (m.id == e.messageId) {
            return m.copyWith(
              isDeleted: true,
              text: 'You deleted this message',
              audioUrl: null,
              audioData: null,
              imageUrl: null,
              imageData: null,
              waveform: null,
            );
          }
          return m;
        }).toList();

        emit(
          state.copyWith(
            threads: {...state.threads, e.chatId: updatedList},
            clearHighlightedMessage: state.highlightedMessageId == e.messageId,
            clearReplyingTo: state.replyingTo?.id == e.messageId,
          ),
        );

        if (_chatRepository != null && !_demoMode && currentUserId != null) {
          try {
            await _chatRepository.deleteMessageForEveryone(
              chatId: e.chatId,
              messageId: e.messageId,
              userId: currentUserId,
            );
          } catch (_) {}
        }
      }
    });

    on<ChatClosed>((e, emit) async {
      final effectiveChatId = (_currentUserId != null &&
              !e.id.startsWith('chat_') &&
              !e.id.startsWith('group_') &&
              e.id.isNotEmpty)
          ? Conversation.directChatId(_currentUserId!, e.id)
          : e.id;

      _typingDebounceTimer?.cancel();
      _updateTypingStatus(effectiveChatId, false);

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
    on<ChatTypingStatusChanged>((e, emit) {
      _typingDebounceTimer?.cancel();
      _updateTypingStatus(e.chatId, e.isTyping);
    });
    on<ChatComposerChanged>(
      (e, emit) {
        emit(state.copyWith(composerText: e.text));
        if (_chatRepository != null &&
            _currentUserId != null &&
            state.activeId.isNotEmpty) {
          if (e.text.trim().isNotEmpty) {
            _updateTypingStatus(state.activeId, true);
            _typingDebounceTimer?.cancel();
            _typingDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
              _updateTypingStatus(state.activeId, false);
            });
          } else {
            _typingDebounceTimer?.cancel();
            _updateTypingStatus(state.activeId, false);
          }
        }
      },
    );
    on<ChatTextSent>((e, emit) async {
      final text = state.composerText.trim();
      if (text.isEmpty) return;
      final id = state.activeId;
      final replySnippet = _formatReplySnippet(state.replyingTo);
      final replyTargetId = state.replyingTo?.id;

      _typingDebounceTimer?.cancel();
      _updateTypingStatus(id, false);

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
          replyTo: replySnippet,
          replyToId: replyTargetId,
          delivery: DeliveryStage.sending,
          isMine: true,
        );

        _appendLocal(emit, effectiveChatId, outgoing);
        if (id != effectiveChatId) {
          _appendLocal(emit, id, outgoing);
        }
        emit(state.copyWith(composerText: '', clearReplyingTo: true));

        final outboxItem = OutboxItem(
          chatId: effectiveChatId,
          message: outgoing,
          recipientPublicKey: conv?.recipientPublicKey ?? '',
          queuedAt: DateTime.now(),
        );

        if (state.networkStatus != NetworkStatus.online) {
          emit(state.copyWith(outboxQueue: [...state.outboxQueue, outboxItem]));
          return;
        }

        final repo = _chatRepository;
        final messageId = outgoing.id;
        final peerKey = conv?.recipientPublicKey ?? '';

        repo.sendMessage(
          chatId: effectiveChatId,
          message: outgoing,
          recipientPublicKey: peerKey,
        ).then((_) {
          if (!isClosed) {
            add(ChatDeliveryAdvanced(effectiveChatId, messageId, DeliveryStage.sent));
            if (id != effectiveChatId) {
              add(ChatDeliveryAdvanced(id, messageId, DeliveryStage.sent));
            }
          }
        }).catchError((_) {
          if (!isClosed) {
            emit(state.copyWith(outboxQueue: [...state.outboxQueue, outboxItem]));
          }
        });
        return;
      }

      _append(
        emit,
        id,
        _outgoing(
          MessageKind.text,
          text: text,
          replyTo: replySnippet,
          replyToId: replyTargetId,
        ),
      );
      emit(
        state.copyWith(
          composerText: '',
          clearReplyingTo: true,
          typingIds: {...state.typingIds, id},
        ),
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
    on<ChatImagePicked>((e, emit) async {
      final localPath = e.filePath;
      final caption = e.caption;
      final id = state.activeId;
      final replySnippet = _formatReplySnippet(state.replyingTo);
      final replyTargetId = state.replyingTo?.id;

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

        final messageId = _id('msg');
        final outgoing = RelayMessage(
          id: messageId,
          senderId: _currentUserId!,
          recipientId: recipientId,
          sentAt: DateTime.now(),
          kind: MessageKind.image,
          text: caption,
          asset: localPath,
          replyTo: replySnippet,
          replyToId: replyTargetId,
          delivery: DeliveryStage.sending,
          isMine: true,
        );

        _appendLocal(emit, effectiveChatId, outgoing);
        if (id != effectiveChatId) {
          _appendLocal(emit, id, outgoing);
        }
        emit(state.copyWith(clearReplyingTo: true));

        final repo = _chatRepository;
        final peerKey = conv?.recipientPublicKey ?? '';
        final outboxItem = OutboxItem(
          chatId: effectiveChatId,
          message: outgoing,
          recipientPublicKey: peerKey,
          queuedAt: DateTime.now(),
        );

        if (state.networkStatus != NetworkStatus.online) {
          emit(state.copyWith(outboxQueue: [...state.outboxQueue, outboxItem]));
          return;
        }

        repo.sendImageMessage(
          chatId: effectiveChatId,
          localFilePath: localPath,
          recipientPublicKey: peerKey,
          caption: caption,
          messageId: messageId,
          replyTo: replySnippet,
          replyToId: replyTargetId,
        ).then((_) {
          if (!isClosed) {
            add(ChatDeliveryAdvanced(effectiveChatId, messageId, DeliveryStage.sent));
            if (id != effectiveChatId) {
              add(ChatDeliveryAdvanced(id, messageId, DeliveryStage.sent));
            }
          }
        }).catchError((_) {
          if (!isClosed) {
            emit(state.copyWith(outboxQueue: [...state.outboxQueue, outboxItem]));
          }
        });
        return;
      }

      // Demo mode fallback
      _append(
        emit,
        id,
        _outgoing(
          MessageKind.image,
          text: caption ?? 'Photo',
          asset: localPath,
          replyTo: replySnippet,
          replyToId: replyTargetId,
        ),
      );
      emit(state.copyWith(clearReplyingTo: true));
    });
    on<ChatMessageReactionToggled>((e, emit) async {
      final userId = _currentUserId ?? 'me';
      final effectiveChatId = (_currentUserId != null &&
              !e.chatId.startsWith('chat_') &&
              !e.chatId.startsWith('group_') &&
              e.chatId.isNotEmpty)
          ? Conversation.directChatId(_currentUserId!, e.chatId)
          : e.chatId;

      final thread = state.threads[effectiveChatId] ?? state.threads[e.chatId];
      if (thread == null) return;

      final message = thread.where((m) => m.id == e.messageId).firstOrNull;
      final isRemoving = message?.reactions?[userId] == e.reaction;

      final updatedThread = thread.map((m) {
        if (m.id != e.messageId) return m;
        final currentReactions = {...?m.reactions};
        if (isRemoving) {
          currentReactions.remove(userId);
        } else {
          currentReactions[userId] = e.reaction;
        }
        return m.copyWith(reactions: currentReactions);
      }).toList();

      emit(state.copyWith(
        threads: {
          ...state.threads,
          effectiveChatId: updatedThread,
          if (effectiveChatId != e.chatId) e.chatId: updatedThread,
        },
      ));

      if (_chatRepository != null && _currentUserId != null) {
        try {
          await _chatRepository.setMessageReaction(
            chatId: effectiveChatId,
            messageId: e.messageId,
            userId: userId,
            reaction: isRemoving ? null : e.reaction,
          );
        } catch (_) {}
      }
    });
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
            for (final entry in state.threads.entries)
              entry.key: [
                for (final m in entry.value)
                  m.id == e.messageId ? m.copyWith(delivery: e.stage) : m,
              ],
          },
        ),
      );
    });
    on<_ChatVoiceSendFailed>((e, emit) {
      emit(
        state.copyWith(
          threads: {
            for (final entry in state.threads.entries)
              entry.key: [
                for (final m in entry.value)
                  if (m.id != e.messageId) m,
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
    on<ChatVoiceSeeked>((e, emit) async {
      if (state.playingMessageId != e.id) {
        _voiceTimer?.cancel();
        await _audioService.stop();
      }
      final message = state.messages
          .where((m) => m.id == e.id)
          .firstOrNull;
      if (message != null && message.duration.inMilliseconds > 0) {
        final targetMs = (message.duration.inMilliseconds * e.progress).round();
        await _audioService.seek(Duration(milliseconds: targetMs));
      }
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
    on<ChatVoiceSpeedChanged>((e, emit) async {
      final nextSpeed = switch (state.voiceSpeed) {
        1.0 => 1.5,
        1.5 => 2.0,
        _ => 1.0,
      };
      await _audioService.setPlaybackRate(nextSpeed);
      emit(state.copyWith(voiceSpeed: nextSpeed));
    });
    on<ChatRecordingStarted>((e, emit) async {
      if (state.isRecording) return;
      _voiceTimer?.cancel();
      _recordingTimer?.cancel();
      await _audioService.stop();
      emit(
        state.copyWith(
          isRecording: true,
          recordingLocked: e.locked,
          recordingSeconds: 0,
          cancelProgress: 0,
          voicePaused: true,
        ),
      );
      try {
        await _audioService.startRecording();
      } catch (_) {
        emit(
          state.copyWith(
            isRecording: false,
            recordingLocked: false,
            recordingSeconds: 0,
            cancelProgress: 0,
          ),
        );
        return;
      }
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
    on<ChatRecordingReleased>((e, emit) async {
      if (!state.isRecording || state.recordingLocked) return;
      if (state.cancelProgress >= .95) {
        await _cancelRecording(emit);
      } else {
        await _finishRecording(emit);
      }
    });
    on<ChatRecordingSent>((e, emit) async {
      if (state.isRecording) await _finishRecording(emit);
    });
    on<ChatRecordingCancelled>((e, emit) async => _cancelRecording(emit));
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
    on<ChatGroupCreated>((e, emit) async {
      final effectiveAdminId = e.adminId ?? _currentUserId ?? 'current_user';
      final allParticipants = <String>{effectiveAdminId, ...e.members}.toList();
      final c = Conversation(
        id: e.id,
        name: e.name,
        description: e.description,
        avatarAsset: e.avatarUrl,
        lastMessage: 'You created this group',
        timeLabel: 'Now',
        lastMessageAt: DateTime.now(),
        participantIds: allParticipants,
        isGroup: true,
        adminIds: [effectiveAdminId],
      );
      emit(
        state.copyWith(
          conversations: [...state.conversations, c],
          threads: {...state.threads, e.id: []},
          activeId: e.id,
        ),
      );

      if (_chatRepository != null && !_demoMode) {
        try {
          await _chatRepository.createGroupConversation(
            groupId: e.id,
            name: e.name,
            memberIds: e.members,
            adminId: effectiveAdminId,
            description: e.description,
            avatarUrl: e.avatarUrl,
          );
        } catch (_) {}
      }
    });

    on<ChatGroupInfoUpdated>((e, emit) async {
      final updatedConvs = state.conversations.map((c) {
        if (c.id != e.groupId) return c;
        return c.copyWith(
          name: (e.name != null && e.name!.trim().isNotEmpty)
              ? e.name!.trim()
              : c.name,
          description: e.description ?? c.description,
          avatarAsset: e.avatarUrl ?? c.avatarAsset,
        );
      }).toList();

      emit(state.copyWith(conversations: updatedConvs));

      if (e.name != null && e.name!.trim().isNotEmpty) {
        _emitSystemMessage(emit, e.groupId, 'Group name changed to "${e.name!.trim()}"');
      } else if (e.description != null) {
        _emitSystemMessage(emit, e.groupId, 'Group description updated');
      } else if (e.avatarUrl != null) {
        _emitSystemMessage(emit, e.groupId, 'Group photo updated');
      }

      if (_chatRepository != null && !_demoMode) {
        try {
          await _chatRepository.updateGroupInfo(
            groupId: e.groupId,
            name: e.name,
            description: e.description,
            avatarUrl: e.avatarUrl,
          );
        } catch (_) {}
      }
    });

    on<ChatGroupMemberPromoted>((e, emit) async {
      final updatedConvs = state.conversations.map((c) {
        if (c.id != e.groupId) return c;
        final currentAdmins = List<String>.from(c.adminIds);
        if (!currentAdmins.contains(e.targetUserId)) {
          currentAdmins.add(e.targetUserId);
        }
        return c.copyWith(adminIds: currentAdmins);
      }).toList();

      emit(state.copyWith(conversations: updatedConvs));

      final targetConv = state.conversations.where((c) => c.id == e.groupId).firstOrNull;
      final targetName = targetConv?.participantNames?[e.targetUserId] ?? 'A member';
      _emitSystemMessage(emit, e.groupId, '$targetName was appointed as an admin');

      if (_chatRepository != null && !_demoMode) {
        try {
          await _chatRepository.promoteToAdmin(
            groupId: e.groupId,
            targetUserId: e.targetUserId,
          );
        } catch (_) {}
      }
    });

    on<ChatGroupMemberDemoted>((e, emit) async {
      final updatedConvs = state.conversations.map((c) {
        if (c.id != e.groupId) return c;
        final currentAdmins =
            c.adminIds.where((id) => id != e.targetUserId).toList();
        return c.copyWith(adminIds: currentAdmins);
      }).toList();

      emit(state.copyWith(conversations: updatedConvs));

      final targetConv = state.conversations.where((c) => c.id == e.groupId).firstOrNull;
      final targetName = targetConv?.participantNames?[e.targetUserId] ?? 'A member';
      _emitSystemMessage(emit, e.groupId, '$targetName was dismissed as an admin');

      if (_chatRepository != null && !_demoMode) {
        try {
          await _chatRepository.demoteAdmin(
            groupId: e.groupId,
            targetUserId: e.targetUserId,
          );
        } catch (_) {}
      }
    });

    on<ChatGroupMembersAdded>((e, emit) async {
      final updatedConvs = state.conversations.map((c) {
        if (c.id != e.groupId) return c;
        final currentParticipants = List<String>.from(c.participantIds);
        final currentNames = Map<String, String>.from(c.participantNames ?? {});
        for (final m in e.newMembers) {
          if (!currentParticipants.contains(m.id)) {
            currentParticipants.add(m.id);
          }
          currentNames[m.id] = m.displayName;
        }
        return c.copyWith(
          participantIds: currentParticipants,
          participantNames: currentNames,
        );
      }).toList();

      emit(state.copyWith(conversations: updatedConvs));

      final names = e.newMembers.map((m) => m.displayName).join(', ');
      _emitSystemMessage(emit, e.groupId, 'Added $names');

      if (_chatRepository != null && !_demoMode) {
        try {
          await _chatRepository.addGroupMembers(
            groupId: e.groupId,
            newMembers: e.newMembers,
          );
        } catch (_) {}
      }
    });

    on<ChatGroupMemberRemoved>((e, emit) async {
      final updatedConvs = state.conversations.map((c) {
        if (c.id != e.groupId) return c;
        final currentParticipants =
            c.participantIds.where((id) => id != e.targetUserId).toList();
        final currentAdmins =
            c.adminIds.where((id) => id != e.targetUserId).toList();
        return c.copyWith(
          participantIds: currentParticipants,
          adminIds: currentAdmins,
        );
      }).toList();

      emit(state.copyWith(conversations: updatedConvs));

      final targetConv = state.conversations.where((c) => c.id == e.groupId).firstOrNull;
      final targetName = targetConv?.participantNames?[e.targetUserId] ?? 'A member';
      _emitSystemMessage(emit, e.groupId, '$targetName was removed from the group');

      if (_chatRepository != null && !_demoMode) {
        try {
          await _chatRepository.removeGroupMember(
            groupId: e.groupId,
            targetUserId: e.targetUserId,
          );
        } catch (_) {}
      }
    });

    on<ChatGroupLeft>((e, emit) async {
      final updatedConvs =
          state.conversations.where((c) => c.id != e.groupId).toList();
      emit(state.copyWith(conversations: updatedConvs));

      _emitSystemMessage(emit, e.groupId, 'You left the group');

      if (_chatRepository != null && !_demoMode) {
        try {
          await _chatRepository.leaveGroup(
            groupId: e.groupId,
            currentUserId: e.currentUserId,
          );
        } catch (_) {}
      }
    });

    on<ChatConnectivityChanged>((e, emit) {
      final wasOffline = state.networkStatus != NetworkStatus.online;
      emit(state.copyWith(networkStatus: e.status));
      if (wasOffline && e.status == NetworkStatus.online && state.outboxQueue.isNotEmpty) {
        add(const ChatOutboxFlushRequested());
      }
    });

    on<ChatOutboxFlushRequested>((e, emit) async {
      if (state.outboxQueue.isEmpty || _chatRepository == null) return;

      final pending = List<OutboxItem>.from(state.outboxQueue);
      final remaining = <OutboxItem>[];

      for (final item in pending) {
        try {
          if (item.message.kind == MessageKind.image && item.message.asset != null) {
            await _chatRepository.sendImageMessage(
              chatId: item.chatId,
              localFilePath: item.message.asset!,
              recipientPublicKey: item.recipientPublicKey,
              caption: item.message.text,
              messageId: item.message.id,
              replyTo: item.message.replyTo,
              replyToId: item.message.replyToId,
            );
          } else if (item.message.kind == MessageKind.voice && item.message.asset != null) {
            await _chatRepository.sendVoiceMessage(
              chatId: item.chatId,
              localFilePath: item.message.asset!,
              duration: item.message.duration,
              waveform: item.message.waveform ?? [],
              recipientPublicKey: item.recipientPublicKey,
              messageId: item.message.id,
              replyTo: item.message.replyTo,
              replyToId: item.message.replyToId,
            );
          } else {
            await _chatRepository.sendMessage(
              chatId: item.chatId,
              message: item.message,
              recipientPublicKey: item.recipientPublicKey,
            );
          }
          add(ChatDeliveryAdvanced(item.chatId, item.message.id, DeliveryStage.sent));
        } catch (_) {
          remaining.add(item.copyWith(
            attempts: item.attempts + 1,
            lastAttemptAt: DateTime.now(),
          ));
        }
      }

      emit(state.copyWith(outboxQueue: remaining));
    });

    on<ChatRetryOutboxItem>((e, emit) {
      add(const ChatOutboxFlushRequested());
    });
  }

  final IConnectivityService? _connectivityService;
  StreamSubscription<NetworkStatus>? _connectivitySubscription;
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

  void _emitSystemMessage(Emitter<ChatState> emit, String groupId, String text) {
    _sequence++;
    final sysMsg = RelayMessage(
      id: 'sys_${DateTime.now().millisecondsSinceEpoch}_$_sequence',
      senderId: _currentUserId ?? 'system',
      senderName: 'System',
      recipientId: groupId,
      sentAt: DateTime.now(),
      kind: MessageKind.system,
      text: text,
      delivery: DeliveryStage.sent,
    );

    final currentThread = state.threads[groupId] ?? state.messages;
    final updatedThread = [...currentThread, sysMsg];

    emit(
      state.copyWith(
        threads: {
          ...state.threads,
          groupId: updatedThread,
        },
        conversations: [
          for (final c in state.conversations)
            c.id == groupId
                ? c.copyWith(
                    lastMessage: text,
                    previewKind: MessageKind.system,
                    lastMessageAt: sysMsg.sentAt,
                  )
                : c,
        ],
      ),
    );
  }

  void _appendLocal(Emitter<ChatState> emit, String chatId, RelayMessage message) {
    final durationSeconds = message.duration.inSeconds;
    final durationMinutes = message.duration.inMinutes;
    final secondsRem = durationSeconds % 60;
    final timeStr = '$durationMinutes:${secondsRem.toString().padLeft(2, '0')}';

    final preview = switch (message.kind) {
      MessageKind.text => message.text ?? '',
      MessageKind.image => 'Photo',
      MessageKind.voice => 'Voice message · $timeStr',
      MessageKind.document => message.text ?? 'Document',
      MessageKind.system => message.text ?? 'System update',
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
    List<double>? waveform,
    String? audioUrl,
    String? replyTo,
    String? replyToId,
  }) => RelayMessage(
    id: _id('local'),
    senderId: 'me',
    sentAt: DateTime.now(),
    kind: kind,
    text: text,
    asset: asset,
    duration: duration,
    waveform: waveform,
    audioUrl: audioUrl,
    replyTo: replyTo,
    replyToId: replyToId,
    isMine: true,
    delivery: DeliveryStage.sending,
  );

  String? _formatReplySnippet(RelayMessage? message) {
    if (message == null) return null;
    if (message.text != null && message.text!.trim().isNotEmpty) {
      return message.text!.trim();
    }
    return switch (message.kind) {
      MessageKind.image => 'Photo',
      MessageKind.voice => 'Voice note',
      MessageKind.document => 'Document',
      MessageKind.system => 'System update',
      MessageKind.text => 'Message',
    };
  }
  void _append(Emitter<ChatState> emit, String chatId, RelayMessage message) {
    final preview = switch (message.kind) {
      MessageKind.text => message.text ?? '',
      MessageKind.image => 'Photo',
      MessageKind.voice => 'Voice message',
      MessageKind.document => message.text ?? 'Document',
      MessageKind.system => message.text ?? 'System update',
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

  Future<void> _togglePlayback(ChatVoiceToggled e, Emitter<ChatState> emit) async {
    if (state.isRecording) return;
    _voiceTimer?.cancel();
    final same = state.playingMessageId == e.messageId;
    if (same && !state.voicePaused) {
      await _audioService.pause();
      emit(state.copyWith(voicePaused: true));
      return;
    }
    if (same && state.voicePaused) {
      await _audioService.resume();
      emit(state.copyWith(voicePaused: false));
      _playbackClock.start();
      _voiceTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (!isClosed) add(const ChatVoiceTicked());
      });
      return;
    }

    final message = state.messages
        .where((m) => m.id == e.messageId)
        .firstOrNull;

    emit(
      state.copyWith(
        playingMessageId: e.messageId,
        voicePaused: false,
        voiceProgress: same && state.voiceProgress < 1
            ? state.voiceProgress
            : 0,
      ),
    );

    if (message != null) {
      String? localPlayablePath;
      if (message.asset != null && File(message.asset!).existsSync()) {
        localPlayablePath = message.asset;
      } else if ((message.audioUrl != null && message.audioUrl!.isNotEmpty) ||
          (message.audioData != null && message.audioData!.isNotEmpty)) {
        final repo = _chatRepository;
        if (repo != null) {
          final conv = state.conversations
              .where((c) => c.id == state.activeId || c.recipientId == state.activeId)
              .firstOrNull;
          final peerKey = conv?.recipientPublicKey ?? '';
          try {
            localPlayablePath = await repo.getOrDownloadVoiceAudio(
              chatId: state.activeId,
              messageId: message.id,
              audioUrl: message.audioUrl ?? '',
              audioData: message.audioData,
              peerPublicKey: peerKey,
              nonce: message.nonce ?? '',
            );
          } catch (_) {}
        }
      }

      if (localPlayablePath != null) {
        await _audioService.play(localPlayablePath);
        await _audioService.setPlaybackRate(state.voiceSpeed);
        return;
      }
    }

    // Fallback simulation timer for demo mode and mock messages
    _playbackClock
      ..reset()
      ..start();
    _voiceTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!isClosed) add(const ChatVoiceTicked());
    });
  }

  Future<void> _cancelRecording(Emitter<ChatState> emit) async {
    _recordingTimer?.cancel();
    await _audioService.cancelRecording().catchError((_) {});
    emit(
      state.copyWith(
        isRecording: false,
        recordingLocked: false,
        recordingSeconds: 0,
        cancelProgress: 0,
      ),
    );
  }

  Future<void> _finishRecording(Emitter<ChatState> emit) async {
    final timerDuration = Duration(
      seconds: state.recordingSeconds.clamp(1, 3599).toInt(),
    );
    _recordingTimer?.cancel();
    emit(
      state.copyWith(
        isRecording: false,
        recordingLocked: false,
        recordingSeconds: 0,
        cancelProgress: 0,
      ),
    );

    final result = await _audioService.stopRecording().catchError((_) => null);
    final duration = (result != null && result.duration.inSeconds > 0)
        ? result.duration
        : timerDuration;
    final waveform = result?.waveform;
    final localPath = result?.path;

    final repo = _chatRepository;
    final userId = _currentUserId;
    final id = state.activeId;
    if (repo != null && userId != null && id.isNotEmpty) {
      final conv = state.conversations
          .where((c) => c.id == id || c.recipientId == id)
          .firstOrNull;

      final effectiveChatId = (id.startsWith('chat_') || id.startsWith('group_'))
          ? id
          : (conv != null && conv.id.startsWith('chat_')
              ? conv.id
              : Conversation.directChatId(userId, id));

      final recipientId = conv?.recipientId ??
          (effectiveChatId.startsWith('chat_')
              ? effectiveChatId
                  .replaceFirst('chat_', '')
                  .split('_')
                  .where((u) => u != userId)
                  .firstOrNull
              : null);

      final peerKey = conv?.recipientPublicKey ?? '';
      final messageId = _id('msg');
      final replySnippet = _formatReplySnippet(state.replyingTo);
      final replyTargetId = state.replyingTo?.id;

      final outgoing = RelayMessage(
        id: messageId,
        senderId: userId,
        recipientId: recipientId,
        sentAt: DateTime.now(),
        kind: MessageKind.voice,
        duration: duration,
        waveform: waveform,
        asset: localPath,
        replyTo: replySnippet,
        replyToId: replyTargetId,
        delivery: DeliveryStage.sending,
        isMine: true,
      );

      _appendLocal(emit, effectiveChatId, outgoing);
      if (id != effectiveChatId) {
        _appendLocal(emit, id, outgoing);
      }
      emit(state.copyWith(clearReplyingTo: true));

      if (localPath != null) {
        repo.sendVoiceMessage(
          chatId: effectiveChatId,
          messageId: messageId,
          localFilePath: localPath,
          duration: duration,
          waveform: waveform ?? const [],
          recipientPublicKey: peerKey,
          replyTo: replySnippet,
          replyToId: replyTargetId,
        ).then((_) {
          if (!isClosed) {
            add(ChatDeliveryAdvanced(effectiveChatId, messageId, DeliveryStage.sent));
            if (id != effectiveChatId) {
              add(ChatDeliveryAdvanced(id, messageId, DeliveryStage.sent));
            }
          }
        }).catchError((_) {
          if (!isClosed) {
            add(_ChatVoiceSendFailed(effectiveChatId, messageId));
            if (id != effectiveChatId) {
              add(_ChatVoiceSendFailed(id, messageId));
            }
          }
        });
      }
    } else {
      final replySnippet = _formatReplySnippet(state.replyingTo);
      final replyTargetId = state.replyingTo?.id;
      _appendLocal(
        emit,
        state.activeId,
        _outgoing(
          MessageKind.voice,
          duration: duration,
          waveform: waveform,
          asset: localPath,
          replyTo: replySnippet,
          replyToId: replyTargetId,
        ),
      );
      emit(state.copyWith(clearReplyingTo: true));
    }
  }

  final Set<String> _deletedForMeMessageIds = {};
  Timer? _typingDebounceTimer;
  Timer? _highlightTimer;
  bool _isCurrentUserTyping = false;

  void _updateTypingStatus(String chatId, bool isTyping) {
    if (_isCurrentUserTyping == isTyping) return;
    _isCurrentUserTyping = isTyping;
    final repo = _chatRepository;
    final userId = _currentUserId;
    if (repo != null && userId != null && chatId.isNotEmpty) {
      repo.setTypingStatus(
        chatId: chatId,
        userId: userId,
        isTyping: isTyping,
      ).catchError((_) {});
    }
  }

  final IAudioService _audioService;
  final INotificationService? _notificationService;
  Stream<double> get liveAmplitudeStream => _audioService.liveAmplitudeStream;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<PlayerState>? _audioStateSubscription;
  StreamSubscription<NotificationPayload>? _notificationOpenedSubscription;

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    _notificationOpenedSubscription?.cancel();
    _audioPositionSubscription?.cancel();
    _audioStateSubscription?.cancel();
    _audioService.dispose();
    _typingDebounceTimer?.cancel();
    _highlightTimer?.cancel();
    if (_isCurrentUserTyping && state.activeId.isNotEmpty) {
      _updateTypingStatus(state.activeId, false);
    }
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
