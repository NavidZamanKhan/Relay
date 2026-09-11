import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:relay/core/theme/relay_colors.dart';
import 'package:relay/features/chats/chat_models.dart';

/// Context action item descriptor.
class MessageActionItem {
  const MessageActionItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
}

/// Full iOS-style context action overlay that renders an anchored reaction
/// pill and a frosted glass action menu card adjacent to the selected message bubble.
class MessageContextOverlay extends StatelessWidget {
  const MessageContextOverlay({
    super.key,
    required this.bubbleOffset,
    required this.bubbleSize,
    required this.mine,
    required this.message,
    required this.animation,
    required this.currentReaction,
    required this.onReactionSelected,
    required this.onMoreReactionsPressed,
    required this.onReplyPressed,
    required this.onCopyPressed,
    this.onSharePressed,
    this.onInfoPressed,
    this.onDeletePressed,
  });

  final Offset bubbleOffset;
  final Size bubbleSize;
  final bool mine;
  final RelayMessage message;
  final Animation<double> animation;
  final String? currentReaction;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback onMoreReactionsPressed;
  final VoidCallback onReplyPressed;
  final VoidCallback onCopyPressed;
  final VoidCallback? onSharePressed;
  final VoidCallback? onInfoPressed;
  final VoidCallback? onDeletePressed;

