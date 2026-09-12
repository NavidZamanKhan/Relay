import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Structured payload representing an incoming notification in Relay.
class NotificationPayload {
  const NotificationPayload({
    required this.id,
    required this.chatId,
    required this.title,
    required this.body,
    this.avatarUrl,
    required this.timestamp,
    this.data = const {},
  });

  final String id;
  final String chatId;
  final String title;
  final String body;
  final String? avatarUrl;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  Map<String, dynamic> toMap() => {
        'id': id,
        'chatId': chatId,
        'title': title,
        'body': body,
        'avatarUrl': avatarUrl,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'data': data,
      };

  factory NotificationPayload.fromMap(Map<String, dynamic> map) {
    return NotificationPayload(
      id: map['id'] as String? ?? '',
      chatId: map['chatId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'] as Map)
          : const {},
    );
  }

  String toJson() => jsonEncode(toMap());

  factory NotificationPayload.fromJson(String source) =>
      NotificationPayload.fromMap(jsonDecode(source) as Map<String, dynamic>);

  NotificationPayload copyWith({
    String? id,
    String? chatId,
    String? title,
    String? body,
    String? avatarUrl,
    DateTime? timestamp,
    Map<String, dynamic>? data,
  }) {
    return NotificationPayload(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      title: title ?? this.title,
      body: body ?? this.body,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
    );
  }
}

/// Abstract contract for unified push and local notification management.
abstract class INotificationService {
  /// Stream that emits whenever a user taps a system notification.
  Stream<NotificationPayload> get onNotificationOpened;

  /// Stream that emits whenever the FCM/APNs registration token refreshes.
  Stream<String> get onTokenRefresh;

  /// Initialize local notification plugins and Firebase Messaging listeners.
  Future<void> initialize({
    void Function(NotificationPayload payload)? onNotificationTapped,
  });

  /// Request notification permissions on iOS and Android 13+.
  Future<bool> requestPermissions();

  /// Retrieve the active FCM registration token for device delivery.
  Future<String?> getFcmToken();

  /// Display a heads-up or system notification banner on the device.
  Future<void> showLocalNotification({
    required NotificationPayload payload,
    bool showPreview = true,
  });

  /// Cancel a specific active notification by numeric ID.
  Future<void> cancelNotification(int id);

  /// Dismiss all active system notifications for this app.
  Future<void> cancelAll();

  /// Clean up active streams and listeners.
  void dispose();
}

/// Production notification service combining Flutter Local Notifications
/// and Firebase Cloud Messaging under a $0 infrastructure model.
class RelayNotificationService implements INotificationService {
  RelayNotificationService({
    FlutterLocalNotificationsPlugin? localNotifications,
    FirebaseMessaging? messaging,
  })  : _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _messaging = messaging;

  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirebaseMessaging? _messaging;

  final StreamController<NotificationPayload> _notificationOpenedController =
      StreamController<NotificationPayload>.broadcast();
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();

