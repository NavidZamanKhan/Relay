import 'package:flutter/material.dart';

import '../../core/theme/relay_colors.dart';
import 'chat_models.dart';

/// A crisp, code-drawn delivery glyph.
///
/// Drawing receipts ourselves keeps stroke weight and alignment identical on
/// iOS and Android. Font-based double-check icons vary by platform and were one
/// of the details making the earlier prototype feel visually inconsistent.
class RelayReceipt extends StatelessWidget {
  const RelayReceipt({
    super.key,
    required this.stage,
    this.size = 15,
    this.color,
  });

  final DeliveryStage stage;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = stage == DeliveryStage.read
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF82B7F5)
              : RelayColors.blue)
        : color ??
              Theme.of(context).textTheme.bodySmall?.color ??
              RelayColors.inkSoft;
    return Semantics(
      label: switch (stage) {
        DeliveryStage.sending => 'Sending',
        DeliveryStage.sent => 'Sent',
        DeliveryStage.delivered => 'Delivered',
        DeliveryStage.read => 'Read',
      },
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ReceiptPainter(stage: stage, color: resolvedColor),
        ),
      ),
    );
  }
}

class _ReceiptPainter extends CustomPainter {
  const _ReceiptPainter({required this.stage, required this.color});

  final DeliveryStage stage;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * .105;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stage == DeliveryStage.sending) {
      final center = Offset(size.width * .5, size.height * .5);
      canvas.drawCircle(center, size.width * .34, paint);
      canvas.drawLine(
        center,
        Offset(size.width * .5, size.height * .29),
        paint,
      );
      canvas.drawLine(
        center,
        Offset(size.width * .64, size.height * .55),
        paint,
      );
      return;
    }

    _check(canvas, size, paint, dx: stage == DeliveryStage.sent ? .02 : -.11);
    if (stage == DeliveryStage.delivered || stage == DeliveryStage.read) {
      _check(canvas, size, paint, dx: .16);
    }
  }

  void _check(Canvas canvas, Size size, Paint paint, {required double dx}) {
    final path = Path()
      ..moveTo(size.width * (.16 + dx), size.height * .51)
      ..lineTo(size.width * (.37 + dx), size.height * .70)
      ..lineTo(size.width * (.72 + dx), size.height * .30);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReceiptPainter oldDelegate) =>
      oldDelegate.stage != stage || oldDelegate.color != color;
}
