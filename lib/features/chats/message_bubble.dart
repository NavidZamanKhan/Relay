import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/motion/relay_motion.dart';
import '../../core/theme/relay_colors.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';
import 'relay_receipt.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.grouped = false});

  final bool grouped;

  final RelayMessage message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mine = message.isMine;
    final bubbleColor = mine
        ? (isDark ? RelayColors.coralNight : RelayColors.coralWash)
        : Theme.of(context).colorScheme.surface;
    final foreground = Theme.of(context).colorScheme.onSurface;

    // MessageBubble itself is intentionally static. Its parent AnimatedList
    // animates only a genuinely inserted row; delivery and playback rebuilds do
    // not make the entire history slide in again.
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.sizeOf(context).width *
              (message.kind == MessageKind.image ? .72 : .79),
        ),
        margin: EdgeInsets.only(
          left: mine ? 54 : 18,
          right: mine ? 18 : 54,
          top: grouped ? 0 : 7,
          bottom: 4,
        ),
        padding: message.kind == MessageKind.image
            ? const EdgeInsets.all(4)
            : const EdgeInsets.fromLTRB(14, 10, 12, 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(19),
            topRight: const Radius.circular(19),
            bottomLeft: Radius.circular(mine ? 19 : 5),
            bottomRight: Radius.circular(mine ? 5 : 19),
          ),
          border: mine
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: RelayColors.coral, width: 2.5),
              ),
            ),
            child: Text(
              message.replyTo!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground.withValues(alpha: .72),
                fontSize: 12,
                height: 1.3,
              ),
            ),
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
  const _ImageMessage({required this.message, required this.foreground});
  final RelayMessage message;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            PageRouteBuilder<void>(
              opaque: false,
              barrierColor: Colors.black.withValues(alpha: .92),
              pageBuilder: (_, animation, _) => _ImagePreview(
                asset: message.asset!,
                heroTag: 'shared-image-${message.id}',
              ),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          child: Hero(
            tag: 'shared-image-${message.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.asset(
                  message.asset!,
                  fit: BoxFit.cover,
                  cacheWidth: 1100,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
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
                            ),
                            AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: RelayMotion.quick,
                              curve: RelayMotion.enter,
                              child: child,
                            ),
                          ],
                        );
                      },
                ),
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
        final selected = state.playingMessageId == message.id;
        final playing = selected && !state.voicePaused;
        final progress = selected ? state.voiceProgress : 0.0;
        return SizedBox(
          width: 240,
          child: Column(
            children: [
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
                      decoration: const BoxDecoration(
                        color: RelayColors.coral,
                        shape: BoxShape.circle,
                      ),
                      child: Semantics(
                        label: playing ? 'Pause voice note' : 'Play voice note',
                        button: true,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CustomPaint(
                              painter: _PlaybackGlyph(playing),
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
                              builder: (_, visualProgress, _) => CustomPaint(
                                painter: WaveformPainter(
                                  progress: visualProgress,
                                  active: RelayColors.coralDeep,
                                  inactive: foreground.withValues(alpha: .27),
                                  seed: message.id.hashCode,
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
  });

  final double progress;
  final Color active;
  final Color inactive;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 32;
    final gap = size.width / bars;
    final activeUntil = (bars * progress).round();
    for (var i = 0; i < bars; i++) {
      final wave =
          .24 +
          .72 *
              ((math.sin((i + seed) * .79).abs() * .55) +
                  (math.sin((i + 2) * .31).abs() * .45));
      final height = size.height * wave.clamp(.22, .96).toDouble();
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
      oldDelegate.seed != seed;
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.asset, required this.heroTag});
  final String asset;
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
                  child: Image.asset(asset, fit: BoxFit.contain),
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
  const _PlaybackGlyph(this.playing);
  final bool playing;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = RelayColors.ink;
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
      oldDelegate.playing != playing;
}
