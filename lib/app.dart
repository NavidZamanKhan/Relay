import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_bloc.dart';
import 'core/motion/relay_motion.dart';
import 'core/theme/relay_theme.dart';
import 'features/auth/relay_gate.dart';
import 'features/chats/chat_bloc.dart';
import 'features/chats/conversation_page.dart';
import 'features/chats/widgets/in_app_notification_banner.dart';

final GlobalKey<NavigatorState> relayNavigatorKey = GlobalKey<NavigatorState>();

class RelayApp extends StatelessWidget {
  const RelayApp({super.key});

  @override
  Widget build(BuildContext context) {
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

class _InAppNotificationHost extends StatelessWidget {
  const _InAppNotificationHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (prev, curr) =>
          curr.incomingNotification != null &&
          curr.incomingNotification != prev.incomingNotification,
      listener: (context, state) {
        final notification = state.incomingNotification;
        if (notification == null) return;

        final appState = context.read<AppBloc>().state;
        final enabled = appState.preferences['Message notifications'] ?? true;
        final previews = appState.preferences['Message previews'] ?? true;

        if (enabled) {
          InAppNotificationBanner.show(
            context,
            payload: notification,
            showPreview: previews,
            onTap: () {
              context.read<ChatBloc>().add(ChatOpened(notification.chatId));
              relayNavigatorKey.currentState?.push(
                RelayMotion.route(const ConversationPage()),
              );
            },
          );
        }

        context.read<ChatBloc>().add(const ChatIncomingNotificationCleared());
      },
      child: child,
    );
  }
}
