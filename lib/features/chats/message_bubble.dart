import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/motion/relay_motion.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_emoji_picker.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';
import 'relay_receipt.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.grouped = false,
    this.isHighlighted = false,
  });

  final bool grouped;
  final bool isHighlighted;

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
        context.read<ChatBloc>().add(ChatReplyTargetSet(msg));
      },
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: mine ? 54 : 18,
            right: mine ? 18 : 54,
            top: grouped ? 0 : 7,
            bottom: reactionCounts.isNotEmpty ? 14 : 4,
          ),
          child: Builder(
            builder: (bubbleContext) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _showAnchoredReactions(bubbleContext, message, mine),
                  onDoubleTap: () => _quickHeartReaction(context, message),
                  child: _BubbleHighlightWrapper(
                    isHighlighted: isHighlighted,
                    borderRadius: bubbleBorderRadius,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.sizeOf(context).width *
                            (message.kind == MessageKind.image ? .72 : .79),
                      ),
                      padding: message.kind == MessageKind.image
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
                      child: switch (message.kind) {
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
                      },
                    ),
                  ),
                ),
                if (reactionCounts.isNotEmpty)
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

  void _showAnchoredReactions(
    BuildContext bubbleContext,
    RelayMessage message,
    bool mine,
  ) {
    HapticFeedback.mediumImpact();
    final renderBox = bubbleContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final bubbleOffset = renderBox.localToGlobal(Offset.zero);
    final bubbleSize = renderBox.size;
    final bloc = bubbleContext.read<ChatBloc>();
    final chatId = bloc.state.activeId;
    final myId = bloc.currentUserId ?? 'me';
    final currentReaction = message.reactions?[myId];

    Navigator.of(bubbleContext, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.18),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (routeContext, animation, secondaryAnimation) {
          return _AnchoredReactionOverlay(
            bubbleOffset: bubbleOffset,
            bubbleSize: bubbleSize,
            mine: mine,
            animation: animation,
            currentReaction: currentReaction,
            onReactionSelected: (emoji) {
              Navigator.of(routeContext).pop();
              bloc.add(ChatMessageReactionToggled(chatId, message.id, emoji));
            },
            onMorePressed: () {
              Navigator.of(routeContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showFullEmojiPickerForReaction(bubbleContext, bloc, chatId, message);
              });
            },
          );
        },
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
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
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

class _AnchoredReactionOverlay extends StatelessWidget {
  const _AnchoredReactionOverlay({
    required this.bubbleOffset,
    required this.bubbleSize,
    required this.mine,
    required this.animation,
    required this.currentReaction,
    required this.onReactionSelected,
    required this.onMorePressed,
  });

  final Offset bubbleOffset;
  final Size bubbleSize;
  final bool mine;
  final Animation<double> animation;
  final String? currentReaction;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback onMorePressed;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    const quickReactions = [
      '\u{2764}\u{FE0F}',
      '\u{1F44D}',
      '\u{1F602}',
      '\u{1F62E}',
      '\u{1F622}',
      '\u{1F64F}',
    ];

    const double barHeight = 48.0;
    const double barWidth = 296.0;
    const double gap = 8.0;
    const double screenMargin = 12.0;

    final minTop = padding.top + kToolbarHeight + 8.0;
    final maxBottom = screenSize.height - padding.bottom - 60.0;

    final placeAbove = (bubbleOffset.dy - barHeight - gap) >= minTop;
    double top;
    if (placeAbove) {
      top = bubbleOffset.dy - barHeight - gap;
    } else {
      top = bubbleOffset.dy + bubbleSize.height + gap;
      if (top + barHeight > maxBottom) {
        top = maxBottom - barHeight;
      }
    }

