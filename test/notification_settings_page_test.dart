import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/app_bloc.dart';
import 'package:relay/core/services/notification_service.dart';
import 'package:relay/features/settings/views/notification_settings_page.dart';

void main() {
  group('NotificationSettingsPage Widget Tests', () {
    late AppBloc appBloc;
    late MockNotificationService notificationService;

    setUp(() {
      appBloc = AppBloc();
      notificationService = MockNotificationService();
    });

    tearDown(() {
      appBloc.close();
      notificationService.dispose();
    });

    testWidgets('renders all preferences and triggers test notification', (tester) async {
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<INotificationService>.value(
              value: notificationService,
            ),
          ],
          child: BlocProvider<AppBloc>.value(
            value: appBloc,
            child: const MaterialApp(
              home: NotificationSettingsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Message notifications'), findsOneWidget);
      expect(find.text('Message previews'), findsOneWidget);
      expect(find.text('Quiet hours'), findsOneWidget);
      expect(find.text('Test alert banner'), findsOneWidget);
      expect(find.text('Check system permissions'), findsOneWidget);

      // Verify toggling quiet hours
      final quietHoursSwitchFinder = find.widgetWithText(
        SwitchListTile,
        'Quiet hours',
      );
      expect(quietHoursSwitchFinder, findsOneWidget);
      final initialSwitch = tester.widget<SwitchListTile>(quietHoursSwitchFinder);
      expect(initialSwitch.value, isFalse);

      await tester.tap(quietHoursSwitchFinder);
      await tester.pumpAndSettle();
      expect(appBloc.state.preferences['Quiet hours'], isTrue);

      // Scroll until test alert banner is visible
      await tester.scrollUntilVisible(
        find.text('Test alert banner'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // Tap test alert banner button
      await tester.tap(find.text('Test alert banner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify in-app banner appears for test message
      expect(find.text('Aisha Chowdhury'), findsOneWidget);
    });

    testWidgets('taps Check system permissions button', (tester) async {
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<INotificationService>.value(
              value: notificationService,
            ),
          ],
          child: BlocProvider<AppBloc>.value(
            value: appBloc,
            child: const MaterialApp(
              home: NotificationSettingsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final checkPermissionsButton = find.text('Check system permissions');
      expect(checkPermissionsButton, findsOneWidget);

      await tester.tap(checkPermissionsButton);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Notification permissions enabled'), findsOneWidget);
    });
  });
}