  StreamSubscription<RemoteMessage>? _fcmForegroundSub;
  StreamSubscription<RemoteMessage>? _fcmOpenedSub;
  StreamSubscription<String>? _tokenSub;
  bool _isInitialized = false;

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'relay_messages',
    'Relay Messages',
    description: 'Notifications for incoming encrypted Relay messages',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  @override
  Stream<NotificationPayload> get onNotificationOpened =>
      _notificationOpenedController.stream;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Future<void> initialize({
    void Function(NotificationPayload payload)? onNotificationTapped,
  }) async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payloadStr = response.payload;
          if (payloadStr != null && payloadStr.isNotEmpty) {
            try {
              final payload = NotificationPayload.fromJson(payloadStr);
              _notificationOpenedController.add(payload);
              onNotificationTapped?.call(payload);
            } catch (_) {}
          }
        },
      );

      if (!kIsWeb && Platform.isAndroid) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_defaultChannel);
      }
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('Local notifications initialization handled: $e');
      }
    }

    _setupFirebaseMessaging(onNotificationTapped);
  }

  void _setupFirebaseMessaging(
    void Function(NotificationPayload payload)? onNotificationTapped,
  ) {
    try {
      final messaging = _messaging ?? FirebaseMessaging.instance;

      messaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
          .then((_) {}, onError: (_) {});

      messaging
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: true,
          )
          .catchError((_) {});

      _fcmForegroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // App is actively in the foreground. Firestore real-time listeners update UI in-place.
        // In-app notifications and alerts are suppressed per user design.
      });

      _fcmOpenedSub =
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final payload = _payloadFromRemoteMessage(message);
        if (payload != null) {
          _notificationOpenedController.add(payload);
          onNotificationTapped?.call(payload);
        }
      });

      messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          final payload = _payloadFromRemoteMessage(message);
          if (payload != null) {
            _notificationOpenedController.add(payload);
            onNotificationTapped?.call(payload);
          }
        }
      }).catchError((_) {});

      _tokenSub = messaging.onTokenRefresh.listen((token) {
        _tokenRefreshController.add(token);
      });
    } catch (e) {
      debugPrint('Firebase messaging listeners handled: $e');
    }
  }

  NotificationPayload? _payloadFromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final chatId = data['chatId']?.toString() ?? '';
    final title = message.notification?.title ?? data['title']?.toString() ?? 'Relay';
    final body = message.notification?.body ?? data['body']?.toString() ?? '';
    final avatarUrl = data['avatarUrl']?.toString();

    if (chatId.isEmpty && body.isEmpty) return null;

    return NotificationPayload(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: chatId,
      title: title,
      body: body,
      avatarUrl: avatarUrl,
      timestamp: message.sentTime ?? DateTime.now(),
      data: data,
    );
  }

  @override
  Future<bool> requestPermissions() async {
    bool granted = false;

    try {
      if (!kIsWeb && Platform.isIOS) {
        final iosGranted = await _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        granted = iosGranted ?? false;
      } else if (!kIsWeb && Platform.isAndroid) {
        final androidGranted = await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        granted = androidGranted ?? false;
      }
    } catch (_) {}

    try {
      final messaging = _messaging ?? FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        granted = true;
      }
    } catch (_) {}

    return granted;
  }

  @override
  Future<String?> getFcmToken() async {
    try {
      final messaging = _messaging ?? FirebaseMessaging.instance;
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          return null;
        }
      }
      return await messaging.getToken();
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('Could not retrieve FCM token: $e');
      }
      return null;
    }
  }

  @override
  Future<void> showLocalNotification({
    required NotificationPayload payload,
    bool showPreview = true,
  }) async {
    try {
      final notificationId = payload.id.hashCode & 0x7FFFFFFF;
      final effectiveBody = showPreview ? payload.body : 'New message';

      final androidDetails = AndroidNotificationDetails(
        _defaultChannel.id,
        _defaultChannel.name,
        channelDescription: _defaultChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        showWhen: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.show(
        id: notificationId,
        title: payload.title,
        body: effectiveBody,
        notificationDetails: details,
        payload: payload.toJson(),
      );
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('Local notification show handled: $e');
      }
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id: id);
    } catch (_) {}
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _localNotifications.cancelAll();
    } catch (_) {}
  }

  /// Testing hook: manually dispatch an opened notification payload.
  void simulateNotificationTapped(NotificationPayload payload) {
    _notificationOpenedController.add(payload);
  }

  /// Testing hook: manually dispatch a refreshed token.
  void simulateTokenRefresh(String token) {
    _tokenRefreshController.add(token);
  }

  @override
  void dispose() {
    _fcmForegroundSub?.cancel();
    _fcmOpenedSub?.cancel();
    _tokenSub?.cancel();
    _notificationOpenedController.close();
    _tokenRefreshController.close();
  }
}

/// Standalone test mock for [INotificationService] ensuring zero native platform dependency.
class MockNotificationService implements INotificationService {
  final StreamController<NotificationPayload> _openedController =
      StreamController<NotificationPayload>.broadcast();
  final StreamController<String> _tokenController =
      StreamController<String>.broadcast();

  final List<NotificationPayload> displayedNotifications = [];
  bool permissionsGranted = true;
  String? mockToken = 'mock_fcm_token_12345';

  @override
  Stream<NotificationPayload> get onNotificationOpened =>
      _openedController.stream;

  @override
  Stream<String> get onTokenRefresh => _tokenController.stream;

  @override
  Future<void> initialize({
    void Function(NotificationPayload payload)? onNotificationTapped,
  }) async {
    _openedController.stream.listen(onNotificationTapped);
  }

  @override
  Future<bool> requestPermissions() async => permissionsGranted;

  @override
  Future<String?> getFcmToken() async => mockToken;

  @override
  Future<void> showLocalNotification({
    required NotificationPayload payload,
    bool showPreview = true,
  }) async {
    final effective = showPreview
        ? payload
        : payload.copyWith(body: 'New message');
    displayedNotifications.add(effective);
  }

  @override
  Future<void> cancelNotification(int id) async {
    displayedNotifications.removeWhere((n) => (n.id.hashCode & 0x7FFFFFFF) == id);
  }

  @override
  Future<void> cancelAll() async {
    displayedNotifications.clear();
  }

  void simulateNotificationTapped(NotificationPayload payload) {
    _openedController.add(payload);
  }

  void simulateTokenRefresh(String token) {
    mockToken = token;
    _tokenController.add(token);
  }

  @override
  void dispose() {
    _openedController.close();
    _tokenController.close();
  }
}
