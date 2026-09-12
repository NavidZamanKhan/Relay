import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/app_bloc.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/features/auth/auth_bloc.dart';
import 'package:relay/features/auth/repositories/i_user_repository.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_list_page.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/conversation_page.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';
import 'package:relay/features/chats/views/desktop/relay_desktop_chat_list_pane.dart';
import 'package:relay/features/chats/views/desktop/relay_desktop_detail_pane.dart';
import 'package:relay/features/chats/views/desktop/relay_desktop_nav_rail.dart';
import 'package:relay/features/chats/views/desktop/relay_desktop_scaffold.dart';
import 'package:relay/features/settings/settings_page.dart';

import 'auth_gate_session_test.dart';

class _FakeDesktopChatRepository extends Fake implements IChatRepository {
  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) {
    return Stream.value([
      const Conversation(
        id: 'chat_alice',
        name: 'Alice Springs',
        avatarAsset: null,
        lastMessage: 'Let us meet on desktop',
        timeLabel: '14:30',
        unread: 2,
        pinned: true,
      ),
      const Conversation(
        id: 'group_team',
        name: 'Relay Core Team',
        avatarAsset: null,
        lastMessage: 'Mac layout is ready',
        timeLabel: '14:25',
        isGroup: true,
        unread: 0,
      ),
    ]);
  }

  @override
  Stream<List<RelayMessage>> watchMessages(
    String chatId,
    String currentUserId,
  ) {
    return Stream.value([
      RelayMessage(
        id: 'msg_1',
        text: 'Hello from mac',
        senderId: 'other_user',
        sentAt: DateTime(2026, 9, 12, 14, 30),
        kind: MessageKind.text,
        isMine: false,
      ),
    ]);
  }

  @override
  Future<void> markConversationRead({
    required String chatId,
    required String readerUserId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop Responsive Layout Tests', () {
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
        chatRepository: _FakeDesktopChatRepository(),
        demoMode: false,
      );
      chatBloc.add(const ChatStreamStarted('test_desktop_user'));

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
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CryptoService>.value(value: cryptoService),
            RepositoryProvider<IUserRepository>.value(value: userRepo),
          ],
          child: MaterialApp(
            home: child,
          ),
        ),
      );
    }

    testWidgets('Wide desktop screen renders 3-column layout and empty state', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const ChatListPage()));
      await tester.pumpAndSettle();

      expect(find.byType(RelayDesktopScaffold), findsOneWidget);
      expect(find.byType(RelayDesktopNavRail), findsOneWidget);
      expect(find.byType(RelayDesktopChatListPane), findsOneWidget);
      expect(find.byType(RelayDesktopDetailPane), findsOneWidget);

      expect(find.text('Relay Desktop'), findsOneWidget);
      expect(
        find.text('Your personal messages are end-to-end encrypted'),
        findsOneWidget,
      );

      expect(find.text('Chats'), findsWidgets);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);
    });

    testWidgets('Selecting a chat embeds ConversationPage in detail pane', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const ChatListPage()));
      await tester.runAsync(() async {
        if (chatBloc.state.conversations.isEmpty) {
          await chatBloc.stream.firstWhere((s) => s.conversations.isNotEmpty);
        }
      });
      await tester.pumpAndSettle();

      final firstTile = find.text('Alice Springs');
      expect(firstTile, findsOneWidget);

      await tester.tap(firstTile);
      await tester.runAsync(() async {
        await chatBloc.stream.firstWhere((s) => s.activeId == 'chat_alice');
      });
      await tester.pumpAndSettle();

      expect(find.byType(ConversationPage), findsOneWidget);
      expect(find.text('Relay Desktop'), findsNothing);

      expect(
        find.widgetWithIcon(IconButton, CupertinoIcons.chevron_left),
        findsNothing,
      );
    });

    testWidgets('Narrow screen (< 768px) falls back to mobile view', (tester) async {
      tester.view.physicalSize = const Size(420, 840);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const ChatListPage()));
      await tester.pumpAndSettle();

      expect(find.byType(RelayDesktopScaffold), findsNothing);
      expect(find.byType(RelayDesktopNavRail), findsNothing);
      expect(find.text('Relay'), findsOneWidget);
    });

    testWidgets('Desktop nav rail Settings button opens embedded settings', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const ChatListPage()));
      await tester.pumpAndSettle();

      final settingsButton = find.byTooltip('Settings');
      expect(settingsButton, findsOneWidget);

      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('YOUR RELAY'), findsOneWidget);
    });

    testWidgets('Desktop filter pills filter conversation list', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(const ChatListPage()));
      await tester.pumpAndSettle();

      final groupsChip = find.text('Groups');
      await tester.ensureVisible(groupsChip);
      await tester.tap(groupsChip);
      await tester.pumpAndSettle();

      expect(chatBloc.state.filter, InboxFilter.groups);

      final favoritesChip = find.text('Favorites');
      await tester.ensureVisible(favoritesChip);
      await tester.tap(favoritesChip);
      await tester.pumpAndSettle();

      expect(chatBloc.state.filter, InboxFilter.favorites);
    });
  });
}
