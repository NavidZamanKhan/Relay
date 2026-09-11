import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/motion/relay_motion.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';
import 'message_bubble.dart';

/// A bottom-anchored timeline with a small visual cache, never a second data
/// source. Messages stay chronological in BLoC and newest-first in this cache.
/// That lets reverse:true keep the latest edge at scroll offset ZERO, including
/// during keyboard resizing. No racing animateTo(maxScrollExtent) calls and no
/// second keyboard-padding animation are needed.
///
/// A BLoC update is reconciled by ID. Only newly appended IDs call insertItem(0).
/// Each new row expands from zero using RelayMotion.messageInsertion, smoothly
/// moving earlier rows. Receipts select their message by ID and never replay
/// an entrance. Clearing/replacing history replaces the AnimatedList key too:
/// its internal item count must always agree with our cache.
class RelayMessageList extends StatefulWidget {
  const RelayMessageList({
    super.key,
    required this.dateHeader,
    required this.typingIndicator,
  });
  final Widget dateHeader, typingIndicator;
  @override
  State<RelayMessageList> createState() => _RelayMessageListState();
}

class _RelayMessageListState extends State<RelayMessageList> {
  var _listKey = GlobalKey<AnimatedListState>();
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  late List<RelayMessage> _rows;
  double? _anchorPixels, _anchorMax;
  Timer? _anchorTimer;
  bool _correctionQueued = false;

  @override
  void initState() {
    super.initState();
    _rows = context.read<ChatBloc>().state.messages.reversed.toList();
  }

