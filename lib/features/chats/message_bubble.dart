import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/motion/relay_motion.dart';
import '../../core/services/audio_service.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_emoji_picker.dart';
import '../../core/widgets/relay_toast.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';
import 'relay_receipt.dart';
import 'views/media_viewer_page.dart';
import 'widgets/message_context_menu.dart';
import 'widgets/relay_message_image.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.grouped = false,
    this.isHighlighted = false,
    this.showSenderAttribution = false,
    this.senderDisplayName,
  });

  final bool grouped;
  final bool isHighlighted;
  final bool showSenderAttribution;
  final String? senderDisplayName;

  final RelayMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.isMine;
    final isVoice = message.kind == MessageKind.voice;
    final bubbleColor = mine
        ? scheme.secondaryContainer
        : (isVoice ? scheme.surfaceContainerHigh : scheme.surface);
    final foreground =
        mine ? scheme.onSecondaryContainer : scheme.onSurface;

    final reactionCounts = <String, int>{};
    if (message.reactions != null) {
      for (final r in message.reactions!.values) {
        reactionCounts[r] = (reactionCounts[r] ?? 0) + 1;
      }
    }

    final bubbleBorderRadius = BorderRadius.only(
      topLeft: const Radius.circular(19),
      topRight: const Radius.circular(19),
      bottomLeft: Radius.circular(mine ? 19 : 5),
      bottomRight: Radius.circular(mine ? 5 : 19),
    );

    // MessageBubble itself is intentionally static. Its parent AnimatedList
    // animates only a genuinely inserted row; delivery and playback rebuilds do
    // not make the entire history slide in again.
    return _SwipeToReplyWrapper(
      message: message,
      onReply: (msg) {
        if (!message.isDeleted) {
          context.read<ChatBloc>().add(ChatReplyTargetSet(msg));
        }
      },
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: mine ? 54 : 18,
            right: mine ? 18 : 54,
            top: grouped ? 0 : 7,
            bottom: (reactionCounts.isNotEmpty && !message.isDeleted) ? 14 : 4,
          ),
          child: Builder(
            builder: (bubbleContext) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _showAnchoredReactions(bubbleContext, message, mine),
                  onDoubleTap: message.isDeleted
                      ? null
                      : () => _quickHeartReaction(context, message),
                  child: _BubbleHighlightWrapper(
                    isHighlighted: isHighlighted,
                    borderRadius: bubbleBorderRadius,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.sizeOf(context).width *
                            (message.kind == MessageKind.image ? .72 : .79),
                      ),
                      padding: message.kind == MessageKind.image && !message.isDeleted
                          ? const EdgeInsets.all(4)
                          : const EdgeInsets.fromLTRB(14, 10, 12, 8),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: bubbleBorderRadius,
                        border: mine || isVoice
                            ? null
                            : Border.all(
                                color: Theme.of(context).dividerColor.withValues(alpha: .72),
                                width: .65,
                              ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showSenderAttribution && !mine)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3.5),
                              child: Text(
                                senderDisplayName ?? message.senderName ?? 'Member',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _getAuthorColor(message.senderId),
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          if (message.isDeleted)
                            _DeletedMessage(
                              message: message,
                              foreground: foreground,
                            )
                          else
                            switch (message.kind) {
                              MessageKind.text => _TextMessage(
                                message: message,
                                foreground: foreground,
                              ),
                              MessageKind.image => _ImageMessage(
                                message: message,
                                foreground: foreground,
                                onLongPress: () => _showAnchoredReactions(bubbleContext, message, mine),
                              ),
                              MessageKind.voice => _VoiceMessage(
                                message: message,
                                foreground: foreground,
                              ),
                              MessageKind.document => _DocumentMessage(
                                message: message,
                                foreground: foreground,
                              ),
                              MessageKind.system => _TextMessage(
                                message: message,
                                foreground: foreground,
                              ),
                            },
                        ],
                      ),
                    ),
                  ),
                ),
                if (reactionCounts.isNotEmpty && !message.isDeleted)
                  Positioned(
                    bottom: -8,
                    right: mine ? 6 : null,
                    left: mine ? null : 6,
                    child: GestureDetector(
                      onTap: () => _showAnchoredReactions(bubbleContext, message, mine),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final entry in reactionCounts.entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  entry.value > 1
                                      ? '${entry.key} ${entry.value}'
                                      : entry.key,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

  void _quickHeartReaction(BuildContext context, RelayMessage message) {
    HapticFeedback.lightImpact();
    final bloc = context.read<ChatBloc>();
    final chatId = bloc.state.activeId;
    final myId = bloc.currentUserId ?? 'me';
    const heart = '\u{2764}\u{FE0F}';
    final current = message.reactions?[myId];
    final next = current == heart ? null : heart;
    bloc.add(ChatMessageReactionToggled(chatId, message.id, next ?? heart));
  }

  static Color _getAuthorColor(String senderId) {
    const palette = [
      Color(0xFF2563EB), // Blue
      Color(0xFF059669), // Emerald
      Color(0xFFD97706), // Amber
      Color(0xFF7C3AED), // Purple
      Color(0xFFDB2777), // Pink
      Color(0xFF0891B2), // Cyan
      Color(0xFFEA580C), // Orange
      Color(0xFF4F46E5), // Indigo
    ];
    if (senderId.isEmpty) return palette[0];
    final hash = senderId.codeUnits.fold(0, (acc, c) => acc + c);
    return palette[hash % palette.length];
  }

  Future<void> _showAnchoredReactions(
    BuildContext bubbleContext,
    RelayMessage message,
    bool mine,
  ) async {
    HapticFeedback.mediumImpact();
    final renderBox = bubbleContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final bubbleOffset = renderBox.localToGlobal(Offset.zero);
    final bubbleSize = renderBox.size;
    final bloc = bubbleContext.read<ChatBloc>();
    final chatId = bloc.state.activeId;
    final myId = bloc.currentUserId ?? 'me';
    final currentReaction = message.reactions?[myId];

    final action = await Navigator.of(bubbleContext, rootNavigator: true).push<MessageContextAction>(
      PageRouteBuilder<MessageContextAction>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.22),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (routeContext, animation, secondaryAnimation) {
          return MessageContextOverlay(
            bubbleOffset: bubbleOffset,
            bubbleSize: bubbleSize,
            mine: mine,
            message: message,
            animation: animation,
            currentReaction: message.isDeleted ? null : currentReaction,
            onReactionSelected: message.isDeleted ? null : (emoji) {
              Navigator.of(routeContext).pop(MessageContextAction.reaction);
              bloc.add(ChatMessageReactionToggled(chatId, message.id, emoji));
            },
            onMoreReactionsPressed: message.isDeleted ? null : () {
              Navigator.of(routeContext).pop(MessageContextAction.moreReactions);
            },
            onReplyPressed: message.isDeleted ? null : () {
              bloc.add(ChatReplyTargetSet(message));
            },
            onCopyPressed: message.isDeleted ? null : () {
              _copyMessageContent(bubbleContext, message);
            },
            onSharePressed: message.isDeleted ? null : () {
              _shareMessageContent(bubbleContext, message);
            },
            onInfoPressed: () {},
            onDeletePressed: () {},
          );
        },
      ),
    );

    if (!bubbleContext.mounted) return;

    switch (action) {
      case MessageContextAction.delete:
        _showDeleteDialog(bubbleContext, bloc, message);
        break;
      case MessageContextAction.info:
        _showMessageInfoSheet(bubbleContext, message);
        break;
      case MessageContextAction.moreReactions:
        _showFullEmojiPickerForReaction(bubbleContext, bloc, chatId, message);
        break;
      case MessageContextAction.reaction:
      case MessageContextAction.reply:
      case MessageContextAction.copy:
      case MessageContextAction.share:
      case null:
        break;
    }
  }

  void _copyMessageContent(BuildContext context, RelayMessage message) {
    HapticFeedback.lightImpact();
    final String textToCopy;
    switch (message.kind) {
      case MessageKind.text:
        textToCopy = message.text ?? '';
      case MessageKind.image:
        textToCopy = message.text?.isNotEmpty == true
            ? message.text!
            : (message.imageUrl ?? 'Photo');
      case MessageKind.voice:
        textToCopy = 'Voice note (${message.duration.inSeconds}s)';
      case MessageKind.document:
        textToCopy = message.text ?? 'Document';
      case MessageKind.system:
        textToCopy = message.text ?? 'System update';
    }
    Clipboard.setData(ClipboardData(text: textToCopy));
    RelayToast.show(
      context,
      message: 'Copied to clipboard',
      icon: CupertinoIcons.doc_on_doc,
    );
  }

  void _shareMessageContent(BuildContext context, RelayMessage message) {
    HapticFeedback.lightImpact();
    final text = message.text ?? message.imageUrl ?? 'Relay message';
    Clipboard.setData(ClipboardData(text: text));
    RelayToast.show(
      context,
      message: 'Link copied for sharing',
      icon: CupertinoIcons.share,
    );
  }

  void _showMessageInfoSheet(BuildContext context, RelayMessage message) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('MMM d, yyyy  HH:mm').format(message.sentAt);
    final deliveryLabel = switch (message.delivery) {
      DeliveryStage.sending => 'Sending',
      DeliveryStage.sent => 'Sent to server',
      DeliveryStage.delivered => 'Delivered to recipient',
      DeliveryStage.read => 'Read by recipient',
    };

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E2127) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle_fill,
                  color: RelayColors.coral,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Message Details',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow('Type', message.kind.name.toUpperCase(), dark),
            _infoRow('Sent', timeStr, dark),
            _infoRow('Status', deliveryLabel, dark),
            _infoRow('Security', 'End-to-End Encrypted (AES-256-GCM)', dark),
            _infoRow('ID', message.id, dark),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: dark ? Colors.white60 : Colors.black54,
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: dark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    ChatBloc bloc,
    RelayMessage message,
  ) {
    final activeChatId = bloc.state.activeId.isNotEmpty
        ? bloc.state.activeId
        : (message.recipientId ?? '');
    final conv = bloc.state.conversations
        .where((c) => c.id == activeChatId)
        .firstOrNull;
    final isGroupAdmin = conv != null &&
        conv.isGroup &&
        conv.adminIds.contains(bloc.currentUserId);
    final canDeleteForEveryone =
        (message.isMine || isGroupAdmin) && !message.isDeleted;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Delete Message?'),
        message: Text(
          canDeleteForEveryone
              ? 'You can delete this message for everyone in the chat or remove it from your device.'
              : 'This will remove the message from your device.',
        ),
        actions: [
          if (canDeleteForEveryone)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                bloc.add(
                  ChatMessageDeleted(
                    chatId: activeChatId,
                    messageId: message.id,
                    mode: MessageDeleteMode.forEveryone,
                  ),
                );
                RelayToast.show(
                  context,
                  message: 'Message deleted for everyone',
                  icon: CupertinoIcons.trash,
                );
              },
              child: const Text('Delete for everyone'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              bloc.add(
                ChatMessageDeleted(
                  chatId: activeChatId,
                  messageId: message.id,
                  mode: MessageDeleteMode.forMe,
                ),
              );
              RelayToast.show(
                context,
                message: 'Message deleted for you',
                icon: CupertinoIcons.trash,
              );
            },
            child: const Text('Delete for me'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showFullEmojiPickerForReaction(
    BuildContext context,
    ChatBloc bloc,
    String chatId,
    RelayMessage message,
  ) {
    final dummyController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerContext) => SizedBox(
        height: 340,
        child: RelayEmojiPicker(
          textEditingController: dummyController,
          onEmojiSelected: (category, emoji) {
            HapticFeedback.lightImpact();
            Navigator.pop(pickerContext);
            bloc.add(ChatMessageReactionToggled(chatId, message.id, emoji.emoji));
          },
        ),
      ),
    ).whenComplete(dummyController.dispose);
  }
}

