import 'dart:async';
import 'dart:io';

/// Represents device network reachability states.
enum NetworkStatus {
  online,
  connecting,
  offline;

  bool get isOnline => this == NetworkStatus.online;
  bool get isOffline => this == NetworkStatus.offline;
  bool get isConnecting => this == NetworkStatus.connecting;
}

/// Abstract contract for device network connectivity tracking.
abstract class IConnectivityService {
  Stream<NetworkStatus> get statusStream;
  NetworkStatus get currentStatus;
  Future<bool> checkReachability();
  void dispose();
}

/// Production connectivity monitor relying on lightweight DNS socket probes
/// ($0 cost, native cross-platform reachability verification).
class RelayConnectivityService implements IConnectivityService {
  RelayConnectivityService({
    Duration onlineInterval = const Duration(seconds: 15),
    Duration offlineInterval = const Duration(seconds: 4),
  })  : _onlineInterval = onlineInterval,
        _offlineInterval = offlineInterval {
    _startMonitoring();
  }

  final Duration _onlineInterval;
  final Duration _offlineInterval;
  final _statusController = StreamController<NetworkStatus>.broadcast();

  NetworkStatus _currentStatus = NetworkStatus.online;
  Timer? _pollTimer;
  bool _isDisposed = false;

  @override
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  @override
  NetworkStatus get currentStatus => _currentStatus;

  void _startMonitoring() {
    // Initial immediate probe
    checkReachability();
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    if (_isDisposed) return;
    _pollTimer?.cancel();
    final interval = _currentStatus == NetworkStatus.online
        ? _onlineInterval
        : _offlineInterval;
    _pollTimer = Timer(interval, () async {
      await checkReachability();
      _scheduleNextPoll();
    });
  }

  @override
  Future<bool> checkReachability() async {
    if (_isDisposed) return _currentStatus == NetworkStatus.online;

    bool reachable = false;
    try {
      // Probe Cloudflare DNS or Google DNS on port 53 (TCP handshake timeout 2s)
      final socket = await Socket.connect(
        '1.1.1.1',
        53,
        timeout: const Duration(seconds: 2),
      ).timeout(const Duration(seconds: 2));
      socket.destroy();
      reachable = true;
    } catch (_) {
      try {
        final socket = await Socket.connect(
          '8.8.8.8',
          53,
          timeout: const Duration(seconds: 2),
        ).timeout(const Duration(seconds: 2));
        socket.destroy();
        reachable = true;
      } catch (_) {
        reachable = false;
      }
    }

    final newStatus = reachable ? NetworkStatus.online : NetworkStatus.offline;
    if (_currentStatus != newStatus && !_isDisposed) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
    return reachable;
  }

  /// Exclusively for testing: override network status directly without network calls.
  void setStatusForTesting(NetworkStatus status) {
    if (_currentStatus != status && !_isDisposed) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollTimer?.cancel();
    _statusController.close();
  }
}
