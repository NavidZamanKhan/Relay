import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'desktop_auth_bridge.dart';
import 'i_auth_repository.dart';

/// Concrete implementation of [IAuthRepository] backed by Firebase Authentication.
class FirebaseAuthRepository implements IAuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    DesktopAuthBridge? desktopBridge,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _desktopBridge = desktopBridge ??
            DesktopAuthBridge(
              apiKey: (auth ?? FirebaseAuth.instance).app.options.apiKey,
              projectId: (auth ?? FirebaseAuth.instance).app.options.projectId,
            );

  final FirebaseAuth _auth;
  final DesktopAuthBridge _desktopBridge;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException error) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        final verificationId =
            await _desktopBridge.sendVerificationCode(phoneNumber);
        onCodeSent(verificationId, null);
      } on FirebaseAuthException catch (e) {
        onVerificationFailed(e);
      } catch (e) {
        onVerificationFailed(
          FirebaseAuthException(
            code: 'network-request-failed',
            message: 'Unable to send SMS code. Please check your network.',
          ),
        );
      }
      return;
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      forceResendingToken: resendToken,
    );
  }

  @override
  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      final verified = await _desktopBridge.verifySmsCode(
        sessionInfo: verificationId,
        smsCode: smsCode,
      );
      final customToken = _desktopBridge.mintCustomToken(
        uid: verified.uid,
        phoneNumber: verified.phoneNumber,
      );
      return _auth.signInWithCustomToken(customToken);
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

