import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/motion/relay_motion.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_emoji_picker.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';
import 'widgets/image_attachment_preview_sheet.dart';
import 'widgets/live_waveform_visualizer.dart';

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
  bool _emojiPickerOpen = false;
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
    if (!_emojiPickerOpen) {
      _focus.requestFocus();
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _emojiPickerOpen = !_emojiPickerOpen;
      if (_emojiPickerOpen) {
        _focus.unfocus();
      } else {
        _focus.requestFocus();
      }
    });
  }

  void _start(LongPressStartDetails d) {
    if (_bloc.state.composerText.trim().isNotEmpty || _bloc.state.isRecording) {
      return;
    }
    if (_emojiPickerOpen) {
      setState(() => _emojiPickerOpen = false);
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
  Widget build(BuildContext context) => BlocConsumer<ChatBloc, ChatState>(
    listenWhen: (a, b) => a.replyingTo != b.replyingTo && b.replyingTo != null,
    listener: (context, state) {
      if (_emojiPickerOpen) {
        setState(() => _emojiPickerOpen = false);
      }
      _focus.requestFocus();
    },
    buildWhen: (a, b) =>
        a.composerText != b.composerText ||
        a.isRecording != b.isRecording ||
        a.recordingLocked != b.recordingLocked ||
        a.recordingSeconds != b.recordingSeconds ||
        a.replyingTo != b.replyingTo,
    builder: (context, state) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final hasText = state.composerText.trim().isNotEmpty;
      return Container(
        padding: EdgeInsets.fromLTRB(
          12,
          9,
          12,
          _emojiPickerOpen ? 0 : (8 + MediaQuery.paddingOf(context).bottom),
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
                AnimatedSize(
                  duration: RelayMotion.quick,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: state.replyingTo != null
                      ? _QuotedReplyBar(
                          replyingTo: state.replyingTo!,
                          contactName: widget.contactName,
                          onDismiss: () => context.read<ChatBloc>().add(
                            const ChatReplyTargetSet(null),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
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
                          if (_emojiPickerOpen) {
                            setState(() => _emojiPickerOpen = false);
                          }
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
                                    Expanded(
                                      child: RepaintBoundary(
                                        child: LiveWaveformVisualizer(
                                          amplitudeStream:
                                              _bloc.liveAmplitudeStream,
                                          isRecording: state.isRecording,
                                          cancelProgress:
                                              state.cancelProgress,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                  ],
                                ),
                              )
                            : Focus(
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.enter &&
                                      !HardwareKeyboard.instance.isShiftPressed &&
                                      !HardwareKeyboard.instance.isAltPressed &&
                                      !HardwareKeyboard.instance.isMetaPressed) {
                                    if (_text.text.trim().isNotEmpty) {
                                      _sendText();
                                    }
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
                                  controller: _text,
                                  focusNode: _focus,
                                  minLines: 1,
                                  maxLines: 5,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  enableSuggestions: true,
                                  autocorrect: true,
                                  enableInteractiveSelection: true,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onTap: () {
                                    if (_emojiPickerOpen) {
                                      setState(() => _emojiPickerOpen = false);
                                    }
                                  },
                                  onChanged: (v) =>
                                      _bloc.add(ChatComposerChanged(v)),
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    height: 1.4,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Message',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _emojiPickerOpen
                                          ? 'Show keyboard'
                                          : 'Show emojis',
                                      onPressed: _toggleEmojiPicker,
                                      icon: Icon(
                                        _emojiPickerOpen
                                            ? CupertinoIcons.keyboard
                                            : CupertinoIcons.smiley,
                                        size: 21,
                                        color: _emojiPickerOpen
                                            ? RelayColors.coral
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
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
                                      borderSide: const BorderSide(
                                        color: RelayColors.coral,
                                        width: 1.5,
                                      ),
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
                          : state.isRecording
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
                          } else if (state.isRecording) {
                            _bloc.add(const ChatRecordingSent());
                          } else {
                            // A tap offers an accessible hands-free recording session.
                            _bloc.add(const ChatRecordingStarted(locked: true));
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
                                hasText || state.isRecording
                                    ? CupertinoIcons.arrow_up
                                    : CupertinoIcons.mic,
                                key: ValueKey(hasText || state.isRecording),
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
                AnimatedSwitcher(
                  duration: RelayMotion.duration(context, RelayMotion.quick),
                  child: _emojiPickerOpen
                      ? Column(
                          key: const ValueKey('relay-emoji-picker-container'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 6),
                            RelayEmojiPicker(
                              textEditingController: _text,
                              onEmojiSelected: (category, emoji) =>
                                  _bloc.add(ChatComposerChanged(_text.text)),
                              onBackspacePressed: () =>
                                  _bloc.add(ChatComposerChanged(_text.text)),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            if (state.isRecording && !state.recordingLocked)
              Positioned(
                right: 2,
                bottom: 88,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _bloc.add(const ChatRecordingLocked()),
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
      builder: (sheet) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share Content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AttachmentTile(
                    icon: CupertinoIcons.camera_fill,
                    label: 'Camera',
                    color: RelayColors.coral,
                    backgroundColor: dark
                        ? RelayColors.coralNight
                        : RelayColors.coralWash,
                    onTap: () {
                      Navigator.pop(sheet);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                  _AttachmentTile(
                    icon: CupertinoIcons.photo_on_rectangle,
                    label: 'Gallery',
                    color: const Color(0xFF8B5CF6),
                    backgroundColor: dark
                        ? const Color(0xFF2A2045)
                        : const Color(0xFFF3E8FF),
                    onTap: () {
                      Navigator.pop(sheet);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  _AttachmentTile(
                    icon: CupertinoIcons.doc_fill,
                    label: 'Document',
                    color: RelayColors.blue,
                    backgroundColor: dark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE0EDFE),
                    onTap: () {
                      Navigator.pop(sheet);
                      _bloc.add(const ChatMediaSent(MessageKind.document));
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 75,
      );
      if (picked != null && mounted) {
        await ImageAttachmentPreviewSheet.show(
          context,
          imagePath: picked.path,
          onSend: (caption) {
            _bloc.add(
              ChatImagePicked(
                picked.path,
                caption: caption.isNotEmpty ? caption : null,
              ),
            );
          },
        );
      }
    } catch (_) {}
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotedReplyBar extends StatelessWidget {
  const _QuotedReplyBar({
    required this.replyingTo,
    required this.contactName,
    required this.onDismiss,
  });

  final RelayMessage replyingTo;
  final String contactName;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isMine = replyingTo.isMine;
    final snippet = replyingTo.text?.trim().isNotEmpty == true
        ? replyingTo.text!.trim()
        : (replyingTo.kind == MessageKind.image
            ? 'Photo'
            : (replyingTo.kind == MessageKind.voice
                ? 'Voice note'
                : 'Attachment'));

    final mediaIcon = switch (replyingTo.kind) {
      MessageKind.image => CupertinoIcons.photo,
      MessageKind.voice => CupertinoIcons.mic,
      MessageKind.document => CupertinoIcons.doc,
      MessageKind.system => CupertinoIcons.info_circle,
      MessageKind.text => null,
    };

    final title = isMine
        ? 'Replying to yourself'
        : (contactName.trim().isNotEmpty
            ? 'Replying to ${contactName.trim()}'
            : 'Replying to message');

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .5),
          width: .7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .18 : .04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
              child: Container(
                width: 3.5,
                color: RelayColors.coral,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context
                              .read<ChatBloc>()
                              .add(ChatLocateMessageRequested(replyingTo.id));
                        },
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.reply,
                              size: 15,
                              color: RelayColors.coral,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: RelayColors.coral,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (mediaIcon != null) ...[
                                        Icon(
                                          mediaIcon,
                                          size: 13,
                                          color: dark
                                              ? RelayColors.moonMuted
                                              : RelayColors.inkSoft,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          snippet,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      icon: const Icon(CupertinoIcons.xmark, size: 16),
                      onPressed: onDismiss,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
    );
  }
}
