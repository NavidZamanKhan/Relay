import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'app_bloc.dart';
import 'core/theme/relay_theme.dart';
import 'features/auth/relay_gate.dart';

class RelayApp extends StatelessWidget {
  const RelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      buildWhen: (previous, current) => previous.themeMode != current.themeMode,
      builder: (context, state) {
        return MaterialApp(
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
                    );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const RelayGate(),
        );
      },
    );
  }
}