class _DeletedMessage extends StatelessWidget {
  const _DeletedMessage({required this.message, required this.foreground});
  final RelayMessage message;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final textMuted = foreground.withValues(alpha: .70);
    final displayText = message.isMine
        ? 'You deleted this message'
        : (message.text?.isNotEmpty == true
            ? message.text!
            : 'This message was deleted');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          CupertinoIcons.slash_circle,
          size: 13.5,
          color: textMuted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            displayText,
            style: TextStyle(
              color: textMuted,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.35,
              letterSpacing: -.02,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          DateFormat('HH:mm').format(message.sentAt),
          style: TextStyle(
            color: textMuted.withValues(alpha: .85),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


class _TextMessage extends StatelessWidget {
  const _TextMessage({required this.message, required this.foreground});
  final RelayMessage message;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (message.replyTo != null) ...[
          _ReplyPreview(
            replyTo: message.replyTo!,
            foreground: foreground,
            onTap: () => _locateTargetMessage(context, message),
          ),
          const SizedBox(height: 8),
        ],
        _LinkedText(
          text: message.text ?? '',
          style: TextStyle(
            color: foreground,
            fontSize: 15,
            height: 1.42,
            letterSpacing: -.03,
          ),
        ),
        const SizedBox(height: 5),
        _MessageMeta(message: message, foreground: foreground),
      ],
    );
  }
}

