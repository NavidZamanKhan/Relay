import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'app_bloc.dart';
import 'features/auth/auth_bloc.dart';
import 'features/chats/chat_bloc.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppBloc()),
        // The portfolio prototype opens at the most visually useful screen.
        // Set previewAuthenticated to false when testing the onboarding flow.
        BlocProvider(create: (_) => AuthBloc(previewAuthenticated: true)),
        BlocProvider(create: (_) => ChatBloc()),
      ],
      child: const RelayApp(),
    ),
  );
}
