import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/app_bloc.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/features/auth/auth_bloc.dart';
import 'package:relay/features/auth/repositories/i_user_repository.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/conversation_page.dart';
import 'package:relay/features/chats/demo_data.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

import 'app_settings_and_splash_gate_test.dart';
import 'auth_gate_session_test.dart';

void main() {
  group('Typing Indicator Size & Layout Tests', () {
    testWidgets('typing bubble renders with enlarged dimensions, padding, and 7.5px dots', (tester) async {
      final userRepo = MockUserRepository();
      final chatRepo = FakeChatRepository();
      final cryptoService = CryptoService(storage: FakeSecureStorage());

      // Seed chat bloc in demo mode with active typing status for 'aisha'
      final chatBloc = ChatBloc(
        chatRepository: chatRepo,
        demoMode: true,
      );

      // Trigger typing status in the active conversation
      chatBloc.emit(
        chatBloc.state.copyWith(
          activeId: 'aisha',
          typingIds: const {'aisha'},
          conversations: DemoData.inbox(),
        ),
      );

      expect(chatBloc.state.typing, isTrue);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<IUserRepository>.value(value: userRepo),
            RepositoryProvider<IChatRepository>.value(value: chatRepo),
            RepositoryProvider<CryptoService>.value(value: cryptoService),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ChatBloc>.value(value: chatBloc),
              BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
              BlocProvider<AppBloc>(create: (_) => AppBloc()),
            ],
            child: const MaterialApp(
              home: ConversationPage(),
            ),
          ),
        ),
      );

      // Verify the typing bubble container exists
      final typingBubbleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints != null &&
            widget.constraints!.minWidth >= 64 &&
            widget.constraints!.minHeight >= 38,
      );
      expect(typingBubbleFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(typingBubbleFinder);
      expect(containerWidget.padding, const EdgeInsets.symmetric(horizontal: 16, vertical: 12));

      // Verify border radius has 18px curves and 6px bottom left corner
      final decoration = containerWidget.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      final borderRadius = decoration!.borderRadius as BorderRadius?;
      expect(borderRadius, isNotNull);
      expect(borderRadius!.topLeft, const Radius.circular(18));
      expect(borderRadius.topRight, const Radius.circular(18));
      expect(borderRadius.bottomRight, const Radius.circular(18));
      expect(borderRadius.bottomLeft, const Radius.circular(6));

      // Verify exactly three dot containers exist with 7.5px dimensions
      final dotsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 7.5 &&
            widget.constraints?.maxHeight == 7.5,
      );
      expect(dotsFinder, findsNWidgets(3));

      // Verify ScaleTransition and FadeTransition wrap the dots
      expect(find.byType(ScaleTransition), findsAtLeastNWidgets(3));
      expect(find.byType(FadeTransition), findsAtLeastNWidgets(3));

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      chatBloc.close();
      await tester.pump();
    });
  });
}