  static const List<String> quickReactions = [
    '\u{2764}\u{FE0F}',
    '\u{1F44D}',
    '\u{1F602}',
    '\u{1F62E}',
    '\u{1F622}',
    '\u{1F64F}',
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    const double reactionBarHeight = 48.0;
    const double reactionBarWidth = 296.0;
    const double actionCardWidth = 224.0;
    const double gap = 8.0;
    const double screenMargin = 14.0;

    final actions = _buildActionItems(context);
    final actionCardHeight = actions.length * 44.0 + (actions.length - 1) * 0.5;

    final minTop = padding.top + kToolbarHeight + 6.0;
    final maxBottom = screenSize.height - padding.bottom - 60.0;

    final spaceAbove = bubbleOffset.dy - minTop;
    final spaceBelow = maxBottom - (bubbleOffset.dy + bubbleSize.height);

    double reactionTop;
    double actionTop;
    Alignment scaleAlignment;

    if (spaceAbove >= reactionBarHeight + gap &&
        spaceBelow >= actionCardHeight + gap) {
      // Standard layout: Reactions above, Action menu below.
      reactionTop = bubbleOffset.dy - reactionBarHeight - gap;
      actionTop = bubbleOffset.dy + bubbleSize.height + gap;
      scaleAlignment = mine ? Alignment.topRight : Alignment.topLeft;
    } else if (spaceBelow < actionCardHeight + gap &&
        spaceAbove >= reactionBarHeight + actionCardHeight + gap * 2) {
      // Stacked above: Action menu on top, Reactions right above bubble.
      reactionTop = bubbleOffset.dy - reactionBarHeight - gap;
      actionTop = reactionTop - actionCardHeight - gap;
      scaleAlignment = mine ? Alignment.bottomRight : Alignment.bottomLeft;
    } else if (spaceAbove < reactionBarHeight + gap) {
      // Stacked below: Reactions right below bubble, Action menu beneath it.
      reactionTop = bubbleOffset.dy + bubbleSize.height + gap;
      actionTop = reactionTop + reactionBarHeight + gap;
      scaleAlignment = mine ? Alignment.topRight : Alignment.topLeft;
    } else {
      // Constrained fallback.
      reactionTop = (bubbleOffset.dy - reactionBarHeight - gap)
          .clamp(minTop, maxBottom - reactionBarHeight);
      actionTop = (bubbleOffset.dy + bubbleSize.height + gap)
          .clamp(minTop, maxBottom - actionCardHeight);
      scaleAlignment = mine ? Alignment.centerRight : Alignment.centerLeft;
    }

    // Horizontal placement calculations
    double reactionLeft;
    double actionLeft;

    if (mine) {
      final bubbleRight = bubbleOffset.dx + bubbleSize.width;

      reactionLeft = bubbleRight - reactionBarWidth;
      reactionLeft = reactionLeft.clamp(
        screenMargin,
        screenSize.width - screenMargin - reactionBarWidth,
      );

      actionLeft = bubbleRight - actionCardWidth;
      actionLeft = actionLeft.clamp(
        screenMargin,
        screenSize.width - screenMargin - actionCardWidth,
      );
    } else {
      reactionLeft = bubbleOffset.dx;
      reactionLeft = reactionLeft.clamp(
        screenMargin,
        screenSize.width - screenMargin - reactionBarWidth,
      );

      actionLeft = bubbleOffset.dx;
      actionLeft = actionLeft.clamp(
        screenMargin,
        screenSize.width - screenMargin - actionCardWidth,
      );
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
            onTap: () => Navigator.maybePop(context),
          ),
        ),
        // Quick reactions bar
        Positioned(
          left: reactionLeft,
          top: reactionTop,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.0).animate(curvedAnim),
              alignment: scaleAlignment,
              child: Material(
                type: MaterialType.transparency,
                child: _ReactionBar(
                  dark: dark,
                  currentReaction: currentReaction,
                  onReactionSelected: onReactionSelected,
                  onMoreReactionsPressed: onMoreReactionsPressed,
                ),
              ),
            ),
          ),
        ),
        // Context action menu card
        Positioned(
          left: actionLeft,
          top: actionTop,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.65, end: 1.0).animate(curvedAnim),
              alignment: scaleAlignment,
              child: Material(
                type: MaterialType.transparency,
                child: _ActionMenuCard(
                  width: actionCardWidth,
                  dark: dark,
                  actions: actions,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<MessageActionItem> _buildActionItems(BuildContext context) {
    final list = <MessageActionItem>[
      MessageActionItem(
        title: 'Reply',
        icon: CupertinoIcons.reply,
        onTap: () {
          Navigator.maybePop(context);
          onReplyPressed();
        },
      ),
      MessageActionItem(
        title: 'Copy',
        icon: CupertinoIcons.doc_on_doc,
        onTap: () {
          Navigator.maybePop(context);
          onCopyPressed();
        },
      ),
    ];

    if (onSharePressed != null) {
      list.add(
        MessageActionItem(
          title: 'Share',
          icon: CupertinoIcons.share,
          onTap: () {
            Navigator.maybePop(context);
            onSharePressed!();
          },
        ),
      );
    }

    if (onInfoPressed != null) {
      list.add(
        MessageActionItem(
          title: 'Info',
          icon: CupertinoIcons.info_circle,
          onTap: () {
            Navigator.maybePop(context);
            onInfoPressed!();
          },
        ),
      );
    }

    if (onDeletePressed != null) {
      list.add(
        MessageActionItem(
          title: 'Delete',
          icon: CupertinoIcons.trash,
          isDestructive: true,
          onTap: () {
            Navigator.maybePop(context);
            onDeletePressed!();
          },
        ),
      );
    }

    return list;
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    required this.dark,
    required this.currentReaction,
    required this.onReactionSelected,
    required this.onMoreReactionsPressed,
  });

  final bool dark;
  final String? currentReaction;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback onMoreReactionsPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          for (final emoji in MessageContextOverlay.quickReactions)
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
              onMoreReactionsPressed();
            },
          ),
        ],
      ),
    );
  }
}

class _ActionMenuCard extends StatelessWidget {
  const _ActionMenuCard({
    required this.width,
    required this.dark,
    required this.actions,
  });

  final double width;
  final bool dark;
  final List<MessageActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xFF22252E).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.65,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.38 : 0.14),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: dark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                _ActionMenuItemRow(
                  action: actions[i],
                  dark: dark,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionMenuItemRow extends StatefulWidget {
  const _ActionMenuItemRow({
    required this.action,
    required this.dark,
  });

  final MessageActionItem action;
  final bool dark;

  @override
  State<_ActionMenuItemRow> createState() => _ActionMenuItemRowState();
}

class _ActionMenuItemRowState extends State<_ActionMenuItemRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final itemColor = widget.action.isDestructive
        ? const Color(0xFFFF453A)
        : (widget.dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87);

    final highlightColor = widget.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.action.onTap();
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: _pressed ? highlightColor : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.action.title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
                color: itemColor,
                letterSpacing: -0.2,
                decoration: TextDecoration.none,
              ),
            ),
            Icon(
              widget.action.icon,
              size: 19,
              color: itemColor,
            ),
          ],
        ),
      ),
    );
  }
}
