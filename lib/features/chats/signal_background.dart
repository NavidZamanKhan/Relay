import 'package:flutter/material.dart';

/// A neutral canvas keeps long conversations readable in both themes.
class SignalBackground extends StatelessWidget {
  const SignalBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: child,
  );
}
