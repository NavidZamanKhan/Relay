import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/motion/relay_motion.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_avatar.dart';

/// Floating in-app notification banner presented when receiving an incoming
/// message while viewing another conversation, the inbox list, or settings.
class InAppNotificationBanner extends StatefulWidget {
  const InAppNotificationBanner({
    super.key,
    required this.payload,
    this.onTap,
    this.onDismissed,
    this.duration = const Duration(milliseconds: 3800),
    this.showPreview = true,
  });

  final NotificationPayload payload;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;
  final Duration duration;
  final bool showPreview;

  static OverlayEntry? _activeEntry;

  /// Dismisses any currently active in-app banner.
  static void dismiss() {
    _activeEntry?.remove();
    _activeEntry = null;
  }

  /// Displays an in-app banner dropping down from the top.
  static void show(
    BuildContext context, {
    required NotificationPayload payload,
    VoidCallback? onTap,
    Duration duration = const Duration(milliseconds: 3800),
    bool showPreview = true,
  }) {
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => InAppNotificationBanner(
        payload: payload,
        duration: duration,
        showPreview: showPreview,
        onTap: () {
          dismiss();
          onTap?.call();
        },
        onDismissed: () {
          if (_activeEntry == entry) {
            entry.remove();
            _activeEntry = null;
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: RelayMotion.enter,
      reverseCurve: RelayMotion.exit,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.85),
      end: Offset.zero,
    ).animate(_fadeAnimation);

    _controller.forward();

    _dismissTimer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed?.call();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyText = widget.showPreview ? widget.payload.body : 'New message';

    return Positioned(
      top: topPadding + 10 + _dragOffsetY,
      left: 14,
      right: 14,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! < 0) {
            setState(() {
              _dragOffsetY += details.primaryDelta!;
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffsetY < -20 || (details.primaryVelocity ?? 0) < -300) {
            _dismiss();
          } else {
            setState(() {
              _dragOffsetY = 0.0;
            });
          }
        },
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2228).withValues(alpha: 0.92)
                          : Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.12,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RelayAvatar(
                          name: widget.payload.title,
                          asset: widget.payload.avatarUrl,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.payload.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : RelayColors.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'now',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : RelayColors.inkFaint,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                bodyText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.28,
                                  color: isDark
                                      ? Colors.white70
                                      : RelayColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 20,
                            color: isDark
                                ? Colors.white38
                                : RelayColors.inkFaint,
                          ),
                          onPressed: _dismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
