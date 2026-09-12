import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_bloc.dart';
import 'core/services/notification_service.dart';
import 'core/theme/relay_theme.dart';
import 'features/auth/relay_gate.dart';
import 'features/chats/chat_bloc.dart';
import 'features/chats/conversation_page.dart';
import 'features/chats/models/conversation.dart';
import 'features/chats/widgets/in_app_notification_banner.dart';

final GlobalKey<NavigatorState> relayNavigatorKey = GlobalKey<NavigatorState>();

class RelayApp extends StatelessWidget {
  const RelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    InAppNotificationBanner.navigatorKey = relayNavigatorKey;
    return BlocBuilder<AppBloc, AppState>(
      buildWhen: (previous, current) => previous.themeMode != current.themeMode,
      builder: (context, state) {
        return MaterialApp(
          navigatorKey: relayNavigatorKey,
          title: 'Relay',
          debugShowCheckedModeBanner: false,
          theme: RelayTheme.light,
          darkTheme: RelayTheme.dark,
          themeMode: state.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 240),
          themeAnimationCurve: Curves.easeOutCubic,
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final overlay =
                (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                    .copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      systemNavigationBarIconBrightness: dark
                          ? Brightness.light
                          : Brightness.dark,
                      systemNavigationBarDividerColor: Colors.transparent,
                      systemNavigationBarContrastEnforced: false,
                    );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: _InAppNotificationHost(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const RelayGate(),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const RelayGate(),
          ),
          onUnknownRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const RelayGate(),
          ),
        );
      },
    );
  }
}

class _InAppNotificationHost extends StatefulWidget {
  const _InAppNotificationHost({required this.child});
  final Widget child;

  @override
  State<_InAppNotificationHost> createState() => _InAppNotificationHostState();
}

class _InAppNotificationHostState extends State<_InAppNotificationHost> {
  StreamSubscription<NotificationPayload>? _systemNotificationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final notificationService = context.read<INotificationService?>();
        _systemNotificationSub =
            notificationService?.onNotificationOpened.listen((payload) {
          _navigateToChat(payload);
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _systemNotificationSub?.cancel();
    super.dispose();
  }

  void _navigateToChat(NotificationPayload notification) {
    final nav = relayNavigatorKey.currentState;
    if (nav == null) return;
    final chatBloc = context.read<ChatBloc>();
    final conversations = chatBloc.state.conversations;
    final match = conversations.where((c) => c.id == notification.chatId);

    final Conversation conversation = match.isNotEmpty
        ? match.first
        : Conversation(
            id: notification.chatId,
            name: notification.title.trim().isNotEmpty
                ? notification.title.trim()
                : 'Relay Contact',
            avatarAsset: notification.avatarUrl,
            lastMessage: notification.body,
            timeLabel: '',
            lastMessageAt: notification.timestamp,
            unread: 0,
            recipientId: notification.data['senderId']?.toString(),
          );

    ConversationPage.openWith(nav, chatBloc, conversation);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (prev, curr) =>
          curr.incomingNotification != null &&
          curr.incomingNotification != prev.incomingNotification,
      listener: (context, state) {
        // Clear the incoming notification state without showing any in-app banner
        context.read<ChatBloc>().add(const ChatIncomingNotificationCleared());
      },
      child: widget.child,
    );
  }
}
