import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/motion/relay_motion.dart';
import '../chats/chat_list_page.dart';
import 'auth_bloc.dart';
import 'otp_page.dart';
import 'phone_entry_page.dart';
import 'profile_setup_page.dart';

class RelayGate extends StatelessWidget {
  const RelayGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) => previous.step != current.step,
      builder: (context, state) {
        final page = switch (state.step) {
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
