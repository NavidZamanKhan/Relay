import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/theme/relay_colors.dart';

/// Real-time scrolling audio waveform visualizer for push-to-talk recording.
///
/// Subscribes directly to a normalized amplitude stream (0.0 to 1.0) and renders
/// a rolling window of audio amplitude bars at display cadence without triggering
/// widget tree rebuilds in parent views.
class LiveWaveformVisualizer extends StatefulWidget {
  const LiveWaveformVisualizer({
    super.key,
    required this.amplitudeStream,
    this.isRecording = true,
    this.cancelProgress = 0.0,
    this.color,
    this.height = 32.0,
    this.barCount = 28,
  });

  /// Stream emitting normalized microphone amplitudes (0.0 to 1.0) every ~70ms.
  final Stream<double>? amplitudeStream;

  /// Whether active voice recording is in progress.
  final bool isRecording;

  /// Slide-to-cancel progress ratio (0.0 to 1.0).
  final double cancelProgress;

  /// Waveform bar tint color. Defaults to [RelayColors.coral].
  final Color? color;

  /// Component height in logical pixels.
  final double height;

  /// Number of visual amplitude bars displayed across the window.
  final int barCount;

  @override
  State<LiveWaveformVisualizer> createState() => _LiveWaveformVisualizerState();
}

class _LiveWaveformVisualizerState extends State<LiveWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  StreamSubscription<double>? _amplitudeSub;

  late List<double> _currentBars;
  late List<double> _targetBars;

  @override
  void initState() {
    super.initState();
    _currentBars = List<double>.filled(widget.barCount, 0.12, growable: true);
    _targetBars = List<double>.filled(widget.barCount, 0.12, growable: true);

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);

    _ticker.repeat();
    _subscribeToStream();
  }

  @override
  void didUpdateWidget(covariant LiveWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) {
      _currentBars = List<double>.filled(widget.barCount, 0.12, growable: true);
      _targetBars = List<double>.filled(widget.barCount, 0.12, growable: true);
    }
    if (oldWidget.amplitudeStream != widget.amplitudeStream ||
        oldWidget.isRecording != widget.isRecording) {
      _subscribeToStream();
    }
  }

  void _subscribeToStream() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;

    if (!widget.isRecording || widget.amplitudeStream == null) return;

    _amplitudeSub = widget.amplitudeStream!.listen((amplitude) {
      if (!mounted) return;
      // Shift bars to the left and insert the new incoming amplitude sample on the right
      _targetBars.removeAt(0);
      _targetBars.add(amplitude.clamp(0.12, 1.0));
    });
  }

  void _onTick() {
    // Smoothly interpolate each bar toward its target height for fluid 60fps motion
    var needsRepaint = false;
    for (var i = 0; i < widget.barCount; i++) {
      final current = _currentBars[i];
      final target = _targetBars[i];
      if ((current - target).abs() > 0.005) {
        _currentBars[i] = lerpDouble(current, target, 0.22) ?? target;
        needsRepaint = true;
      }
    }
    if (needsRepaint && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? RelayColors.coral;
    final cancelRatio = widget.cancelProgress.clamp(0.0, 1.0);
    final effectiveColor = cancelRatio > 0
        ? Color.lerp(baseColor, RelayColors.coralDeep, cancelRatio)!
        : baseColor;
    final opacity = (1.0 - cancelRatio * 0.65).clamp(0.2, 1.0);

    return SizedBox(
      height: widget.height,
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LiveWaveformPainter(
            bars: _currentBars,
            color: effectiveColor,
          ),
        ),
      ),
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  const _LiveWaveformPainter({
    required this.bars,
    required this.color,
  });

  final List<double> bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final count = bars.length;
    final gap = size.width / count;
    final maxHeight = size.height - 4.0;
    const minHeight = 4.0;

    for (var i = 0; i < count; i++) {
      final normalized = bars[i].clamp(0.08, 1.0);
      final barHeight = minHeight + (maxHeight - minHeight) * normalized;
      final x = (i + 0.5) * gap;
      final top = (size.height - barHeight) / 2.0;
      final bottom = (size.height + barHeight) / 2.0;

      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.bars != bars;
  }
}
