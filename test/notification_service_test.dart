import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/notification_service.dart';

void main() {
  group('NotificationPayload Model Tests', () {
    test('serializes to and from Map correctly', () {
      final now = DateTime.now();
      final payload = NotificationPayload(
        id: 'msg_101',
        chatId: 'chat_aisha',
        title: 'Aisha Chowdhury',
        body: 'Testing encrypted delivery',
        avatarUrl: 'assets/avatars/aisha.png',
        timestamp: now,
        data: {'extraKey': 'extraValue'},
      );

      final map = payload.toMap();
      expect(map['id'], 'msg_101');
      expect(map['chatId'], 'chat_aisha');
      expect(map['title'], 'Aisha Chowdhury');
      expect(map['body'], 'Testing encrypted delivery');
      expect(map['avatarUrl'], 'assets/avatars/aisha.png');
      expect(map['timestamp'], now.millisecondsSinceEpoch);
      expect(map['data'], {'extraKey': 'extraValue'});

      final fromMap = NotificationPayload.fromMap(map);
      expect(fromMap.id, payload.id);
      expect(fromMap.chatId, payload.chatId);
      expect(fromMap.title, payload.title);
      expect(fromMap.body, payload.body);
      expect(fromMap.avatarUrl, payload.avatarUrl);
      expect(fromMap.data, payload.data);
    });

    test('serializes to and from JSON string correctly', () {
      final now = DateTime.now();
      final payload = NotificationPayload(
        id: 'msg_202',
        chatId: 'chat_group_1',
        title: 'Engineering Team',
        body: 'Meeting in 5 minutes',
        timestamp: now,
      );

      final jsonStr = payload.toJson();
      final fromJson = NotificationPayload.fromJson(jsonStr);

      expect(fromJson.id, 'msg_202');
      expect(fromJson.chatId, 'chat_group_1');
      expect(fromJson.title, 'Engineering Team');
      expect(fromJson.body, 'Meeting in 5 minutes');
    });

    test('copyWith properly updates specific fields', () {
      final payload = NotificationPayload(
        id: 'initial_id',
        chatId: 'chat_1',
        title: 'User A',
        body: 'Initial body',
        timestamp: DateTime(2026, 9, 1),
      );

      final updated = payload.copyWith(
        body: 'Updated body text',
        title: 'User B',
      );

      expect(updated.id, 'initial_id');
      expect(updated.chatId, 'chat_1');
      expect(updated.title, 'User B');
      expect(updated.body, 'Updated body text');
    });
  });

  group('MockNotificationService Lifecycle Tests', () {
    late MockNotificationService service;

    setUp(() {
      service = MockNotificationService();
    });

    tearDown(() {
      service.dispose();
    });

    test('requests permissions and retrieves mock token', () async {
      final granted = await service.requestPermissions();
      expect(granted, isTrue);

      final token = await service.getFcmToken();
      expect(token, 'mock_fcm_token_12345');
    });

    test('shows local notifications with preview text enabled', () async {
      final payload = NotificationPayload(
        id: 'notif_1',
        chatId: 'chat_1',
        title: 'Aisha',
        body: 'Private message content',
        timestamp: DateTime.now(),
      );

      await service.showLocalNotification(payload: payload, showPreview: true);
      expect(service.displayedNotifications.length, 1);
      expect(service.displayedNotifications.first.body, 'Private message content');
    });

    test('replaces body with "New message" when showPreview is false', () async {
      final payload = NotificationPayload(
        id: 'notif_2',
        chatId: 'chat_2',
        title: 'Rahim',
        body: 'Sensitive secret',
        timestamp: DateTime.now(),
      );

      await service.showLocalNotification(payload: payload, showPreview: false);
      expect(service.displayedNotifications.length, 1);
      expect(service.displayedNotifications.first.body, 'New message');
    });

    test('cancels notifications by ID and cancelAll clears list', () async {
      final p1 = NotificationPayload(
        id: '10',
        chatId: 'c1',
        title: 'T1',
        body: 'B1',
        timestamp: DateTime.now(),
      );
      final p2 = NotificationPayload(
        id: '20',
        chatId: 'c2',
        title: 'T2',
        body: 'B2',
        timestamp: DateTime.now(),
      );

      await service.showLocalNotification(payload: p1);
      await service.showLocalNotification(payload: p2);
      expect(service.displayedNotifications.length, 2);

      await service.cancelNotification(p1.id.hashCode & 0x7FFFFFFF);
      expect(service.displayedNotifications.length, 1);
      expect(service.displayedNotifications.first.id, '20');

      await service.cancelAll();
      expect(service.displayedNotifications.isEmpty, isTrue);
    });

    test('simulates token refresh stream', () async {
      final tokenExpectation = expectLater(
        service.onTokenRefresh,
        emitsInOrder(['token_abc', 'token_xyz']),
      );

      service.simulateTokenRefresh('token_abc');
      service.simulateTokenRefresh('token_xyz');

      await tokenExpectation;
      expect(await service.getFcmToken(), 'token_xyz');
    });

    test('simulates notification tap stream and callback', () async {
      NotificationPayload? tappedFromCallback;
      await service.initialize(
        onNotificationTapped: (payload) {
          tappedFromCallback = payload;
        },
      );

      final payload = NotificationPayload(
        id: 'tap_1',
        chatId: 'chat_tapped',
        title: 'Sender',
        body: 'Tap test',
        timestamp: DateTime.now(),
      );

      final streamExpectation = expectLater(
        service.onNotificationOpened,
        emits(payload),
      );

      service.simulateNotificationTapped(payload);
      await streamExpectation;
      expect(tappedFromCallback?.chatId, 'chat_tapped');
    });
  });
}
