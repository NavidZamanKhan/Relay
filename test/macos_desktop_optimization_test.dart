import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/app_bloc.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/features/auth/auth_bloc.dart';
import 'package:relay/features/auth/auth_scaffold.dart';
import 'package:relay/features/auth/models/user_profile.dart';
import 'package:relay/features/auth/phone_entry_page.dart';
import 'package:relay/features/auth/repositories/i_user_repository.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/message_composer.dart';
import 'package:relay/features/settings/settings_page.dart';

import 'auth_gate_session_test.dart';

class _MockUserRepo implements IUserRepository {
  @override
  Future<UserProfile?> getUserProfile(String uid) async => null;

  @override
  Future<void> saveUserProfile(UserProfile profile) async {}

  @override
  Future<void> updatePresence({required String uid, required bool isOnline}) async {}

  @override
  Future<void> updateFcmToken({required String uid, required String? token}) async {}

  @override
  Stream<UserProfile?> watchUserProfile(String uid) => Stream.value(null);

  @override
  Future<void> deleteUserProfile(String uid) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('macOS Desktop Layout & AuthScaffold Tests', () {
    testWidgets('AuthScaffold renders centered card on desktop width >= 640', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScaffold(
            eyebrow: 'Welcome to Relay',
            title: 'Desktop Onboarding',
            subtitle: 'Centered card test',
            child: Text('Card Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final desktopCardBox = constrainedBoxes.where((cb) => cb.constraints.maxWidth == 460);
      expect(desktopCardBox.isNotEmpty, isTrue);

      expect(find.text('WELCOME TO RELAY'), findsOneWidget);
      expect(find.text('Desktop Onboarding'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('AuthScaffold renders full-width layout on mobile width < 640', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScaffold(
            eyebrow: 'Welcome to Relay',
            title: 'Mobile Onboarding',
            subtitle: 'Full width test',
            child: Text('Mobile Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final desktopCardBox = constrainedBoxes.where((cb) => cb.constraints.maxWidth == 460);
      expect(desktopCardBox.isEmpty, isTrue);

      expect(find.text('WELCOME TO RELAY'), findsOneWidget);
      expect(find.text('Mobile Onboarding'), findsOneWidget);
    });
  });

  group('PhoneEntryPage Keyboard Submission Tests', () {
    late AuthBloc authBloc;
    late MockAuthRepository mockAuth;
    late _MockUserRepo mockUser;

    setUp(() {
      mockAuth = MockAuthRepository();
      mockUser = _MockUserRepo();
      FlutterSecureStorage.setMockInitialValues({});
      authBloc = AuthBloc(
        authRepository: mockAuth,
        userRepository: mockUser,
        cryptoService: CryptoService(),
      );
    });

    tearDown(() async {
      await authBloc.close();
    });

    testWidgets('Submitting phone number via Enter key dispatches AuthPhoneSubmitted', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const PhoneEntryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter a valid phone number and submit via TextInputAction.go
      final phoneField = find.byType(TextField);
      expect(phoneField, findsOneWidget);

      await tester.enterText(phoneField, '650-555-1234');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(authBloc.state.phone, equals('+8806505551234'));
      expect(authBloc.state.step, equals(AuthStep.otp));
    });
  });

  group('MessageComposer Desktop Enter-to-Send Tests', () {
    late ChatBloc chatBloc;

    setUp(() {
      chatBloc = ChatBloc(demoMode: true);
    });

    tearDown(() async {
      await chatBloc.close();
    });

    testWidgets('Pressing plain Enter sends text message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<ChatBloc>.value(
              value: chatBloc,
              child: const MessageComposer(contactName: 'Test Contact'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Enter text
      await tester.enterText(textField, 'Hello macOS desktop');
      await tester.pump();
      expect(chatBloc.state.composerText, equals('Hello macOS desktop'));

      // Press Enter key
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // After Enter send, composerText is cleared and message added
      expect(chatBloc.state.composerText, isEmpty);
      expect(
        chatBloc.state.messages.any((m) => m.text == 'Hello macOS desktop'),
        isTrue,
      );
    });
  });

  group('SettingsPage Desktop Ergonomics Tests', () {
    testWidgets('SettingsPage with showBackButton false omits leading back chevron', (tester) async {
      final appBloc = AppBloc();
      final mockAuth = MockAuthRepository();
      final mockUser = _MockUserRepo();
      FlutterSecureStorage.setMockInitialValues({});
      final authBloc = AuthBloc(
        authRepository: mockAuth,
        userRepository: mockUser,
        cryptoService: CryptoService(),
      );

      addTearDown(() async {
        await appBloc.close();
        await authBloc.close();
      });

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AppBloc>.value(value: appBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const MaterialApp(
            home: SettingsPage(showBackButton: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.chevron_left), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('SettingsPage with showBackButton true displays leading back chevron', (tester) async {
      final appBloc = AppBloc();
      final mockAuth = MockAuthRepository();
      final mockUser = _MockUserRepo();
      FlutterSecureStorage.setMockInitialValues({});
      final authBloc = AuthBloc(
        authRepository: mockAuth,
        userRepository: mockUser,
        cryptoService: CryptoService(),
      );

      addTearDown(() async {
        await appBloc.close();
        await authBloc.close();
      });

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AppBloc>.value(value: appBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const MaterialApp(
            home: SettingsPage(showBackButton: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.chevron_left), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
