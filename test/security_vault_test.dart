import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/app_bloc.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/features/auth/auth_bloc.dart';
import 'package:relay/features/auth/models/user_profile.dart';
import 'package:relay/features/auth/repositories/i_auth_repository.dart';
import 'package:relay/features/auth/repositories/i_user_repository.dart';
import 'package:relay/features/chats/widgets/safety_number_sheet.dart';
import 'package:relay/features/settings/views/security_settings_page.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

class FakeFirebaseUser extends Fake implements User {
  FakeFirebaseUser({required this.uid});
  @override
  final String uid;
}

class FakeAuthRepo extends Fake implements IAuthRepository {
  FakeAuthRepo({required this.user});
  final User user;

  @override
  User? get currentUser => user;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class MockUserRepository implements IUserRepository {
  final Map<String, UserProfile> profiles = {};

  @override
  Future<UserProfile?> getUserProfile(String uid) async => profiles[uid];

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    profiles[profile.uid] = profile;
  }

  @override
  Stream<UserProfile?> watchUserProfile(String uid) =>
      Stream.value(profiles[uid]);

  @override
  Future<void> updatePresence({
    required String uid,
    required bool isOnline,
  }) async {}
}

void main() {
  group('E2EE Safety Number and Vault Security Tests', () {
    test('computeSafetyNumber is symmetric between peer keys', () async {
      final storageAlice = FakeSecureStorage();
      final cryptoAlice = CryptoService(storage: storageAlice);
      final alicePub = await cryptoAlice.getOrCreatePublicKey();

      final storageBob = FakeSecureStorage();
      final cryptoBob = CryptoService(storage: storageBob);
      final bobPub = await cryptoBob.getOrCreatePublicKey();

      final codeA = await CryptoService.computeSafetyNumber(alicePub, bobPub);
      final codeB = await CryptoService.computeSafetyNumber(bobPub, alicePub);

      expect(codeA, equals(codeB));
      expect(codeA.split(' ').length, 6);
      for (final block in codeA.split(' ')) {
        expect(block.length, 5);
        expect(int.tryParse(block), isNotNull);
      }
    });

    test('different peer keys yield distinct safety numbers', () async {
      final storage1 = FakeSecureStorage();
      final storage2 = FakeSecureStorage();
      final storage3 = FakeSecureStorage();

      final key1 = await CryptoService(storage: storage1).getOrCreatePublicKey();
      final key2 = await CryptoService(storage: storage2).getOrCreatePublicKey();
      final key3 = await CryptoService(storage: storage3).getOrCreatePublicKey();

      final code12 = await CryptoService.computeSafetyNumber(key1, key2);
      final code13 = await CryptoService.computeSafetyNumber(key1, key3);

      expect(code12, isNot(equals(code13)));
    });

    test('formatKeyFingerprint generates grouped 16-character hex string', () async {
      final storage = FakeSecureStorage();
      final crypto = CryptoService(storage: storage);
      final pubKey = await crypto.getOrCreatePublicKey();

      final fingerprint = CryptoService.formatKeyFingerprint(pubKey);
      expect(fingerprint, isNotEmpty);
      expect(fingerprint.split(' ').length, 4);
      for (final block in fingerprint.split(' ')) {
        expect(block.length, 4);
      }
      expect(CryptoService.formatKeyFingerprint(''), equals('None'));
    });

    test('CryptoService regenerateKeypair creates fresh keys and overwrites storage', () async {
      final storage = FakeSecureStorage();
      final crypto = CryptoService(storage: storage);

      final initialPub = await crypto.getOrCreatePublicKey();
      final regeneratedPub = await crypto.regenerateKeypair();

      expect(regeneratedPub, isNot(equals(initialPub)));
      expect(await storage.read(key: 'relay_x25519_public_key'), equals(regeneratedPub));
      expect(base64Decode(regeneratedPub).length, 32);
    });

    test('AuthBloc handles AuthKeyRegenerated and AuthKeyVaultRestored events', () async {
      final storage = FakeSecureStorage();
      final crypto = CryptoService(storage: storage);
      final initialPub = await crypto.getOrCreatePublicKey();
      final userRepo = MockUserRepository();
      const uid = 'user_vault_test';

      final authBloc = AuthBloc(
        authRepository: FakeAuthRepo(user: FakeFirebaseUser(uid: uid)),
        userRepository: userRepo,
        cryptoService: crypto,
        previewAuthenticated: true,
      );

      // Export vault from original key
      final vault = await crypto.exportEncryptedKeyVault(uid);

      // Regenerate keys
      authBloc.add(const AuthKeyRegenerated());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state.publicKey, isNotNull);
      expect(authBloc.state.publicKey, isNot(equals(initialPub)));

      // Restore keys from vault
      authBloc.add(AuthKeyVaultRestored(vault));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state.publicKey, equals(initialPub));

      await authBloc.close();
    });
  });

  group('SafetyNumberSheet Widget Verification Tests', () {
    testWidgets('renders safety number sheet and copies code', (tester) async {
      const keyA = 'mc911i40Bf/uM9U4iS7f3E6hA1v5C4v9e7r1s0t4u8w=';
      const keyB = 'k8122j51Cg/vN0V5jT8g4F7iB2w6D5w0f8s2t1u5v9x=';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafetyNumberSheet(
              peerName: 'Elena Rostova',
              myPublicKey: keyA,
              peerPublicKey: keyB,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Verify Security Code'), findsOneWidget);
      expect(find.textContaining('Elena Rostova'), findsOneWidget);
      expect(find.text('Copy Code'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Tap Copy Code button
      await tester.tap(find.text('Copy Code'));
      await tester.pumpAndSettle();
    });
  });

  group('SecuritySettingsPage Widget Verification Tests', () {
    testWidgets('renders E2EE status, fingerprint, vault controls, and preferences', (tester) async {
      final storage = FakeSecureStorage();
      final crypto = CryptoService(storage: storage);
      await crypto.getOrCreatePublicKey();

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CryptoService>.value(value: crypto),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => AuthBloc(
                  cryptoService: crypto,
                  previewAuthenticated: true,
                ),
              ),
              BlocProvider(create: (_) => AppBloc()),
            ],
            child: const MaterialApp(
              home: SecuritySettingsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Privacy & security'), findsOneWidget);
      expect(find.text('End-to-End Encrypted'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('CRYPTOGRAPHIC IDENTITY'), findsOneWidget);
      expect(find.text('Public Key Fingerprint'), findsOneWidget);
      expect(find.text('Export Encrypted Vault'), findsOneWidget);
      expect(find.text('Restore Key Vault'), findsOneWidget);
      expect(find.text('Regenerate Encryption Keys'), findsOneWidget);
      expect(find.text('Last seen'), findsOneWidget);
      expect(find.text('Read receipts'), findsOneWidget);
      expect(find.text('App lock'), findsOneWidget);

      // Tap Restore Key Vault opens dialog
      await tester.tap(find.text('Restore Key Vault'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Restore Key Vault'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Regenerate Encryption Keys opens warning dialog
      await tester.tap(find.text('Regenerate Encryption Keys'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Regenerate Keys?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
