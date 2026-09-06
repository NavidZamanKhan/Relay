import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/crypto/crypto_service.dart';
import 'package:relay/features/auth/auth_bloc.dart';
import 'package:relay/features/auth/models/user_profile.dart';
import 'package:relay/features/auth/repositories/i_auth_repository.dart';
import 'package:relay/features/auth/repositories/i_user_repository.dart';

class FakeUser extends Fake implements User {
  FakeUser({required this.uid, this.phoneNumber = '+16505551234'});
  @override
  final String uid;
  @override
  final String? phoneNumber;
}

class FakeUserCredential extends Fake implements UserCredential {
  FakeUserCredential({required this.user});
  @override
  final User? user;
}

class MockAuthRepository implements IAuthRepository {
  MockAuthRepository({User? initialUser}) : _currentUser = initialUser {
    _controller = StreamController<User?>.broadcast();
  }

  User? _currentUser;
  late final StreamController<User?> _controller;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => _currentUser;

  void emitUser(User? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException error) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    onCodeSent('mock_verification_id', 12345);
  }

  @override
  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = FakeUser(uid: 'user_otp_success');
    _currentUser = user;
    return FakeUserCredential(user: user);
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    final user = FakeUser(uid: 'user_credential_success');
    _currentUser = user;
    return FakeUserCredential(user: user);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

class MockUserRepository implements IUserRepository {
  final Map<String, UserProfile> _profiles = {};

  void setProfile(UserProfile profile) {
    _profiles[profile.uid] = profile;
  }

  @override
  Future<UserProfile?> getUserProfile(String uid) async => _profiles[uid];

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _profiles[profile.uid] = profile;
  }

  @override
  Stream<UserProfile?> watchUserProfile(String uid) {
    return Stream.value(_profiles[uid]);
  }
}

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
    if (value != null) _data[key] = value;
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

void main() {
  group('Auth Gate & Session Lifecycle Tests', () {
    late MockAuthRepository authRepo;
    late MockUserRepository userRepo;
    late CryptoService cryptoService;

    setUp(() {
      authRepo = MockAuthRepository();
      userRepo = MockUserRepository();
      cryptoService = CryptoService(storage: FakeSecureStorage());
    });

    tearDown(() {
      authRepo.dispose();
    });

    test('initializes at phone step when unauthenticated', () {
      final bloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        cryptoService: cryptoService,
        previewAuthenticated: false,
      );

      expect(bloc.state.step, AuthStep.phone);
      bloc.close();
    });

    test('transitions to complete when authenticated session has existing profile', () async {
      userRepo.setProfile(
        const UserProfile(
          uid: 'existing_user',
          phoneNumber: '+16505551234',
          displayName: 'Returning User',
          about: 'Hello world',
          publicKey: 'mock_pub_key',
        ),
      );

      final bloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        cryptoService: cryptoService,
        previewAuthenticated: false,
      );

      authRepo.emitUser(FakeUser(uid: 'existing_user'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AuthState>(
            (state) =>
                state.step == AuthStep.complete &&
                state.displayName == 'Returning User' &&
                state.userId == 'existing_user',
          ),
        ),
      );

      await bloc.close();
    });

    test('transitions to profile setup when authenticated user has no stored profile', () async {
      final bloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        cryptoService: cryptoService,
        previewAuthenticated: false,
      );

      authRepo.emitUser(FakeUser(uid: 'new_user_without_profile'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AuthState>(
            (state) =>
                state.step == AuthStep.profile &&
                state.userId == 'new_user_without_profile',
          ),
        ),
      );

      await bloc.close();
    });

    test('signing in with OTP skips profile setup if profile already exists', () async {
      userRepo.setProfile(
        const UserProfile(
          uid: 'user_otp_success',
          phoneNumber: '+16505551234',
          displayName: 'Preexisting Profile',
          about: 'Ready to chat',
          publicKey: 'mock_pub_key',
        ),
      );

      final bloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        cryptoService: cryptoService,
        previewAuthenticated: false,
      );

      // Submit phone to move to OTP
      bloc.add(const AuthPhoneSubmitted('+16505551234'));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<AuthState>((s) => s.step == AuthStep.otp)),
      );

      // Verify OTP
      bloc.add(const AuthOtpChanged('123456'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AuthState>(
            (s) =>
                s.step == AuthStep.complete &&
                s.displayName == 'Preexisting Profile',
          ),
        ),
      );

      await bloc.close();
    });

    test('sign out resets state to phone step and wipes cryptographic keys', () async {
      final bloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        cryptoService: cryptoService,
        previewAuthenticated: true,
      );

      expect(bloc.state.step, AuthStep.complete);

      bloc.add(const AuthSignOutRequested());

      await expectLater(
        bloc.stream,
        emitsThrough(predicate<AuthState>((s) => s.step == AuthStep.phone)),
      );

      expect(await cryptoService.getPublicKey(), isNull);
      await bloc.close();
    });
  });
}
