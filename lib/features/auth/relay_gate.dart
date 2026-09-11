import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/motion/relay_motion.dart';
import '../chats/chat_bloc.dart';
import '../chats/chat_list_page.dart';
import 'auth_bloc.dart';
import 'otp_page.dart';
import 'phone_entry_page.dart';
import 'profile_setup_page.dart';
import 'widgets/relay_splash_screen.dart';

import 'presence_observer.dart';
import 'repositories/i_user_repository.dart';

class RelayGate extends StatefulWidget {
  const RelayGate({super.key});

  @override
  State<RelayGate> createState() => _RelayGateState();
}

class _RelayGateState extends State<RelayGate> {
  PresenceObserver? _presenceObserver;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState.step == AuthStep.complete && authState.userId != null) {
      context.read<ChatBloc>().add(ChatStreamStarted(authState.userId!));
      _startPresence();
    }
  }

  void _startPresence() {
    _presenceObserver?.stop();
    _presenceObserver = PresenceObserver(
      userRepository: context.read<IUserRepository>(),
      getUserId: () => context.read<AuthBloc>().state.userId ?? '',
    )..start();
  }

  @override
  void dispose() {
    _presenceObserver?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.step != current.step || previous.userId != current.userId,
      listener: (context, state) {
        if (state.step == AuthStep.complete && state.userId != null) {
          context.read<ChatBloc>().add(ChatStreamStarted(state.userId!));
          _startPresence();
        } else {
          _presenceObserver?.stop();
        }
      },
      buildWhen: (previous, current) => previous.step != current.step,
      builder: (context, state) {
        final page = switch (state.step) {
          AuthStep.initial => const RelaySplashScreen(key: ValueKey('splash')),
          AuthStep.phone => const PhoneEntryPage(key: ValueKey('phone')),
          AuthStep.otp => const OtpPage(key: ValueKey('otp')),
          AuthStep.profile => const ProfileSetupPage(key: ValueKey('profile')),
          AuthStep.complete => const ChatListPage(key: ValueKey('chats')),
        };
        return AnimatedSwitcher(
          duration: RelayMotion.expressive,
          reverseDuration: RelayMotion.standard,
          switchInCurve: RelayMotion.enter,
          switchOutCurve: RelayMotion.exit,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(.06, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: page,
        );
      },
    );
  }
}