class _ImageMessage extends StatelessWidget {
  const _ImageMessage({
    required this.message,
    required this.foreground,
    this.onLongPress,
  });
  final RelayMessage message;
  final Color foreground;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.replyTo != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: _ReplyPreview(
              replyTo: message.replyTo!,
              foreground: foreground,
              onTap: () => _locateTargetMessage(context, message),
            ),
          ),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => MediaViewerPage.open(
            context,
            message,
            heroTag: 'shared-image-${message.id}',
          ),
          onLongPress: onLongPress,
          child: Hero(
            tag: 'shared-image-${message.id}',
            createRectTween: (begin, end) =>
                MaterialRectCenterArcTween(begin: begin, end: end),
            flightShuttleBuilder: (
              flightContext,
              animation,
              flightDirection,
              fromHeroContext,
              toHeroContext,
            ) =>
                MediaViewerPage.buildFlightShuttle(
              animation,
              flightDirection,
              message,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: RelayMessageImage(message: message),
              ),
            ),
          ),
        ),
        if (message.text != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 0),
            child: Text(
              message.text!,
              style: TextStyle(color: foreground, fontSize: 14.5),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 6, 3),
          child: _MessageMeta(message: message, foreground: foreground),
        ),
      ],
    );
  }
}

class _VoiceMessage extends StatelessWidget {
  const _VoiceMessage({required this.message, required this.foreground});
  final RelayMessage message;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (a, b) =>
          a.playingMessageId != b.playingMessageId ||
          a.voiceProgress != b.voiceProgress ||
          a.voiceSpeed != b.voiceSpeed ||
          a.voicePaused != b.voicePaused,
      builder: (context, state) {
        final scheme = Theme.of(context).colorScheme;
        final selected = state.playingMessageId == message.id;
        final playing = selected && !state.voicePaused;
        final progress = selected ? state.voiceProgress : 0.0;
        return SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.replyTo != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReplyPreview(
                    replyTo: message.replyTo!,
                    foreground: foreground,
                    onTap: () => _locateTargetMessage(context, message),
                  ),
                ),
              ],
              Row(
                children: [
                  InkWell(
                    onTap: () => context.read<ChatBloc>().add(
                      ChatVoiceToggled(message.id),
                    ),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Semantics(
                        label: playing ? 'Pause voice note' : 'Play voice note',
                        button: true,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CustomPaint(
                              painter: _PlaybackGlyph(playing, scheme.onPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: LayoutBuilder(
                        builder: (context, bounds) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => context.read<ChatBloc>().add(
                            ChatVoiceSeeked(
                              message.id,
                              d.localPosition.dx / bounds.maxWidth,
                            ),
                          ),
                          onHorizontalDragUpdate: (d) =>
                              context.read<ChatBloc>().add(
                                ChatVoiceSeeked(
                                  message.id,
                                  d.localPosition.dx / bounds.maxWidth,
                                ),
                              ),
                          child: RepaintBoundary(
                            child: TweenAnimationBuilder<double>(
                              // BLoC owns playback truth; this tween fills the small
                              // gaps between state ticks so the waveform stays fluid.
                              tween: Tween(end: progress),
                              duration: RelayMotion.duration(
                                context,
                                const Duration(milliseconds: 80),
                              ),
                              curve: Curves.linear,
                              builder: (context, visualProgress, _) => CustomPaint(
                                  painter: WaveformPainter(
                                    progress: visualProgress,
                                    active: scheme.secondary,
                                    inactive: foreground.withValues(
                                      alpha: scheme.brightness == Brightness.dark
                                          ? .45
                                          : .52,
                                    ),
                                    seed: message.id.hashCode,
                                    waveform: message.waveform,
                                  ),
                                ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  GestureDetector(
                    onTap: () => context.read<ChatBloc>().add(
                      const ChatVoiceSpeedChanged(),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 44,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${state.voiceSpeed % 1 == 0 ? state.voiceSpeed.toInt() : state.voiceSpeed}×',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text(
                    playing
                        ? _duration(
                            Duration(
                              seconds:
                                  (message.duration.inSeconds * (1 - progress))
                                      .round(),
                            ),
                          )
                        : _duration(message.duration),
                    style: TextStyle(
                      color: foreground.withValues(alpha: .66),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _MessageMeta(message: message, foreground: foreground),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _duration(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({required this.message, required this.foreground});
  final RelayMessage message;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          DateFormat('HH:mm').format(message.sentAt),
          style: TextStyle(
            color: foreground.withValues(alpha: .70),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (message.isMine) ...[
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: RelayMotion.quick,
            child: RelayReceipt(
              stage: message.delivery,
              key: ValueKey(message.delivery),
              size: 14,
              color: foreground.withValues(alpha: .65),
            ),
          ),
        ],
      ],
    );
  }
}

class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.progress,
    required this.active,
    required this.inactive,
    required this.seed,
    this.waveform,
  });

  final double progress;
  final Color active;
  final Color inactive;
  final int seed;
  final List<double>? waveform;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 32;
    final gap = size.width / bars;
    final activeUntil = (bars * progress).round();
    final hasRealWaveform = waveform != null && waveform!.isNotEmpty;
    final resampled = hasRealWaveform
        ? (waveform!.length == bars
            ? waveform!
            : RelayAudioService.resampleWaveform(waveform!, bars))
        : null;

    for (var i = 0; i < bars; i++) {
      double wave;
      if (resampled != null) {
        wave = resampled[i];
      } else {
        wave = .24 +
            .72 *
                ((math.sin((i + seed) * .79).abs() * .55) +
                    (math.sin((i + 2) * .31).abs() * .45));
      }
      final height = size.height * wave.clamp(.16, .96).toDouble();
      final paint = Paint()
        ..color = i < activeUntil ? active : inactive
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      final x = gap * i + gap / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.inactive != inactive ||
      oldDelegate.seed != seed ||
      oldDelegate.waveform != waveform;
}


class _DocumentMessage extends StatelessWidget {
  const _DocumentMessage({required this.message, required this.foreground});
  final RelayMessage message;
  final Color foreground;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 236,
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 48,
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.doc, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text ?? 'Document',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF · 128 KB',
                    style: TextStyle(
                      color: foreground.withValues(alpha: .6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'View document',
              icon: const Icon(CupertinoIcons.arrow_down_circle, size: 22),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(message.text ?? 'Document'),
                  content: const Text(
                    'Saturday, 4 PM. Meet at the usual spot. Bring a camera.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: _MessageMeta(message: message, foreground: foreground),
        ),
      ],
    ),
  );
}

/// Recognizers are retained with the message and disposed when its text changes
/// or the row leaves the tree. Never allocate undisposed recognizers in build.
class _LinkedText extends StatefulWidget {
  const _LinkedText({required this.text, required this.style});
  final String text;
  final TextStyle style;
  @override
  State<_LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<_LinkedText> {
  final _recognizers = <TapGestureRecognizer>[];
  List<InlineSpan> _spans = [];
  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant _LinkedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _parse();
  }

  void _parse() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    var end = 0;
    for (final match in RegExp(r'https?://[^\s]+').allMatches(widget.text)) {
      spans.add(TextSpan(text: widget.text.substring(end, match.start)));
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () async {
          final uri = Uri.tryParse(url);
          if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
            return;
          }
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!opened && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This link could not be opened.')),
            );
          }
        };
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizer,
        ),
      );
      end = match.end;
    }
    spans.add(TextSpan(text: widget.text.substring(end)));
    _spans = spans;
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text.rich(TextSpan(children: _spans), style: widget.style);
}

class _PlaybackGlyph extends CustomPainter {
  const _PlaybackGlyph(this.playing, this.color);
  final bool playing;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    if (playing) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 3, 5, 18),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(14, 3, 5, 18),
          const Radius.circular(1),
        ),
        paint,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(6, 3)
          ..lineTo(21, 12)
          ..lineTo(6, 21)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlaybackGlyph oldDelegate) =>
      oldDelegate.playing != playing || oldDelegate.color != color;
}

