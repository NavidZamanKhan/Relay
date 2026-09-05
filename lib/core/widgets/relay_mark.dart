import 'package:flutter/material.dart';

import '../theme/relay_colors.dart';

/// Relay's handoff mark.
///
/// The white stem and bowl establish an abstract R. The coral stroke takes over
/// at the exact midpoint and carries the form forward: one person handing a
/// thought to another. It stays legible at notification size and avoids the
/// literal arrows/chat bubbles used by most messaging brands.
class RelayMark extends StatelessWidget {
  const RelayMark({super.key, this.size = 40, this.onDark = true});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onDark ? RelayColors.ink : RelayColors.paper,
          borderRadius: BorderRadius.circular(size * .26),
        ),
        child: CustomPaint(painter: _RelayHandoffPainter(onDark: onDark)),
      ),
    );
  }
}

class _RelayHandoffPainter extends CustomPainter {
  const _RelayHandoffPainter({required this.onDark});

  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final stroke = unit * .105;
    final paper = Paint()
      ..color = onDark ? RelayColors.paper : RelayColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final coral = Paint()
      ..color = RelayColors.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The restrained R-shaped sender: vertical stem into an open upper bowl.
    final sender = Path()
      ..moveTo(unit * .30, unit * .74)
      ..lineTo(unit * .30, unit * .27)
      ..lineTo(unit * .52, unit * .27)
      ..cubicTo(
        unit * .68,
        unit * .27,
        unit * .72,
        unit * .36,
        unit * .72,
        unit * .43,
      )
      ..cubicTo(
        unit * .72,
        unit * .51,
        unit * .65,
        unit * .56,
        unit * .53,
        unit * .56,
      )
      ..lineTo(unit * .36, unit * .56);
    canvas.drawPath(sender, paper);

    // The coral baton starts where the bowl resolves and exits forward.
    canvas.drawLine(
      Offset(unit * .51, unit * .56),
      Offset(unit * .73, unit * .75),
      coral,
    );
  }

  @override
  bool shouldRepaint(covariant _RelayHandoffPainter oldDelegate) =>
      oldDelegate.onDark != onDark;
}
