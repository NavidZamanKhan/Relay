import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/notification_service.dart';
import 'package:relay/features/chats/widgets/in_app_notification_banner.dart';

void main() {
  group('InAppNotificationBanner Widget Tests', () {
    testWidgets('renders banner with sender title, preview body, and avatar', (tester) async {
      final payload = NotificationPayload(
        id: 'msg_999',
        chatId: 'chat_test',
        title: 'Kazi Nazrul',
        body: 'Where the mind is without fear',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                InAppNotificationBanner(
                  payload: payload,
                  showPreview: true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kazi Nazrul'), findsOneWidget);
      expect(find.text('Where the mind is without fear'), findsOneWidget);
      expect(find.text('now'), findsOneWidget);
    });

    testWidgets('respects showPreview false by masking message content', (tester) async {
      final payload = NotificationPayload(
        id: 'msg_private',
        chatId: 'chat_secure',
        title: 'Secret Agent',
        body: 'Top secret rendezvous at 0700',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                InAppNotificationBanner(
                  payload: payload,
                  showPreview: false,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Secret Agent'), findsOneWidget);
      expect(find.text('New message'), findsOneWidget);
      expect(find.text('Top secret rendezvous at 0700'), findsNothing);
    });

    testWidgets('tap triggers onTap callback', (tester) async {
      bool tapped = false;
      final payload = NotificationPayload(
        id: 'msg_tap',
        chatId: 'chat_tap',
        title: 'Aisha',
        body: 'Tap on me',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                InAppNotificationBanner(
                  payload: payload,
                  onTap: () {
                    tapped = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Aisha'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('close button dismisses banner', (tester) async {
      bool dismissed = false;
      final payload = NotificationPayload(
        id: 'msg_close',
        chatId: 'chat_close',
        title: 'Dismiss Me',
        body: 'Click xmark to close',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                InAppNotificationBanner(
                  payload: payload,
                  onDismissed: () {
                    dismissed = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final closeButtonFinder = find.byType(IconButton);
      expect(closeButtonFinder, findsOneWidget);

      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('dragging upward dismisses banner', (tester) async {
      bool dismissed = false;
      final payload = NotificationPayload(
        id: 'msg_drag',
        chatId: 'chat_drag',
        title: 'Drag Up',
        body: 'Swipe upwards to dismiss',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                InAppNotificationBanner(
                  payload: payload,
                  onDismissed: () {
                    dismissed = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.drag(find.text('Drag Up'), const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('InAppNotificationBanner.show displays via navigatorKey fallback', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      InAppNotificationBanner.navigatorKey = navKey;

      final payload = NotificationPayload(
        id: 'msg_overlay_fallback',
        chatId: 'chat_fallback',
        title: 'Navid Zaman',
        body: 'In-app notification works cleanly',
        timestamp: DateTime.now(),
      );

      late BuildContext builderContext;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          builder: (context, child) {
            builderContext = context;
            return child ?? const SizedBox.shrink();
          },
          home: const Scaffold(
            body: Center(child: Text('Home Page')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Show banner from the builderContext (which has no Overlay ancestor)
      InAppNotificationBanner.show(
        builderContext,
        payload: payload,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Navid Zaman'), findsOneWidget);
      expect(find.text('In-app notification works cleanly'), findsOneWidget);

      InAppNotificationBanner.dismiss();
      await tester.pumpAndSettle();

      expect(find.text('Navid Zaman'), findsNothing);
    });
  });
}
