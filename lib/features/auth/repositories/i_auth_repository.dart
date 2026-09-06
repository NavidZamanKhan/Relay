import 'package:firebase_auth/firebase_auth.dart';

/// Abstract contract for authentication data sources and lifecycle management.
abstract interface class IAuthRepository {
  /// Stream of user authentication state transitions.
  Stream<User?> get authStateChanges;

  /// The currently signed-in user, or null if unauthenticated.
  User? get currentUser;

  /// Dispatches phone number verification to Firebase.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException error) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? resendToken,
  });

  /// Submits the 6-digit OTP code against the verification ID.
  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String smsCode,
  });

  /// Signs in directly with a verified credential (e.g. Android auto-retrieval).
  Future<UserCredential> signInWithCredential(AuthCredential credential);

  /// Signs out the active user session.
  Future<void> signOut();
}
