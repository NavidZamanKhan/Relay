import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/relay_message.dart';

/// Centered capsule event pill displaying in-chat group administrative events
/// (e.g. member additions, removals, admin promotions, metadata updates).
class GroupSystemEventPill extends StatelessWidget {
  const GroupSystemEventPill({
    super.key,
    required this.message,
  });

  final RelayMessage message;

  IconData _resolveIcon(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('appointed') || lower.contains('admin')) {
      return CupertinoIcons.shield_fill;
    }
    if (lower.contains('added')) {
      return CupertinoIcons.person_badge_plus;
    }
    if (lower.contains('removed')) {
      return CupertinoIcons.person_badge_minus;
    }
    if (lower.contains('left')) {
      return CupertinoIcons.arrow_right_square;
    }
    if (lower.contains('created')) {
      return CupertinoIcons.sparkles;
    }
    if (lower.contains('name') || lower.contains('description') || lower.contains('photo')) {
      return CupertinoIcons.pencil;
    }
    return CupertinoIcons.info_circle_fill;
  }

  @override
  Widget build(BuildContext context) {
    final eventText = message.text ?? '';
    final icon = _resolveIcon(eventText);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13.5,
                color: onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  eventText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: onSurface.withValues(alpha: 0.9),
                    letterSpacing: 0.1,
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
