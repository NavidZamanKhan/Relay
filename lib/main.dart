import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'app_bloc.dart';
import 'core/crypto/crypto_service.dart';
import 'core/services/app_settings_storage.dart';
import 'core/services/notification_service.dart';
import 'features/auth/auth_bloc.dart';
import 'features/auth/repositories/firebase_auth_repository.dart';
import 'features/auth/repositories/firestore_user_repository.dart';
import 'features/auth/repositories/i_user_repository.dart';
import 'features/chats/chat_bloc.dart';
import 'features/chats/repositories/firestore_chat_repository.dart';
import 'features/chats/repositories/i_chat_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const settingsStorage = AppSettingsStorage();
  final savedAppState = await settingsStorage.loadSettings();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final authRepository = FirebaseAuthRepository();
  final userRepository = FirestoreUserRepository();
  final cryptoService = CryptoService();
  final chatRepository = FirestoreChatRepository(cryptoService: cryptoService);
  final notificationService = RelayNotificationService();
  await notificationService.initialize();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IChatRepository>.value(value: chatRepository),
        RepositoryProvider<IUserRepository>.value(value: userRepository),
        RepositoryProvider<CryptoService>.value(value: cryptoService),
        RepositoryProvider<INotificationService>.value(value: notificationService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AppBloc(
              initialState: savedAppState,
              storage: settingsStorage,
            ),
          ),
          BlocProvider(
            create: (_) => AuthBloc(
              authRepository: authRepository,
              userRepository: userRepository,
              cryptoService: cryptoService,
              notificationService: notificationService,
              previewAuthenticated: false,
            ),
          ),
          BlocProvider(
            create: (_) => ChatBloc(
              chatRepository: chatRepository,
              notificationService: notificationService,
              demoMode: false,
            ),
          ),
        ],
        child: const RelayApp(),
      ),
    ),
  );
}
