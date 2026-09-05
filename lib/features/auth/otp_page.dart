import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/motion/relay_motion.dart';
import '../../core/theme/relay_colors.dart';
import 'auth_bloc.dart';
import 'auth_scaffold.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.select((AuthBloc bloc) => bloc.state.phone);
    return AuthScaffold(
      eyebrow: 'One quick check',
      title: 'Pass the signal.',
      subtitle: 'We sent a private code to ${_mask(phone)}',
      leading: IconButton.filledTonal(
        onPressed: () =>
            context.read<AuthBloc>().add(const AuthPhoneEditRequested()),
        icon: const Icon(CupertinoIcons.chevron_left, size: 22),
      ),
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (a, b) =>
            a.otp != b.otp ||
            a.isVerifying != b.isVerifying ||
            a.resendSeconds != b.resendSeconds,
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Verification code',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  TextButton(
                    onPressed: () => context.read<AuthBloc>().add(
                      const AuthPhoneEditRequested(),
                    ),
                    child: const Text('Edit number'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _focusNode.requestFocus,
                child: Stack(
                  children: [
                    Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) =>
                            context.read<AuthBloc>().add(AuthOtpChanged(value)),
                      ),
                    ),
                    Row(
                      children: List.generate(6, (index) {
                        final filled = state.otp.length > index;
                        final active = state.otp.length == index;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: RelayMotion.quick,
                            curve: RelayMotion.spring,
                            height: 62,
                            margin: EdgeInsets.only(right: index == 5 ? 0 : 7),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: active
                                    ? RelayColors.coral
                                    : Theme.of(context).dividerColor,
                                width: active ? 1.6 : 1,
                              ),
                            ),
                            child: Center(
                              child: AnimatedScale(
                                duration: RelayMotion.quick,
                                scale: filled ? 1 : .7,
                                curve: RelayMotion.spring,
                                child: Text(
                                  filled ? state.otp[index] : '•',
                                  style: TextStyle(
                                    fontSize: filled ? 22 : 14,
                                    fontWeight: FontWeight.w700,
                                    color: filled
                                        ? null
                                        : Theme.of(context).dividerColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: RelayMotion.quick,
                child: state.isVerifying
                    ? const Row(
                        key: ValueKey('verifying'),
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Verifying securely…',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('resend'),
                        children: [
                          const Text('Didn’t receive it? '),
                          TextButton(
                            onPressed: state.resendSeconds == 0
                                ? () => context.read<AuthBloc>().add(
                                    const AuthResendRequested(),
                                  )
                                : null,
                            child: Text(
                              state.resendSeconds == 0
                                  ? 'Resend now'
                                  : 'Resend in 00:${state.resendSeconds.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                'Prototype tip: enter any six digits.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: RelayColors.coralDeep),
              ),
            ],
          );
        },
      ),
    );
  }

  String _mask(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 7)} ••• •${phone.substring(phone.length - 2)}';
  }
}
