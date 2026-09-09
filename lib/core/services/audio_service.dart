import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Contract defining audio recording, amplitude extraction, and playback.
abstract interface class IAudioService {
  /// Verifies or requests microphone permission.
  Future<bool> hasPermission();

  /// Begins recording AAC-LC audio to a local temporary file.
  Future<void> startRecording();

  /// Concludes recording, returning the local file path, duration, and 32-bar waveform.
  Future<({String path, Duration duration, List<double> waveform})?> stopRecording();

  /// Aborts active recording and purges temporary files.
  Future<void> cancelRecording();

  /// Stream of normalized amplitude levels (0.0 to 1.0) while recording.
  Stream<double> get liveAmplitudeStream;

  /// Starts or resumes playback for a given local file path or remote URL.
  Future<void> play(String sourcePath);

  /// Pauses active playback.
  Future<void> pause();

  /// Resumes paused playback.
  Future<void> resume();

  /// Stops playback and resets position.
  Future<void> stop();

  /// Seeks to a specific duration in the active audio file.
  Future<void> seek(Duration position);

  /// Modifies playback speed (e.g. 1.0, 1.5, 2.0).
  Future<void> setPlaybackRate(double speed);

  /// Stream of elapsed playback duration.
  Stream<Duration> get positionStream;

  /// Stream of total audio duration.
  Stream<Duration?> get durationStream;

  /// Stream of audio player state changes.
  Stream<PlayerState> get playerStateStream;

  /// Releases resources held by the recorder and player.
  void dispose();
}

/// Production implementation of [IAudioService] using package:record and package:audioplayers.
class RelayAudioService implements IAudioService {
  RelayAudioService({
    AudioRecorder? recorder,
    AudioPlayer? player,
  })  : _recorder = recorder ?? AudioRecorder(),
        _player = player ?? AudioPlayer();

  final AudioRecorder _recorder;
  final AudioPlayer _player;

  final List<double> _rawAmplitudes = [];
  final StreamController<double> _liveAmplitudeController =
      StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  DateTime? _recordingStartTime;
  String? _currentRecordingPath;
  bool _isRecording = false;

  @override
  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  @override
  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      throw StateError('Microphone permission not granted');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${tempDir.path}/rec_$timestamp.m4a';

    _currentRecordingPath = filePath;
    _rawAmplitudes.clear();
    _recordingStartTime = DateTime.now();

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 32000,
      sampleRate: 44100,
      numChannels: 1,
    );

    await _recorder.start(config, path: filePath);
    _isRecording = true;

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 70))
        .listen((amp) {
      // amp.current is in dBFS (typically -60.0 to 0.0)
      final normalized = _normalizeDecibels(amp.current);
      _rawAmplitudes.add(normalized);
      if (!_liveAmplitudeController.isClosed) {
        _liveAmplitudeController.add(normalized);
      }
    });
  }

  @override
  Future<({String path, Duration duration, List<double> waveform})?> stopRecording() async {
    if (!_isRecording) return null;

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    final path = await _recorder.stop();
    _isRecording = false;

    final duration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!)
        : Duration.zero;

    final effectivePath = path ?? _currentRecordingPath;
    if (effectivePath == null || !File(effectivePath).existsSync()) {
      return null;
    }

    final waveform = resampleWaveform(_rawAmplitudes, 32);

    return (
      path: effectivePath,
      duration: duration,
      waveform: waveform,
    );
  }

  @override
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    final path = await _recorder.stop();
    _isRecording = false;

    final effectivePath = path ?? _currentRecordingPath;
    if (effectivePath != null) {
      final file = File(effectivePath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    _currentRecordingPath = null;
    _rawAmplitudes.clear();
  }

  @override
  Stream<double> get liveAmplitudeStream => _liveAmplitudeController.stream;

  @override
  Future<void> play(String sourcePath) async {
    Source source;
    if (sourcePath.startsWith('http://') || sourcePath.startsWith('https://')) {
      source = UrlSource(sourcePath);
    } else {
      source = DeviceFileSource(sourcePath);
    }
    await _player.play(source);
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    await _player.resume();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> setPlaybackRate(double speed) async {
    await _player.setPlaybackRate(speed);
  }

  @override
  Stream<Duration> get positionStream => _player.onPositionChanged;

  @override
  Stream<Duration?> get durationStream => _player.onDurationChanged;

  @override
  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _liveAmplitudeController.close();
    _recorder.dispose();
    _player.dispose();
  }

  /// Normalizes dBFS (-60 dB to 0 dB) to 0.0 - 1.0.
  static double _normalizeDecibels(double db) {
    if (db.isNaN || db.isInfinite) return 0.15;
    if (db <= -60) return 0.15;
    if (db >= 0) return 1.0;
    // Map -60..0 dB to 0.15..1.0 linearly
    final ratio = (db + 60) / 60.0;
    return (0.15 + 0.85 * ratio).clamp(0.15, 1.0);
  }

  /// Downsamples or interpolates an arbitrary list of amplitude samples into [targetBars] items.
  static List<double> resampleWaveform(List<double> samples, int targetBars) {
    if (samples.isEmpty) {
      return List.filled(targetBars, 0.25);
    }

    if (samples.length == targetBars) {
      return samples.map((s) => s.clamp(0.15, 1.0)).toList();
    }

    final result = <double>[];

    if (samples.length < targetBars) {
      // Upsample with smooth linear interpolation
      for (var i = 0; i < targetBars; i++) {
        final position = i * (samples.length - 1) / (targetBars - 1);
        final lowerIndex = position.floor();
        final upperIndex = position.ceil().clamp(0, samples.length - 1);
        final fraction = position - lowerIndex;

        final interpolated = (1.0 - fraction) * samples[lowerIndex] +
            fraction * samples[upperIndex];
        result.add(interpolated.clamp(0.15, 1.0));
      }
      return result;
    }

    // Downsample using peak amplitude per bucket
    final bucketSize = samples.length / targetBars;
    for (var i = 0; i < targetBars; i++) {
      final startIndex = (i * bucketSize).floor();
      final endIndex = ((i + 1) * bucketSize).ceil().clamp(0, samples.length);

      var peak = 0.15;
      for (var j = startIndex; j < endIndex; j++) {
        peak = math.max(peak, samples[j]);
      }
      result.add(peak.clamp(0.15, 1.0));
    }

    return result;
  }
}

/// Fallback in-memory implementation of [IAudioService] for testing, demo mode,
/// and environments without native audio hardware/plugins.
class NoOpAudioService implements IAudioService {
  final _liveAmplitude = StreamController<double>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> startRecording() async {}

  @override
  Future<({String path, Duration duration, List<double> waveform})?> stopRecording() async {
    return (
      path: '',
      duration: Duration.zero,
      waveform: List.filled(32, 0.25),
    );
  }

  @override
  Future<void> cancelRecording() async {}

  @override
  Stream<double> get liveAmplitudeStream => _liveAmplitude.stream;

  @override
  Future<void> play(String sourcePath) async {
    _playerStateController.add(PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    _playerStateController.add(PlayerState.paused);
  }

  @override
  Future<void> resume() async {
    _playerStateController.add(PlayerState.playing);
  }

  @override
  Future<void> stop() async {
    _playerStateController.add(PlayerState.stopped);
  }

  @override
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> setPlaybackRate(double speed) async {}

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  void dispose() {
    _liveAmplitude.close();
    _positionController.close();
    _durationController.close();
    _playerStateController.close();
  }
}