void _locateTargetMessage(BuildContext context, RelayMessage message) {
  HapticFeedback.selectionClick();
  final chatBloc = context.read<ChatBloc>();
  String? targetId = message.replyToId;
  if (targetId == null || targetId.isEmpty) {
    final snippet = message.replyTo?.trim();
    if (snippet != null && snippet.isNotEmpty) {
      final match = chatBloc.state.messages.where((m) {
        if (m.text != null && m.text!.trim() == snippet) return true;
        if (m.kind == MessageKind.image &&
            (snippet == 'Photo' || (m.text?.trim() == snippet))) {
          return true;
        }
        if (m.kind == MessageKind.voice &&
            (snippet == 'Voice note' || snippet == 'Voice message')) {
          return true;
        }
        return false;
      }).firstOrNull;
      targetId = match?.id;
    }
  }
  if (targetId != null && targetId.isNotEmpty) {
    chatBloc.add(ChatLocateMessageRequested(targetId));
  }
}

class _BubbleHighlightWrapper extends StatefulWidget {
  const _BubbleHighlightWrapper({
    required this.isHighlighted,
    required this.borderRadius,
    required this.child,
  });

  final bool isHighlighted;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<_BubbleHighlightWrapper> createState() => _BubbleHighlightWrapperState();
}

