import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/widgets/relay_button.dart';
import 'auth_bloc.dart';
import 'auth_scaffold.dart';

class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key});
  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  final _controller = TextEditingController(text: '1712 345 678');
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    return AuthScaffold(
      eyebrow: 'Welcome to Relay',
      title: 'A little closer.',
      subtitle:
          'For the small updates, the long stories, and the people in between.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your phone number',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: () => _countries(context),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      CountryFlag(iso: state.countryIso),
                      const SizedBox(width: 8),
                      Text(
                        state.countryCode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Icon(CupertinoIcons.chevron_down, size: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                    LengthLimitingTextInputFormatter(18),
                  ],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(hintText: 'Phone number'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'We’ll send a 6-digit SMS code. Standard carrier rates may apply.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 28),
          RelayButton(
            label: 'Send verification code',
            icon: CupertinoIcons.arrow_right,
            onPressed: () {
              final digits = _controller.text.replaceAll(' ', '');
              if (digits.length < 7 || digits.length > 15) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Check your phone number and try again.'),
                  ),
                );
                return;
              }
              context.read<AuthBloc>().add(
                AuthPhoneSubmitted(
                  '${state.countryCode} ${_controller.text.trim()}',
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'By continuing, you agree to our Terms & Privacy.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  void _countries(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final countries =
            const [
                  ('BD', 'Bangladesh', '+880'),
                  ('IN', 'India', '+91'),
                  ('GB', 'United Kingdom', '+44'),
                  ('US', 'United States', '+1'),
                ]
                .where(
                  (c) => '${c.$2} ${c.$3}'.toLowerCase().contains(
                    state.countryQuery.toLowerCase(),
                  ),
                )
                .toList();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            0,
            22,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose country',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) =>
                    context.read<AuthBloc>().add(AuthCountrySearched(v)),
                decoration: const InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: Icon(CupertinoIcons.search, size: 19),
                ),
              ),
              const SizedBox(height: 12),
              for (final c in countries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CountryFlag(iso: c.$1),
                  title: Text(c.$2, style: const TextStyle(fontSize: 14)),
                  trailing: Text(c.$3),
                  onTap: () {
                    context.read<AuthBloc>().add(
                      AuthCountrySelected(c.$1, c.$3),
                    );
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Actual vector flag shapes keep country indicators consistent across devices.
/// No emoji fonts are used for interface icons or flags.
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.iso});
  final String iso;
  @override
  Widget build(BuildContext context) => Semantics(
    label: iso,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 26,
        height: 18,
        child: CustomPaint(painter: _FlagPainter(iso)),
      ),
    ),
  );
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter(this.iso);
  final String iso;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint();
    void rect(double y, double h, Color color) =>
        canvas.drawRect(Rect.fromLTWH(0, y, s.width, h), p..color = color);
    if (iso == 'BD') {
      rect(0, s.height, const Color(0xFF006A4E));
      canvas.drawCircle(
        Offset(s.width * .45, s.height * .5),
        s.height * .3,
        p..color = const Color(0xFFF42A41),
      );
    } else if (iso == 'IN') {
      rect(0, s.height / 3, const Color(0xFFFF9933));
      rect(s.height / 3, s.height / 3, Colors.white);
      rect(s.height * 2 / 3, s.height / 3, const Color(0xFF138808));
      canvas.drawCircle(
        Offset(s.width / 2, s.height / 2),
        2,
        p..color = const Color(0xFF000080),
      );
    } else if (iso == 'US') {
      rect(0, s.height, Colors.white);
      for (var i = 0; i < 13; i += 2) {
        rect(s.height * i / 13, s.height / 13, const Color(0xFFB22234));
      }
      canvas.drawRect(
        Rect.fromLTWH(0, 0, s.width * .44, s.height * .54),
        p..color = const Color(0xFF3C3B6E),
      );
      for (var x = 0; x < 4; x++) {
        for (var y = 0; y < 3; y++) {
          canvas.drawCircle(
            Offset(1.5 + x * 2.7, 1.5 + y * 2.7),
            .45,
            p..color = Colors.white,
          );
        }
      }
    } else {
      rect(0, s.height, const Color(0xFF012169));
      p
        ..color = Colors.white
        ..strokeWidth = 4;
      canvas.drawLine(Offset.zero, Offset(s.width, s.height), p);
      canvas.drawLine(Offset(s.width, 0), Offset(0, s.height), p);
      canvas.drawRect(
        Rect.fromLTWH(s.width * .38, 0, s.width * .24, s.height),
        p,
      );
      rect(s.height * .33, s.height * .34, Colors.white);
      p.color = const Color(0xFFC8102E);
      canvas.drawRect(
        Rect.fromLTWH(s.width * .43, 0, s.width * .14, s.height),
        p,
      );
      rect(s.height * .40, s.height * .20, p.color);
    }
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) =>
      oldDelegate.iso != iso;
}
