import 'package:flutter/widgets.dart';
import 'repositories/i_user_repository.dart';

/// Monitors application lifecycle states to update user presence in Cloud Firestore.
class PresenceObserver with WidgetsBindingObserver {
  PresenceObserver({
    required IUserRepository userRepository,
    required String Function() getUserId,
  })  : _userRepository = userRepository,
        _getUserId = getUserId;

  final IUserRepository _userRepository;
  final String Function() _getUserId;
  bool _initialized = false;

  void start() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
  }

  void stop() {
    if (!_initialized) return;
    _initialized = false;
    _setOnline(false);
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setOnline(false);
    }
  }

  void _setOnline(bool isOnline) {
    final uid = _getUserId();
    if (uid.isNotEmpty) {
      _userRepository.updatePresence(uid: uid, isOnline: isOnline);
    }
  }
}
