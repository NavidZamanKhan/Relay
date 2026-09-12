import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/app_bloc.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/core/services/backup_service.dart';
import 'package:relay/core/services/cache_service.dart';
import 'package:relay/core/widgets/relay_button.dart';
import 'package:relay/features/auth/auth_bloc.dart';

import 'package:relay/features/auth/models/user_profile.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/models/conversation.dart';
import 'package:relay/features/chats/models/relay_message.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';
import 'package:relay/features/settings/settings_page.dart';
import 'package:relay/features/settings/views/backup_settings_page.dart';
import 'package:relay/features/settings/views/chat_settings_page.dart';
import 'package:relay/features/settings/views/notification_settings_page.dart';
import 'package:relay/features/settings/views/security_settings_page.dart';

import 'auth_gate_session_test.dart';

class DummyChatRepository extends Fake implements IChatRepository {
  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      Stream.value([
        const Conversation(
          id: 'test_chat_1',
          name: 'Aisha Chowdhury',
          avatarAsset: null,
          lastMessage: 'Hello there!',
          timeLabel: '12:00',
        ),
      ]);

  @override
  Stream<List<RelayMessage>> watchMessages(
    String chatId,
    String currentUserId,
  ) =>
      Stream.value([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cache_service_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('CacheUsage formats bytes accurately', () {
      expect(CacheUsage.formatBytes(0), '0 B');
      expect(CacheUsage.formatBytes(512), '512 B');
      expect(CacheUsage.formatBytes(1536), '1.5 KB');
      expect(CacheUsage.formatBytes(5 * 1024 * 1024), '5.0 MB');
    });

    test('calculateCacheUsage returns non-negative values', () async {
      final service = CacheService(
        customDocsDir: tempDir,
        customTempDir: tempDir,
      );
      final usage = await service.calculateCacheUsage();
      expect(usage.photosBytes, greaterThanOrEqualTo(0));
      expect(usage.voiceBytes, greaterThanOrEqualTo(0));
      expect(usage.fileBytes, greaterThanOrEqualTo(0));
      expect(usage.totalBytes, greaterThanOrEqualTo(0));
    });

    test('purgeLocalCache returns zeroed usage', () async {
      final service = CacheService(
        customDocsDir: tempDir,
        customTempDir: tempDir,
      );
      final purged = await service.purgeLocalCache();
      expect(purged.totalBytes, 0);
    });
  });

