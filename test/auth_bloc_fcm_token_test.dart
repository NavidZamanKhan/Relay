import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/services/notification_service.dart';
import 'package:relay/features/auth/auth_bloc.dart';
import 'package:relay/features/auth/models/user_profile.dart';

import 'auth_gate_session_test.dart';

void main() {
  group('AuthBloc FCM Token Lifecycle Tests', () {
    late MockAuthRepository authRepo;
    late MockUserRepository userRepo;
    late MockNotificationService notificationService;

    setUp(() {
      authRepo = MockAuthRepository();
      userRepo = MockUserRepository();
      notificationService = MockNotificationService();
    });

    tearDown(() {
      authRepo.dispose();
      notificationService.dispose();
    });

    test('syncs FCM token to user profile on authentication', () async {
      final authBloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        notificationService: notificationService,
        previewAuthenticated: false,
      );

      const profile = UserProfile(
        uid: 'user_fcm_sync',
        phoneNumber: '+15551234567',
        displayName: 'Tariq',
        about: 'Testing FCM',
        publicKey: 'pub_test_fcm_123',
      );
      userRepo.setProfile(profile);

      // Trigger user login
      authRepo.emitUser(FakeUser(uid: 'user_fcm_sync'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final updatedProfile = await userRepo.getUserProfile('user_fcm_sync');
      expect(updatedProfile?.fcmToken, 'mock_fcm_token_12345');

      await authBloc.close();
    });

    test('clears FCM token upon sign-out', () async {
      final authBloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        notificationService: notificationService,
        previewAuthenticated: false,
      );

      const profile = UserProfile(
        uid: 'user_signout',
        phoneNumber: '+15559876543',
        displayName: 'Farhana',
        about: 'Relay member',
        publicKey: 'pub_signout_key',
        fcmToken: 'existing_token_xyz',
      );
      userRepo.setProfile(profile);

      authRepo.emitUser(FakeUser(uid: 'user_signout'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Dispatch SignOut
      authBloc.add(const AuthSignOutRequested());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final updatedProfile = await userRepo.getUserProfile('user_signout');
      expect(updatedProfile?.fcmToken, isNull);

      await authBloc.close();
    });

    test('updates FCM token when token refreshes', () async {
      final authBloc = AuthBloc(
        authRepository: authRepo,
        userRepository: userRepo,
        notificationService: notificationService,
        previewAuthenticated: false,
      );

      const profile = UserProfile(
        uid: 'user_refresh',
        phoneNumber: '+15553334444',
        displayName: 'Kamal',
        about: 'Active',
        publicKey: 'pub_kamal',
      );
      userRepo.setProfile(profile);

      authRepo.emitUser(FakeUser(uid: 'user_refresh'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Simulate token rotation
      notificationService.simulateTokenRefresh('new_rotated_token_888');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final updatedProfile = await userRepo.getUserProfile('user_refresh');
      expect(updatedProfile?.fcmToken, 'new_rotated_token_888');

      await authBloc.close();
    });
  });
}
