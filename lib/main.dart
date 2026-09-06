import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'app_bloc.dart';
import 'features/auth/auth_bloc.dart';
import 'features/auth/repositories/firebase_auth_repository.dart';
import 'features/chats/chat_bloc.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final authRepository = FirebaseAuthRepository();
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppBloc()),
        BlocProvider(
          create: (_) => AuthBloc(
            authRepository: authRepository,
            previewAuthenticated: false,
          ),
        ),
        BlocProvider(create: (_) => ChatBloc()),
      ],
      child: const RelayApp(),
    ),
  );
}
