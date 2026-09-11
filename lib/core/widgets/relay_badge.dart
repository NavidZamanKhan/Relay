import 'package:flutter/material.dart';

import '../theme/relay_colors.dart';

enum RelayBadgeVariant {
  accent,
  subtle,
  outline,
}

/// Compact pill badge used for roles (e.g. Admin), statuses, and tags.
class RelayBadge extends StatelessWidget {
  const RelayBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = RelayBadgeVariant.accent,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
  });

  final String label;
  final IconData? icon;
  final RelayBadgeVariant variant;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color foregroundColor;
    Border? border;

    switch (variant) {
      case RelayBadgeVariant.accent:
        backgroundColor = RelayColors.mint.withValues(alpha: .15);
        foregroundColor = RelayColors.mint;
        border = Border.all(
          color: RelayColors.mint.withValues(alpha: .32),
          width: 0.7,
        );
      case RelayBadgeVariant.subtle:
        backgroundColor = scheme.surfaceContainerHighest.withValues(alpha: .6);
        foregroundColor = scheme.onSurfaceVariant;
        border = null;
      case RelayBadgeVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = scheme.onSurface.withValues(alpha: .75);
        border = Border.all(
          color: scheme.outline.withValues(alpha: .35),
          width: 0.8,
        );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10.5, color: foregroundColor),
            const SizedBox(width: 3.5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
