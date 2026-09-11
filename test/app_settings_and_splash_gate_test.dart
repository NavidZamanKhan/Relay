import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/app_bloc.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/core/services/app_settings_storage.dart';
import 'package:relay/features/auth/auth_bloc.dart';
import 'package:relay/features/auth/relay_gate.dart';
import 'package:relay/features/auth/repositories/i_user_repository.dart';
import 'package:relay/features/auth/widgets/relay_splash_screen.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/models/conversation.dart';
import 'package:relay/features/chats/models/relay_message.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';
import 'package:relay/features/chats/widgets/image_attachment_preview_sheet.dart';

import 'auth_gate_session_test.dart';

class FakeChatRepository extends Fake implements IChatRepository {
  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      Stream.value([]);

  @override
  Stream<List<RelayMessage>> watchMessages(
    String chatId,
    String currentUserId,
  ) =>
      Stream.value([]);
}

void main() {
  group('AppSettingsStorage Persistence Tests', () {
    late Directory tempDir;
    late AppSettingsStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('relay_settings_test_');
      storage = AppSettingsStorage(customDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns default AppState when settings file does not exist', () async {
      final state = await storage.loadSettings();
      expect(state.themeMode, ThemeMode.system);
      expect(state.preferences['Last seen'], isTrue);
      expect(state.cacheMb, 186);
    });

    test('persists and reloads dark themeMode and updated preferences', () async {
      const customState = AppState(
        themeMode: ThemeMode.dark,
        cacheMb: 42,
        preferences: {
          'Last seen': false,
          'Read receipts': false,
          'App lock': true,
        },
      );

      await storage.saveSettings(customState);
      final loaded = await storage.loadSettings();

      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.cacheMb, 42);
      expect(loaded.preferences['Last seen'], isFalse);
      expect(loaded.preferences['Read receipts'], isFalse);
      expect(loaded.preferences['App lock'], isTrue);
    });

    test('falls back gracefully to defaults on corrupted file content', () async {
      final file = File('${tempDir.path}/relay_settings.json');
      await file.writeAsString('{not-valid-json-syntax}');

      final loaded = await storage.loadSettings();
      expect(loaded.themeMode, ThemeMode.system);
      expect(loaded.cacheMb, 186);
    });
  });

  group('AppBloc Theme & Preference Persistence Tests', () {
    late Directory tempDir;
    late AppSettingsStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('relay_app_bloc_test_');
      storage = AppSettingsStorage(customDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('AppThemeChanged saves updated themeMode to disk storage', () async {
      final bloc = AppBloc(storage: storage);
      bloc.add(const AppThemeChanged(ThemeMode.dark));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AppState>((s) => s.themeMode == ThemeMode.dark),
        ),
      );

      final loaded = await storage.loadSettings();
      expect(loaded.themeMode, ThemeMode.dark);

      await bloc.close();
    });

    test('AppPreferenceChanged saves updated preference to disk storage', () async {
      final bloc = AppBloc(storage: storage);
      bloc.add(const AppPreferenceChanged('Last seen', false));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AppState>((s) => s.preferences['Last seen'] == false),
        ),
      );

      final loaded = await storage.loadSettings();
      expect(loaded.preferences['Last seen'], isFalse);

      await bloc.close();
    });

    test('initialState restores saved state immediately upon construction', () {
      const savedState = AppState(
        themeMode: ThemeMode.dark,
        cacheMb: 99,
        preferences: {'App lock': true},
      );

      final bloc = AppBloc(initialState: savedState, storage: storage);
      expect(bloc.state.themeMode, ThemeMode.dark);
      expect(bloc.state.cacheMb, 99);
      expect(bloc.state.preferences['App lock'], isTrue);

      bloc.close();
    });
  });

  group('RelaySplashScreen & Gate Gatekeeper Tests', () {
    testWidgets('RelaySplashScreen renders logo, brand title, and loading caption', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RelaySplashScreen(),
        ),
      );

      expect(find.text('Relay'), findsOneWidget);
      expect(find.text('Securing connection...'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('RelayGate displays RelaySplashScreen during AuthStep.initial', (tester) async {
      final authRepo = MockAuthRepository();
      final userRepo = MockUserRepository();
      final cryptoService = CryptoService(storage: FakeSecureStorage());
      final chatRepo = FakeChatRepository();

      final authBloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        cryptoService: cryptoService,
        previewAuthenticated: false,
      );
      final chatBloc = ChatBloc(chatRepository: chatRepo, demoMode: true);

      expect(authBloc.state.step, AuthStep.initial);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<IUserRepository>.value(value: userRepo),
            RepositoryProvider<IChatRepository>.value(value: chatRepo),
            RepositoryProvider<CryptoService>.value(value: cryptoService),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<ChatBloc>.value(value: chatBloc),
              BlocProvider<AppBloc>(create: (_) => AppBloc()),
            ],
            child: const MaterialApp(
              home: RelayGate(),
            ),
          ),
        ),
      );

      // Verify that RelaySplashScreen is displayed while in AuthStep.initial
      expect(find.byType(RelaySplashScreen), findsOneWidget);
      expect(find.text('Securing connection...'), findsOneWidget);
      expect(find.text('A little closer.'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      authBloc.close();
      chatBloc.close();
      await tester.pump();
    });
  });

  group('ImageAttachmentPreviewSheet Caption Styling Tests', () {
    testWidgets('caption input field has transparent fill and no border outline', (tester) async {
      const dummyPath = '/test_path/preview_image.jpg';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
          home: Scaffold(
            body: ImageAttachmentPreviewSheet(
              imagePath: dummyPath,
              onSend: (_) {},
            ),
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      final decoration = textField.decoration;
      expect(decoration, isNotNull);

      // Verify fill is explicitly disabled to avoid white rectangle
      expect(decoration!.filled, isFalse);
      expect(decoration.fillColor, Colors.transparent);

      // Verify borders are explicitly Border.none to avoid coral/accent focused box
      expect(decoration.border, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