class _BubbleHighlightWrapperState extends State<_BubbleHighlightWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 82,
      ),
    ]).animate(_controller);

    if (widget.isHighlighted) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant _BubbleHighlightWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final progress = _glowAnimation.value;
        return Stack(
          children: [
            child!,
            if (progress > 0.005)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: RelayColors.coral.withValues(alpha: 0.26 * progress),
                      borderRadius: widget.borderRadius,
                      border: Border.all(
                        color: RelayColors.coral.withValues(alpha: 0.85 * progress),
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.replyTo,
    required this.foreground,
    this.onTap,
  });

  final String replyTo;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: foreground.withValues(alpha: .12),
            width: .6,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(9),
                  bottomLeft: Radius.circular(9),
                ),
                child: Container(
                  width: 3,
                  color: RelayColors.coral,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.reply,
                            size: 11,
                            color: RelayColors.coral,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Reply',
                            style: TextStyle(
                              color: RelayColors.coral,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (onTap != null) ...[
                            const Spacer(),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 10,
                              color: foreground.withValues(alpha: .45),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        replyTo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: .85),
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeToReplyWrapper extends StatefulWidget {
  const _SwipeToReplyWrapper({
    required this.child,
    required this.message,
    required this.onReply,
  });

  final Widget child;
  final RelayMessage message;
  final ValueChanged<RelayMessage> onReply;

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _thresholdCrossed = false;

  static const double _threshold = 46.0;
  static const double _maxDrag = 70.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx < 0 && _dragOffset <= 0) {
      return;
    }
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx * 0.55).clamp(0.0, _maxDrag);
      if (_dragOffset >= _threshold && !_thresholdCrossed) {
        _thresholdCrossed = true;
        HapticFeedback.lightImpact();
      } else if (_dragOffset < _threshold && _thresholdCrossed) {
        _thresholdCrossed = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_thresholdCrossed) {
      widget.onReply(widget.message);
    }
    _thresholdCrossed = false;
    _runReturnAnimation();
  }

  void _onHorizontalDragCancel() {
    _thresholdCrossed = false;
    _runReturnAnimation();
  }

  void _runReturnAnimation() {
    _animation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final currentOffset =
            _controller.isAnimating ? _animation.value : _dragOffset;
        final progress = (currentOffset / _threshold).clamp(0.0, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            if (currentOffset > 2)
              Positioned(
                left: 10 + (currentOffset * 0.22),
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.6 + (progress * 0.4),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: progress >= 1.0
                            ? RelayColors.coral
                            : Theme.of(context)
                                .dividerColor
                                .withValues(alpha: .6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.reply,
                        size: 16,
                        color: progress >= 1.0
                            ? Colors.white
                            : Theme.of(context).iconTheme.color,
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(currentOffset, 0),
              child: child,
            ),
          ],
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onHorizontalDragCancel: _onHorizontalDragCancel,
        child: widget.child,
      ),
    );
  }
}