  group('BackupService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_service_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('createEncryptedBackup creates valid encrypted backup file', () async {
      final storage = FakeSecureStorage();
      final crypto = CryptoService(storage: storage);
      final service = BackupService(
        cryptoService: crypto,
        customDir: tempDir,
      );

      final metadata = await service.createEncryptedBackup(
        userId: 'test_user_alice',
        conversationsData: [
          {'id': 'c1', 'name': 'Bob', 'lastMessage': 'Hi'},
        ],
        totalMessages: 5,
      );

      expect(metadata.conversationCount, 1);
      expect(metadata.messageCount, 5);
      expect(metadata.byteSize, greaterThan(0));
      expect(File(metadata.filePath).existsSync(), isTrue);

      final content = await File(metadata.filePath).readAsString();
      final decrypted =
          await service.decryptBackupBundle(content, 'test_user_alice');
      expect(decrypted, isNotNull);
      expect(decrypted!['userId'], 'test_user_alice');
      expect(decrypted['totalConversations'], 1);
    });

    test('AuthAccountDeleted event transitions step to phone', () async {
      final storage = FakeSecureStorage();
      final crypto = CryptoService(storage: storage);
      final uRepo = MockUserRepository();
      final aRepo = MockAuthRepository();
      final bloc = AuthBloc(
        authRepository: aRepo,
        userRepository: uRepo,
        cryptoService: crypto,
        previewAuthenticated: true,
      );

      bloc.add(const AuthAccountDeleted());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.isVerifying == true),
          predicate<AuthState>((s) => s.step == AuthStep.phone),
        ]),
      );
      await bloc.close();
    });
  });

  group('Settings UI Navigation and Feature Tests', () {
    late AppBloc appBloc;
    late AuthBloc authBloc;
    late ChatBloc chatBloc;
    late MockUserRepository userRepo;
    late MockAuthRepository authRepo;
    late CryptoService cryptoService;

    setUp(() {
      final storage = FakeSecureStorage();
      cryptoService = CryptoService(storage: storage);
      userRepo = MockUserRepository();
      authRepo = MockAuthRepository();

      authBloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        cryptoService: cryptoService,
        previewAuthenticated: true,
      );

      chatBloc = ChatBloc(
        chatRepository: DummyChatRepository(),
        demoMode: true,
      );

      appBloc = AppBloc();
    });

    tearDown(() {
      appBloc.close();
      authBloc.close();
      chatBloc.close();
    });

    Widget createTestApp(Widget child) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<AppBloc>.value(value: appBloc),
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<ChatBloc>.value(value: chatBloc),
        ],
        child: RepositoryProvider<CryptoService>.value(
          value: cryptoService,
          child: MaterialApp(
            home: child,
          ),
        ),
      );
    }

    testWidgets('SettingsPage renders all core section tiles', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const SettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('YOUR RELAY'), findsOneWidget);
      expect(find.text('STORAGE'), findsOneWidget);
      expect(find.text('PROTOTYPE'), findsOneWidget);

      expect(find.text('Privacy & security'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Chat backup'), findsOneWidget);
      expect(find.text('Manage local cache'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('Tapping Chats opens ChatSettingsPage', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const SettingsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatSettingsPage), findsOneWidget);
      expect(find.text('MEDIA AUTO-DOWNLOAD'), findsOneWidget);
      expect(find.text('Save to Photos'), findsOneWidget);
      expect(find.text('Enter is send'), findsOneWidget);
      expect(find.text('Font size'), findsOneWidget);
      expect(find.text('Clear all messages'), findsOneWidget);
      expect(find.text('Delete all chats'), findsOneWidget);
    });

    testWidgets('Tapping Chat backup opens BackupSettingsPage', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const SettingsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chat backup'));
      await tester.pumpAndSettle();

      expect(find.byType(BackupSettingsPage), findsOneWidget);
      expect(find.text('Encrypted Chat Backup'), findsOneWidget);
      expect(find.text('Back Up Now'), findsOneWidget);
      expect(find.text('Export Backup Location'), findsOneWidget);
      expect(find.text('Restore from Backup'), findsOneWidget);
      expect(find.text('Automatic backups'), findsOneWidget);
    });

    testWidgets('Tapping Manage local cache opens bottom sheet with dynamic bar', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const SettingsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage local cache'));
      await tester.pumpAndSettle();

      expect(find.text('Local cache'), findsOneWidget);
      expect(find.byType(RelayButton), findsOneWidget);
    });

    testWidgets('Delete account confirmation dispatches AuthAccountDeleted', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      userRepo.setProfile(
        const UserProfile(
          uid: 'active_user',
          phoneNumber: '+15550001111',
          displayName: 'Test User',
          about: 'About me',
          publicKey: 'key',
        ),
      );

      await tester.pumpWidget(createTestApp(const SettingsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your Relay?'), findsOneWidget);
      expect(find.text('Delete permanently'), findsOneWidget);
      await tester.tap(find.text('Delete permanently'));
      await tester.runAsync(() async {
        await authBloc.stream.firstWhere((s) => s.step == AuthStep.phone);
      });
      await tester.pumpAndSettle();

      expect(authBloc.state.step, AuthStep.phone);
    });

    testWidgets('NotificationSettingsPage renders quiet hours schedule', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      appBloc.add(const AppPreferenceChanged('Quiet hours', true));
      await tester.pumpWidget(createTestApp(const NotificationSettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Quiet hours window'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
    });

    testWidgets('SecuritySettingsPage renders descriptive subtitles for privacy', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const SecuritySettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Last seen'), findsOneWidget);
      expect(
        find.text('Share when you were last active with conversation contacts'),
        findsOneWidget,
      );
      expect(find.text('Read receipts'), findsOneWidget);
      expect(find.text('App lock'), findsOneWidget);
    });
  });
}