  @override
  void dispose() {
    _anchorTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _sync(ChatState next) {
    final ids = _rows.map((m) => m.id).toSet();
    final newIds = next.messages.map((m) => m.id).toSet();
    _itemKeys.removeWhere((id, _) => !newIds.contains(id));
    if (!newIds.containsAll(ids) || next.messages.length < _rows.length) {
      setState(() {
        _rows = next.messages.reversed.toList();
        _listKey = GlobalKey<AnimatedListState>();
      });
      return;
    }
    final added = next.messages.where((m) => !ids.contains(m.id)).toList();
    if (added.isEmpty) return; // receipt changes are handled by row selectors.
    final nearLatest = !_scroll.hasClients || _scroll.offset < 72;
    final outgoing = added.any((m) => m.isMine);
    if (!nearLatest && !outgoing && _scroll.hasClients) {
      // When reading history, compensate for exactly the height gained at the
      // latest edge. Metrics notifications arrive AFTER layout; corrections run
      // after the frame. A real user drag immediately releases this anchor.
      _anchorPixels ??= _scroll.offset;
      _anchorMax ??= _scroll.position.maxScrollExtent;
      _anchorTimer?.cancel();
      _anchorTimer = Timer(
        RelayMotion.messageInsert + const Duration(milliseconds: 80),
        () {
          _anchorPixels = null;
          _anchorMax = null;
        },
      );
    }
    for (final message in added) {
      _rows.insert(0, message);
      _listKey.currentState?.insertItem(
        0,
        duration: RelayMotion.duration(context, RelayMotion.messageInsert),
      );
    }
    if (outgoing && !nearLatest && _scroll.hasClients) {
      _anchorPixels = null;
      _anchorMax = null;
      _scroll.animateTo(
        0,
        duration: RelayMotion.duration(context, RelayMotion.standard),
        curve: RelayMotion.enter,
      );
    }
  }

  bool _metrics(ScrollMetricsNotification notification) {
    if (_anchorPixels != null && !_correctionQueued) {
      _correctionQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _correctionQueued = false;
        if (!mounted || !_scroll.hasClients || _anchorPixels == null) return;
        final target =
            _anchorPixels! + _scroll.position.maxScrollExtent - _anchorMax!;
        if ((_scroll.offset - target).abs() > .2) {
          _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
        }
      });
    }
    return false;
  }

  void _scrollToMessage(String targetId) {
    final index = _rows.indexWhere((m) => m.id == targetId);
    if (index == -1) return;

    final key = _itemKeys[targetId];
    final currentContext = key?.currentContext;

    if (currentContext != null) {
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: 0.5,
      );
    } else if (_scroll.hasClients) {
      // In reversed AnimatedList, index 0 is at offset 0 (bottom).
      const estimatedRowHeight = 78.0;
      final estimatedOffset = (index * estimatedRowHeight)
          .clamp(0.0, _scroll.position.maxScrollExtent);

      _scroll
          .animateTo(
            estimatedOffset,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
          )
          .then((_) {
            if (!mounted) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final targetContext = _itemKeys[targetId]?.currentContext;
              if (targetContext != null && mounted) {
                Scrollable.ensureVisible(
                  targetContext,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: 0.5,
                );
              }
            });
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ChatBloc, ChatState>(
          listenWhen: (a, b) => a.messages != b.messages,
          listener: (_, s) => _sync(s),
        ),
        BlocListener<ChatBloc, ChatState>(
          listenWhen: (a, b) =>
              a.highlightedMessageId != b.highlightedMessageId &&
              b.highlightedMessageId != null,
          listener: (_, s) {
            final targetId = s.highlightedMessageId;
            if (targetId != null) {
              _scrollToMessage(targetId);
            }
          },
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: _metrics,
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (n) {
                  if (n.dragDetails != null) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _anchorPixels = null;
                    _anchorMax = null;
                  }
                  return false;
                },
                child: AnimatedList(
                  key: _listKey,
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
                  initialItemCount: _rows.length,
                  itemBuilder: (context, index, animation) {
                    final m = _rows[index];
                    final older = index + 1 < _rows.length
                        ? _rows[index + 1]
                        : null;
                    final newDay =
                        older == null ||
                        !DateUtils.isSameDay(m.sentAt, older.sentAt);
                    final grouped =
                        older != null &&
                        older.senderId == m.senderId &&
                        m.sentAt.difference(older.sentAt).inMinutes.abs() < 4 &&
                        !newDay;
                    final itemKey = _itemKeys.putIfAbsent(m.id, () => GlobalKey());
                    final row = RepaintBoundary(
                      key: itemKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (newDay)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 10,
                                bottom: 20,
                              ),
                              child: Text(
                                _date(m.sentAt),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                      letterSpacing: .2,
                                    ),
                              ),
                            ),
                          _LiveMessage(fallback: m, grouped: grouped),
                        ],
                      ),
                    );
                    return RelayMotion.messageInsertion(
                      animation: animation,
                      isMine: m.isMine,
                      child: row,
                    );
                  },
                ),
              ),
            ),
          ),
          BlocSelector<ChatBloc, ChatState, bool>(
            selector: (s) => s.typing,
            builder: (context, typing) => AnimatedSize(
              duration: RelayMotion.duration(
                context,
                RelayMotion.messageInsert,
              ),
              curve: RelayMotion.messageEnter,
              alignment: Alignment.bottomLeft,
              child: typing
                  ? widget.typingIndicator
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Today';
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, yyyy').format(date);
  }
}

class _LiveMessage extends StatelessWidget {
  const _LiveMessage({required this.fallback, required this.grouped});
  final RelayMessage fallback;
  final bool grouped;
  @override
  Widget build(BuildContext context) =>
      BlocSelector<ChatBloc, ChatState, (RelayMessage, bool, bool, String?)>(
        selector: (s) {
          final m = s.messages.where((m) => m.id == fallback.id).firstOrNull ??
              fallback;
          final isHighlighted = s.highlightedMessageId == fallback.id;
          final activeConv =
              s.conversations.where((c) => c.id == s.activeId).firstOrNull;
          final isGroup = activeConv?.isGroup ?? false;
          final senderName =
              m.senderName ?? activeConv?.participantNames?[m.senderId];
          return (m, isHighlighted, isGroup, senderName);
        },
        builder: (_, data) => MessageBubble(
          message: data.$1,
          grouped: grouped,
          isHighlighted: data.$2,
          showSenderAttribution: data.$3 && !data.$1.isMine,
          senderDisplayName: data.$4,
        ),
      );
}
