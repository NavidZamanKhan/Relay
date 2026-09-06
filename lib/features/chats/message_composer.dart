import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/motion/relay_motion.dart';
import '../../core/theme/relay_colors.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';

/// RECORDING GESTURE OWNERSHIP - KEEP THIS STRUCTURE WHEN ADDING `record`.
///
/// The GestureDetector below remains mounted in the SAME element slot for idle,
/// holding and locked states. Replacing the whole composer with an
/// AnimatedSwitcher disposes its long-press recognizer mid-gesture: move/end
/// callbacks disappear and release-to-send silently breaks.
///
/// A ValueNotifier carries raw finger displacement directly into a transform.
/// It is presentation state, not a recording decision. Only start/lock/cancel/
/// release events reach BLoC. This keeps finger feedback synchronous while
/// avoiding timeline rebuilds for pointer samples. Locked/sent/cancelled truth
/// always comes back from BLoC. Crossing a threshold latches once, with one
/// haptic, so moving across it repeatedly cannot enqueue contradictory events.
class MessageComposer extends StatefulWidget {
  const MessageComposer({super.key, required this.contactName});
  final String contactName;
  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _finger = ValueNotifier<Offset>(Offset.zero);
  late final ChatBloc _bloc;
  bool _resolved = false;
  @override
  void initState() {
    super.initState();
    _bloc = context.read<ChatBloc>();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _bloc.state.isRecording) {
      _resolved = true;
      _bloc.add(const ChatRecordingCancelled());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_bloc.isClosed && _bloc.state.isRecording) {
      _bloc.add(const ChatRecordingCancelled());
    }
    _text.dispose();
    _focus.dispose();
    _finger.dispose();
    super.dispose();
  }

  void _sendText() {
    _bloc.add(const ChatTextSent());
    _text.clear();
    HapticFeedback.selectionClick();
    _focus.requestFocus();
  }

  void _start(LongPressStartDetails d) {
    if (_bloc.state.composerText.trim().isNotEmpty || _bloc.state.isRecording) {
      return;
    }
    _resolved = false;
    _finger.value = Offset.zero;
    _bloc.add(const ChatRecordingStarted());
    HapticFeedback.lightImpact();
  }

  void _move(LongPressMoveUpdateDetails d) {
    if (_resolved || !_bloc.state.isRecording) return;
    final offset = d.offsetFromOrigin;
    _finger.value = Offset(
      offset.dx.clamp(-80.0, 0.0),
      offset.dy.clamp(-54.0, 0.0),
    );
    if (offset.dx <= -110) {
      _resolved = true;
      _bloc.add(const ChatRecordingCancelled());
      HapticFeedback.selectionClick();
    } else if (offset.dy <= -72) {
      _resolved = true;
      _finger.value = Offset.zero;
      _bloc.add(const ChatRecordingLocked());
      HapticFeedback.mediumImpact();
    }
  }

  void _end(LongPressEndDetails d) {
    if (!_resolved) _bloc.add(const ChatRecordingReleased());
    _finger.value = Offset.zero;
    _resolved = false;
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ChatBloc, ChatState>(
    buildWhen: (a, b) =>
        a.composerText != b.composerText ||
        a.isRecording != b.isRecording ||
        a.recordingLocked != b.recordingLocked ||
        a.recordingSeconds != b.recordingSeconds,
    builder: (context, state) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final hasText = state.composerText.trim().isNotEmpty;
      return Container(
        padding: EdgeInsets.fromLTRB(
          12,
          9,
          12,
          8 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: .7),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: state.isRecording
                          ? 'Cancel recording'
                          : 'Attach',
                      onPressed: () {
                        if (state.isRecording) {
                          _resolved = true;
                          _bloc.add(const ChatRecordingCancelled());
                        } else {
                          _attachments(context);
                        }
                      },
                      icon: Icon(
                        state.isRecording
                            ? CupertinoIcons.trash
                            : CupertinoIcons.plus,
                        size: 23,
                        color: state.isRecording ? RelayColors.coralDeep : null,
                      ),
                    ),
                    Expanded(
                      child: AnimatedSize(
                        duration: RelayMotion.duration(
                          context,
                          RelayMotion.quick,
                        ),
                        alignment: Alignment.bottomCenter,
                        curve: RelayMotion.enter,
                        child: state.isRecording
                            ? SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 3),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: RelayColors.coralDeep,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${state.recordingSeconds ~/ 60}:${(state.recordingSeconds % 60).toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 13),
                                    const Expanded(
                                      child: RepaintBoundary(
                                        child: _RecordingWave(),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                  ],
                                ),
                              )
                            : TextField(
                                controller: _text,
                                focusNode: _focus,
                                minLines: 1,
                                maxLines: 5,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (v) =>
                                    _bloc.add(ChatComposerChanged(v)),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Message',
                                  fillColor: dark
                                      ? RelayColors.nightSoft
                                      : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Stable recognizer: only this control's paint/content changes.
                    Semantics(
                      button: true,
                      label: hasText
                          ? 'Send message'
                          : state.recordingLocked
                          ? 'Send voice note'
                          : 'Record voice note',
                      child: GestureDetector(
                        key: const ValueKey('record-gesture'),
                        behavior: HitTestBehavior.opaque,
                        onLongPressStart: _start,
                        onLongPressMoveUpdate: _move,
                        onLongPressEnd: _end,
                        onLongPressCancel: () {
                          if (state.isRecording && !state.recordingLocked) {
                            _bloc.add(const ChatRecordingCancelled());
                          }
                        },
                        onTap: () {
                          if (hasText) {
                            _sendText();
                          } else if (state.recordingLocked) {
                            _bloc.add(const ChatRecordingSent());
                          } else if (!state.isRecording) {
                            // A tap offers an accessible hands-free equivalent of a hold.
                            _bloc.add(const ChatRecordingStarted());
                            _bloc.add(const ChatRecordingLocked());
                          }
                        },
                        child: ValueListenableBuilder<Offset>(
                          valueListenable: _finger,
                          builder: (_, offset, child) => Transform.translate(
                            offset: state.isRecording && !state.recordingLocked
                                ? offset
                                : Offset.zero,
                            child: child,
                          ),
                          child: AnimatedContainer(
                            duration: RelayMotion.duration(
                              context,
                              RelayMotion.instant,
                            ),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: hasText || state.isRecording
                                  ? RelayColors.coral
                                  : (dark
                                        ? RelayColors.nightSoft
                                        : RelayColors.ink),
                              shape: BoxShape.circle,
                            ),
                            child: AnimatedSwitcher(
                              duration: RelayMotion.duration(
                                context,
                                RelayMotion.quick,
                              ),
                              child: Icon(
                                hasText || state.recordingLocked
                                    ? CupertinoIcons.arrow_up
                                    : CupertinoIcons.mic,
                                key: ValueKey(hasText || state.recordingLocked),
                                size: 22,
                                color: hasText || state.isRecording
                                    ? RelayColors.ink
                                    : RelayColors.paper,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: RelayMotion.duration(context, RelayMotion.quick),
                  curve: RelayMotion.enter,
                  child: state.isRecording
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 3),
                          child: Text(
                            state.recordingLocked
                                ? 'Recording hands-free · tap the arrow to send'
                                : 'Slide left to cancel · slide up to lock',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 10.5),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
            if (state.isRecording && !state.recordingLocked)
              Positioned(
                right: 2,
                bottom: 88,
                child: Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: const Column(
                    children: [
                      Icon(CupertinoIcons.lock, size: 17),
                      SizedBox(height: 13),
                      Icon(CupertinoIcons.chevron_up, size: 13),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
  void _attachments(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to the conversation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(sheet);
                  _bloc.add(const ChatMediaSent(MessageKind.image));
                },
                child: AspectRatio(
                  aspectRatio: 2.6,
                  child: Image.asset(
                    'assets/images/sylhet_evening.png',
                    fit: BoxFit.cover,
                    cacheWidth: 1100,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (icon, label, kind) in const [
                  (CupertinoIcons.camera, 'Camera', MessageKind.image),
                  (CupertinoIcons.photo, 'Gallery', MessageKind.image),
                  (CupertinoIcons.doc, 'Document', MessageKind.document),
                ])
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(sheet);
                        _bloc.add(ChatMediaSent(kind));
                      },
                      child: Column(
                        children: [
                          Icon(
                            icon,
                            size: 25,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(height: 9),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The waveform repaints at the display cadence through CustomPainter(repaint:).
/// It never rebuilds the composer or list. The seeded envelope is illustrative;
/// replace the samples with on-device amplitude data in the production phase.
class _RecordingWave extends StatefulWidget {
  const _RecordingWave();
  @override
  State<_RecordingWave> createState() => _RecordingWaveState();
}

class _RecordingWaveState extends State<_RecordingWave>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 30,
    child: CustomPaint(painter: _LiveWavePainter(_clock)),
  );
}

class _LiveWavePainter extends CustomPainter {
  _LiveWavePainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = RelayColors.coral
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const count = 25;
    for (var i = 0; i < count; i++) {
      final h =
          4 +
          (size.height - 4) *
              (math.sin(i * .72 + clock.value * math.pi * 2).abs() * .65 + .12);
      final x = (i + .5) * size.width / count;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWavePainter oldDelegate) =>
      oldDelegate.clock != clock;
}
