import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/audio_service.dart';
import 'package:relay/features/chats/message_bubble.dart';
import 'package:relay/features/chats/widgets/live_waveform_visualizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Audio Waveform and Resampling Tests', () {
    test('resampleWaveform correctly generates target bars', () {
      // Empty samples fallback
      final empty = RelayAudioService.resampleWaveform([], 32);
      expect(empty.length, equals(32));
      expect(empty.every((s) => s >= 0.15 && s <= 1.0), isTrue);

      // Upsampling from 5 samples to 32 bars
      final fewSamples = [0.2, 0.4, 0.9, 0.5, 0.3];
      final upsampled = RelayAudioService.resampleWaveform(fewSamples, 32);
      expect(upsampled.length, equals(32));
      expect(upsampled.every((s) => s >= 0.15 && s <= 1.0), isTrue);
      // Peak sample should be preserved or closely interpolated
      expect(upsampled.any((s) => s >= 0.8), isTrue);

      // Downsampling from 100 samples to 32 bars
      final manySamples = List.generate(100, (i) => (i / 100.0).clamp(0.15, 1.0));
      final downsampled = RelayAudioService.resampleWaveform(manySamples, 32);
      expect(downsampled.length, equals(32));
      expect(downsampled.first, lessThan(downsampled.last));
    });

    test('NoOpAudioService emits live amplitudes during recording', () async {
      final service = NoOpAudioService(emitMockAmplitudes: true);
      final amplitudes = <double>[];

      final sub = service.liveAmplitudeStream.listen(amplitudes.add);

      await service.startRecording();
      // Allow mock timer to tick
      await Future<void>.delayed(const Duration(milliseconds: 230));

      expect(amplitudes.isNotEmpty, isTrue);
      expect(amplitudes.every((a) => a >= 0.12 && a <= 1.0), isTrue);

      final result = await service.stopRecording();
      expect(result, isNotNull);
      expect(result!.waveform.length, equals(32));

      await sub.cancel();
      service.dispose();
    });

    testWidgets('LiveWaveformVisualizer renders and consumes amplitude stream', (tester) async {
      final controller = StreamController<double>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveWaveformVisualizer(
              amplitudeStream: controller.stream,
              isRecording: true,
              cancelProgress: 0.0,
              height: 32,
              barCount: 28,
            ),
          ),
        ),
      );

      expect(find.byType(LiveWaveformVisualizer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LiveWaveformVisualizer),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      // Push amplitude ticks
      controller.add(0.45);
      await tester.pump(const Duration(milliseconds: 50));

      controller.add(0.85);
      await tester.pump(const Duration(milliseconds: 50));

      controller.add(0.20);
      await tester.pump(const Duration(milliseconds: 50));

      // Visualizer stays mounted and renders updated bars
      expect(find.byType(LiveWaveformVisualizer), findsOneWidget);

      await controller.close();
    });

    testWidgets('LiveWaveformVisualizer reacts to cancelProgress change', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveWaveformVisualizer(
              amplitudeStream: null,
              isRecording: true,
              cancelProgress: 0.8,
              height: 32,
              barCount: 28,
            ),
          ),
        ),
      );

      expect(find.byType(LiveWaveformVisualizer), findsOneWidget);
      final opacityFinder = find.byType(Opacity);
      expect(opacityFinder, findsOneWidget);

      final opacityWidget = tester.widget<Opacity>(opacityFinder);
      expect(opacityWidget.opacity, lessThan(1.0));
    });

    testWidgets('WaveformPainter in message bubble paints real 32-bar waveform', (tester) async {
      final realWaveform = List.generate(32, (i) => (i % 2 == 0 ? 0.75 : 0.3));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 44,
              child: CustomPaint(
                painter: WaveformPainter(
                  progress: 0.5,
                  active: Colors.red,
                  inactive: Colors.grey,
                  seed: 42,
                  waveform: realWaveform,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is WaveformPainter,
        ),
        findsOneWidget,
      );
    });
  });
}