    double left;
    Alignment scaleAlignment;
    if (mine) {
      final bubbleRight = bubbleOffset.dx + bubbleSize.width;
      left = bubbleRight - barWidth;
      if (left + barWidth > screenSize.width - screenMargin) {
        left = screenSize.width - screenMargin - barWidth;
      }
      if (left < screenMargin) {
        left = screenMargin;
      }
      scaleAlignment = placeAbove ? Alignment.bottomRight : Alignment.topRight;
    } else {
      left = bubbleOffset.dx;
      if (left < screenMargin) {
        left = screenMargin;
      }
      if (left + barWidth > screenSize.width - screenMargin) {
        left = screenSize.width - screenMargin - barWidth;
      }
      scaleAlignment = placeAbove ? Alignment.bottomLeft : Alignment.topLeft;
    }

    final curvedAnim = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuad,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.45, end: 1.0).animate(curvedAnim),
              alignment: scaleAlignment,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF22242B) : Colors.white,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? 0.45 : 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 0.7,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emoji in quickReactions)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onReactionSelected(emoji);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentReaction == emoji
                                  ? RelayColors.coral.withValues(alpha: 0.22)
                                  : Colors.transparent,
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(
                                fontSize: 25,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      Container(
                        width: 1,
                        height: 22,
                        color: dark ? Colors.white24 : Colors.black12,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                      ),
                      IconButton(
                        tooltip: 'More reactions',
                        padding: const EdgeInsets.all(5),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(
                          CupertinoIcons.plus,
                          size: 20,
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onMorePressed();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          onTap: () => Navigator.of(context).push(
            PageRouteBuilder<void>(
              opaque: false,
              barrierColor: Colors.black.withValues(alpha: .92),
              pageBuilder: (_, animation, _) => _ImagePreview(
                message: message,
                heroTag: 'shared-image-${message.id}',
              ),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          onLongPress: onLongPress,
          child: Hero(
            tag: 'shared-image-${message.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _BubbleImage(message: message),
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

    for (var i = 0; i < bars; i++) {
      double wave;
      if (hasRealWaveform) {
        if (i < waveform!.length) {
          wave = waveform![i];
        } else {
          wave = 0.25;
        }
      } else {
        wave = .24 +
            .72 *
                ((math.sin((i + seed) * .79).abs() * .55) +
                    (math.sin((i + 2) * .31).abs() * .45));
      }
      final height = size.height * wave.clamp(.18, .96).toDouble();
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

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.message,
    required this.heroTag,
  });

  final RelayMessage message;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: heroTag,
                child: InteractiveViewer(
                  minScale: .8,
                  maxScale: 4,
                  child: _BubbleImage(
                    message: message,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .42),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(CupertinoIcons.clear, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleImage extends StatefulWidget {
  const _BubbleImage({
    required this.message,
    this.fit = BoxFit.cover,
  });

  final RelayMessage message;
  final BoxFit fit;

  @override
  State<_BubbleImage> createState() => _BubbleImageState();
}

class _BubbleImageState extends State<_BubbleImage> {
  String? _resolvedLocalPath;

  @override
  void initState() {
    super.initState();
    _checkPersistentLocalCache();
  }

  @override
  void didUpdateWidget(covariant _BubbleImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.asset != widget.message.asset ||
        oldWidget.message.imageUrl != widget.message.imageUrl ||
        oldWidget.message.imageData != widget.message.imageData) {
      _checkPersistentLocalCache();
    }
  }

  Future<void> _checkPersistentLocalCache() async {
    final msg = widget.message;
    // 1. Direct asset
    if (msg.asset != null && msg.asset!.isNotEmpty) {
      if (msg.asset!.startsWith('assets/')) {
        if (mounted) setState(() => _resolvedLocalPath = msg.asset);
        return;
      }
      try {
        final f = File(msg.asset!);
        if (f.existsSync()) {
          if (mounted) setState(() => _resolvedLocalPath = msg.asset);
          return;
        }
      } catch (_) {}
    }

    // 2. Persistent document directory cache
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final target = File('${docsDir.path}/relay_images/img_${msg.id}.jpg');
      if (await target.exists() && await target.length() > 0) {
        if (mounted) setState(() => _resolvedLocalPath = target.path);
        return;
      }
    } catch (_) {}

    // Fallback: If imageData is present, eagerly cache it to disk
    if (msg.imageData != null && msg.imageData!.isNotEmpty) {
      try {
        final rawBase64 = msg.imageData!.contains(',')
            ? msg.imageData!.split(',').last
            : msg.imageData!;
        final bytes = base64Decode(rawBase64);
        _cacheBytesToDocsDir(msg.id, bytes);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;

    // 1. If persistent local cache or existing asset path was resolved
    if (_resolvedLocalPath != null) {
      if (_resolvedLocalPath!.startsWith('assets/')) {
        return Image.asset(
          _resolvedLocalPath!,
          fit: widget.fit,
          cacheWidth: 1100,
          errorBuilder: (_, _, _) => _buildFallback(msg),
        );
      }
      try {
        final file = File(_resolvedLocalPath!);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: widget.fit,
            cacheWidth: 1100,
            errorBuilder: (_, _, _) => _buildFallback(msg),
          );
        }
      } catch (_) {}
    }

    // 2. Direct synchronous check for message.asset if it exists right now
    if (msg.asset != null && msg.asset!.isNotEmpty) {
      if (msg.asset!.startsWith('assets/')) {
        return Image.asset(
          msg.asset!,
          fit: widget.fit,
          cacheWidth: 1100,
          errorBuilder: (_, _, _) => _buildFallback(msg),
        );
      }
      try {
        final file = File(msg.asset!);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: widget.fit,
            cacheWidth: 1100,
            errorBuilder: (_, _, _) => _buildFallback(msg),
          );
        }
      } catch (_) {}
    }

    // 3. Fallback to Cloud Storage URL or inline base64
    return _buildFallback(msg);
  }

  Widget _buildFallback(RelayMessage msg) {
    // A. Network URL
    if (msg.imageUrl != null &&
        msg.imageUrl!.isNotEmpty &&
        msg.imageUrl!.startsWith('http')) {
      return Image.network(
        msg.imageUrl!,
        fit: widget.fit,
        cacheWidth: 1100,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            _cacheBase64IfAvailable(msg);
            return child;
          }
          return ColoredBox(
            color: RelayColors.ink.withValues(alpha: .12),
            child: const Center(
              child: SizedBox.square(
                dimension: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RelayColors.coral,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _buildBase64OrPlaceholder(msg),
      );
    }

    // B. Base64
    return _buildBase64OrPlaceholder(msg);
  }

  Widget _buildBase64OrPlaceholder(RelayMessage msg) {
    if (msg.imageData != null && msg.imageData!.isNotEmpty) {
      try {
        final rawBase64 = msg.imageData!.contains(',')
            ? msg.imageData!.split(',').last
            : msg.imageData!;
        final bytes = base64Decode(rawBase64);
        _cacheBytesToDocsDir(msg.id, bytes);
        return Image.memory(
          bytes,
          fit: widget.fit,
          cacheWidth: 1100,
          errorBuilder: (_, _, _) => _buildPlaceholder(),
        );
      } catch (_) {}
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: RelayColors.inkSoft,
      child: Center(
        child: Icon(CupertinoIcons.photo, color: Colors.white70, size: 28),
      ),
    );
  }

  void _cacheBase64IfAvailable(RelayMessage msg) {
    if (msg.imageData != null && msg.imageData!.isNotEmpty) {
      try {
        final rawBase64 = msg.imageData!.contains(',')
            ? msg.imageData!.split(',').last
            : msg.imageData!;
        _cacheBytesToDocsDir(msg.id, base64Decode(rawBase64));
      } catch (_) {}
    }
  }

  void _cacheBytesToDocsDir(String messageId, Uint8List bytes) {
    getApplicationDocumentsDirectory().then((docsDir) async {
      try {
        final dir = Directory('${docsDir.path}/relay_images');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final file = File('${dir.path}/img_$messageId.jpg');
        if (!await file.exists()) {
          await file.writeAsBytes(bytes, flush: true);
        }
      } catch (_) {}
    }).catchError((_) {});
  }
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
