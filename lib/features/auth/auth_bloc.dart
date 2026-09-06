import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/crypto/crypto_service.dart';
import 'models/user_profile.dart';
import 'repositories/i_auth_repository.dart';
import 'repositories/i_user_repository.dart';

// --- Auth Events ---

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthCountrySelected extends AuthEvent {
  const AuthCountrySelected(this.iso, this.code);
  final String iso;
  final String code;

  @override
  List<Object?> get props => [iso, code];
}

final class AuthCountrySearched extends AuthEvent {
  const AuthCountrySearched(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

final class AuthPhoneSubmitted extends AuthEvent {
  const AuthPhoneSubmitted(this.phone);
  final String phone;

  @override
  List<Object?> get props => [phone];
}

final class AuthOtpChanged extends AuthEvent {
  const AuthOtpChanged(this.code);
  final String code;

  @override
  List<Object?> get props => [code];
}

final class AuthOtpVerified extends AuthEvent {
  const AuthOtpVerified();
}

final class AuthPhoneEditRequested extends AuthEvent {
  const AuthPhoneEditRequested();
}

final class AuthResendRequested extends AuthEvent {
  const AuthResendRequested();
}

final class AuthResendTicked extends AuthEvent {
  const AuthResendTicked();
}

final class AuthProfileUpdated extends AuthEvent {
  const AuthProfileUpdated({required this.name, required this.about});
  final String name;
  final String about;

  @override
  List<Object?> get props => [name, about];
}

final class AuthRestarted extends AuthEvent {
  const AuthRestarted();
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

final class AuthErrorDismissed extends AuthEvent {
  const AuthErrorDismissed();
}

// Internal package events for Firebase callbacks
final class _AuthCodeSent extends AuthEvent {
  const _AuthCodeSent(this.verificationId, this.resendToken);
  final String verificationId;
  final int? resendToken;

  @override
  List<Object?> get props => [verificationId, resendToken];
}

final class _AuthVerificationFailed extends AuthEvent {
  const _AuthVerificationFailed(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

final class _AuthAutoVerified extends AuthEvent {
  const _AuthAutoVerified(this.credential);
  final PhoneAuthCredential credential;

  @override
  List<Object?> get props => [credential];
}

final class _AuthTimeout extends AuthEvent {
  const _AuthTimeout(this.verificationId);
  final String verificationId;

  @override
  List<Object?> get props => [verificationId];
}

final class _AuthUserChanged extends AuthEvent {
  const _AuthUserChanged(this.user);
  final User? user;

  @override
  List<Object?> get props => [user?.uid];
}

// --- Auth State ---

enum AuthStep { phone, otp, profile, complete }

final class AuthState extends Equatable {
  const AuthState({
    required this.step,
    this.phone = '+880 1712 345 678',
    this.otp = '',
    this.isVerifying = false,
    this.resendSeconds = 30,
    this.displayName = 'Navid',
    this.about = 'Building things worth keeping open.',
    this.countryIso = 'BD',
    this.countryCode = '+880',
    this.countryQuery = '',
    this.verificationId,
    this.resendToken,
    this.errorMessage,
    this.userId,
    this.publicKey,
  });

  final AuthStep step;
  final String phone;
  final String otp;
  final bool isVerifying;
  final int resendSeconds;
  final String displayName;
  final String about;
  final String countryIso;
  final String countryCode;
  final String countryQuery;
  final String? verificationId;
  final int? resendToken;
  final String? errorMessage;
  final String? userId;
  final String? publicKey;

  AuthState copyWith({
    AuthStep? step,
    String? phone,
    String? otp,
    bool? isVerifying,
    int? resendSeconds,
    String? displayName,
    String? about,
    String? countryIso,
    String? countryCode,
    String? countryQuery,
    String? verificationId,
    int? resendToken,
    String? errorMessage,
    bool clearError = false,
    String? userId,
    String? publicKey,
  }) {
    return AuthState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      otp: otp ?? this.otp,
      isVerifying: isVerifying ?? this.isVerifying,
      resendSeconds: resendSeconds ?? this.resendSeconds,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      countryIso: countryIso ?? this.countryIso,
      countryCode: countryCode ?? this.countryCode,
      countryQuery: countryQuery ?? this.countryQuery,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userId: userId ?? this.userId,
      publicKey: publicKey ?? this.publicKey,
    );
  }

  @override
  List<Object?> get props => [
        step,
        phone,
        otp,
        isVerifying,
        resendSeconds,
        displayName,
        about,
        countryIso,
        countryCode,
        countryQuery,
        verificationId,
        resendToken,
        errorMessage,
        userId,
        publicKey,
      ];
}

// --- Auth BLoC ---

final class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    IAuthRepository? authRepository,
    IUserRepository? userRepository,
    CryptoService? cryptoService,
    bool previewAuthenticated = true,
  })  : _authRepository = authRepository,
        _userRepository = userRepository,
        _cryptoService = cryptoService,
        super(
          AuthState(
            step: previewAuthenticated ? AuthStep.complete : AuthStep.phone,
          ),
        ) {
    on<AuthCountrySelected>(_onCountrySelected);
    on<AuthCountrySearched>(_onCountrySearched);
    on<AuthPhoneSubmitted>(_onPhoneSubmitted);
    on<_AuthCodeSent>(_onCodeSent);
    on<_AuthVerificationFailed>(_onVerificationFailed);
    on<_AuthAutoVerified>(_onAutoVerified);
    on<_AuthTimeout>(_onTimeout);
    on<AuthOtpChanged>(_onOtpChanged);
    on<AuthOtpVerified>(_onOtpVerified);
    on<AuthPhoneEditRequested>(_onPhoneEditRequested);
    on<AuthResendRequested>(_onResendRequested);
    on<AuthResendTicked>(_onResendTicked);
    on<AuthProfileUpdated>(_onProfileUpdated);
    on<AuthRestarted>(_onRestarted);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthErrorDismissed>(_onErrorDismissed);
    on<_AuthUserChanged>(_onUserChanged);

    if (_authRepository != null && !previewAuthenticated) {
      _authStateSubscription = _authRepository.authStateChanges.listen((user) {
        add(_AuthUserChanged(user));
      });
    }
  }

  final IAuthRepository? _authRepository;
  final IUserRepository? _userRepository;
  final CryptoService? _cryptoService;
  StreamSubscription<User?>? _authStateSubscription;
  Timer? _resendTimer;
  int _verificationEpoch = 0;

  void _onCountrySelected(AuthCountrySelected event, Emitter<AuthState> emit) {
    emit(
      state.copyWith(
        countryIso: event.iso,
        countryCode: event.code,
        countryQuery: '',
      ),
    );
  }

  void _onCountrySearched(AuthCountrySearched event, Emitter<AuthState> emit) {
    emit(state.copyWith(countryQuery: event.query));
  }

  Future<void> _onPhoneSubmitted(
    AuthPhoneSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final cleanedNumber = event.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    emit(
      state.copyWith(
        phone: event.phone,
        isVerifying: true,
        clearError: true,
      ),
    );

    if (_authRepository == null) {
      // Mock / preview mode fallback for tests
      emit(
        state.copyWith(
          step: AuthStep.otp,
          isVerifying: false,
          otp: '',
          resendSeconds: 30,
        ),
      );
      _startResendTimer();
      return;
    }

    try {
      await _authRepository.verifyPhoneNumber(
        phoneNumber: cleanedNumber,
        resendToken: state.resendToken,
        onCodeSent: (verificationId, resendToken) {
          add(_AuthCodeSent(verificationId, resendToken));
        },
        onVerificationFailed: (error) {
          add(_AuthVerificationFailed(error.message ?? 'Phone verification failed.'));
        },
        onVerificationCompleted: (credential) {
          add(_AuthAutoVerified(credential));
        },
        onCodeAutoRetrievalTimeout: (verificationId) {
          add(_AuthTimeout(verificationId));
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          isVerifying: false,
          errorMessage: 'Unable to send SMS code. Please check your network.',
        ),
      );
    }
  }

  void _onCodeSent(_AuthCodeSent event, Emitter<AuthState> emit) {
    emit(
      state.copyWith(
        step: AuthStep.otp,
        isVerifying: false,
        verificationId: event.verificationId,
        resendToken: event.resendToken,
        resendSeconds: 30,
        otp: '',
        clearError: true,
      ),
    );
    _startResendTimer();
  }

  void _onVerificationFailed(_AuthVerificationFailed event, Emitter<AuthState> emit) {
    emit(
      state.copyWith(
        isVerifying: false,
        errorMessage: event.message,
      ),
    );
  }

  Future<void> _onAutoVerified(
    _AuthAutoVerified event,
    Emitter<AuthState> emit,
  ) async {
    _resendTimer?.cancel();
    if (_authRepository != null) {
      try {
        final credential =
            await _authRepository.signInWithCredential(event.credential);
        final uid = credential.user?.uid;
        if (uid != null && _userRepository != null) {
          UserProfile? existingProfile;
          try {
            existingProfile = await _userRepository.getUserProfile(uid);
          } catch (_) {
            // Safe fallback for fresh users
          }
          if (existingProfile != null && existingProfile.displayName.isNotEmpty) {
            emit(
              state.copyWith(
                step: AuthStep.complete,
                displayName: existingProfile.displayName,
                about: existingProfile.about,
                phone: existingProfile.phoneNumber.isNotEmpty
                    ? existingProfile.phoneNumber
                    : state.phone,
                publicKey: existingProfile.publicKey,
                userId: uid,
                isVerifying: false,
                clearError: true,
              ),
            );
            return;
          }
        }
        emit(
          state.copyWith(
            step: AuthStep.profile,
            isVerifying: false,
            userId: uid,
            clearError: true,
          ),
        );
        return;
      } catch (_) {}
    }
    emit(
      state.copyWith(
        step: AuthStep.profile,
        isVerifying: false,
        clearError: true,
      ),
    );
  }

  void _onTimeout(_AuthTimeout event, Emitter<AuthState> emit) {
    emit(state.copyWith(verificationId: event.verificationId));
  }

  void _onOtpChanged(AuthOtpChanged event, Emitter<AuthState> emit) {
    emit(state.copyWith(otp: event.code, clearError: true));
    if (event.code.length == 6) {
      add(const AuthOtpVerified());
    }
  }

  Future<void> _onOtpVerified(
    AuthOtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    if (state.otp.length != 6 || state.isVerifying) return;
    final epoch = ++_verificationEpoch;
    emit(state.copyWith(isVerifying: true, clearError: true));

    if (_authRepository == null) {
      // Mock / preview mode fallback for tests
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (emit.isDone || epoch != _verificationEpoch || state.step != AuthStep.otp) {
        return;
      }
      _resendTimer?.cancel();
      emit(state.copyWith(step: AuthStep.profile, isVerifying: false));
      return;
    }

    final verificationId = state.verificationId;
    if (verificationId == null) {
      emit(
        state.copyWith(
          isVerifying: false,
          errorMessage: 'Verification session expired. Please request a new code.',
        ),
      );
      return;
    }

    UserCredential credential;
    try {
      credential = await _authRepository.signInWithOtp(
        verificationId: verificationId,
        smsCode: state.otp,
      );
    } on FirebaseAuthException catch (e) {
      emit(
        state.copyWith(
          isVerifying: false,
          errorMessage: e.message ?? 'Invalid code. Please try again.',
        ),
      );
      return;
    } catch (_) {
      emit(
        state.copyWith(
          isVerifying: false,
          errorMessage: 'Verification failed. Please check the code and try again.',
        ),
      );
      return;
    }

    _resendTimer?.cancel();
    final uid = credential.user?.uid;
    UserProfile? existingProfile;
    if (uid != null && _userRepository != null) {
      try {
        existingProfile = await _userRepository.getUserProfile(uid);
      } catch (_) {
        // Tolerant of brand-new users or initial replica synchronization
      }
    }

    if (existingProfile != null && existingProfile.displayName.isNotEmpty) {
      emit(
        state.copyWith(
          step: AuthStep.complete,
          displayName: existingProfile.displayName,
          about: existingProfile.about,
          phone: existingProfile.phoneNumber.isNotEmpty
              ? existingProfile.phoneNumber
              : state.phone,
          publicKey: existingProfile.publicKey,
          userId: uid,
          isVerifying: false,
          clearError: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        step: AuthStep.profile,
        isVerifying: false,
        userId: uid,
        clearError: true,
      ),
    );
  }

  void _onPhoneEditRequested(AuthPhoneEditRequested event, Emitter<AuthState> emit) {
    _resendTimer?.cancel();
    _verificationEpoch++;
    emit(
      state.copyWith(
        step: AuthStep.phone,
        otp: '',
        isVerifying: false,
        clearError: true,
      ),
    );
  }

  Future<void> _onResendRequested(
    AuthResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state.resendSeconds > 0) return;
    emit(state.copyWith(resendSeconds: 30, otp: '', clearError: true));
    _startResendTimer();

    if (_authRepository != null) {
      final cleanedNumber = state.phone.replaceAll(RegExp(r'[^0-9+]'), '');
      await _authRepository.verifyPhoneNumber(
        phoneNumber: cleanedNumber,
        resendToken: state.resendToken,
        onCodeSent: (verificationId, resendToken) {
          add(_AuthCodeSent(verificationId, resendToken));
        },
        onVerificationFailed: (error) {
          add(_AuthVerificationFailed(error.message ?? 'Resend failed.'));
        },
        onVerificationCompleted: (credential) {
          add(_AuthAutoVerified(credential));
        },
        onCodeAutoRetrievalTimeout: (verificationId) {
          add(_AuthTimeout(verificationId));
        },
      );
    }
  }

  void _onResendTicked(AuthResendTicked event, Emitter<AuthState> emit) {
    if (state.resendSeconds <= 1) {
      _resendTimer?.cancel();
      emit(state.copyWith(resendSeconds: 0));
    } else {
      emit(state.copyWith(resendSeconds: state.resendSeconds - 1));
    }
  }

  Future<void> _onProfileUpdated(
    AuthProfileUpdated event,
    Emitter<AuthState> emit,
  ) async {
    final sanitizedName = event.name.trim();
    final sanitizedAbout = event.about.trim();

    if (sanitizedName.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Display name cannot be empty.',
        ),
      );
      return;
    }

    emit(state.copyWith(isVerifying: true, clearError: true));

    if (_userRepository == null || _cryptoService == null) {
      // Mock / preview mode fallback for tests
      emit(
        state.copyWith(
          step: AuthStep.complete,
          displayName: sanitizedName,
          about: sanitizedAbout,
          isVerifying: false,
          clearError: true,
        ),
      );
      return;
    }

    try {
      final uid = _authRepository?.currentUser?.uid ?? state.userId;
      if (uid == null) {
        emit(
          state.copyWith(
            isVerifying: false,
            errorMessage: 'Authentication session not found. Please log in again.',
          ),
        );
        return;
      }

      // Securely retrieve or generate X25519 identity public key
      final publicKey = await _cryptoService.getOrCreatePublicKey();

      final profile = UserProfile(
        uid: uid,
        phoneNumber: _authRepository?.currentUser?.phoneNumber ?? state.phone,
        displayName: sanitizedName,
        about: sanitizedAbout,
        publicKey: publicKey,
      );

      await _userRepository.saveUserProfile(profile);

      emit(
        state.copyWith(
          step: AuthStep.complete,
          displayName: sanitizedName,
          about: sanitizedAbout,
          publicKey: publicKey,
          userId: uid,
          isVerifying: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isVerifying: false,
          errorMessage: 'Unable to save profile. Please check your connection.',
        ),
      );
    }
  }

  void _onRestarted(AuthRestarted event, Emitter<AuthState> emit) {
    _resendTimer?.cancel();
    _verificationEpoch++;
    emit(
      state.copyWith(
        step: AuthStep.phone,
        otp: '',
        isVerifying: false,
        clearError: true,
      ),
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _resendTimer?.cancel();
    await _authRepository?.signOut();
    await _cryptoService?.clearKeys();
    emit(
      state.copyWith(
        step: AuthStep.phone,
        otp: '',
        isVerifying: false,
        clearError: true,
      ),
    );
  }

  void _onErrorDismissed(AuthErrorDismissed event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearError: true));
  }

  Future<void> _onUserChanged(
    _AuthUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    final user = event.user;
    if (user == null) {
      if (state.step != AuthStep.phone) {
        emit(
          state.copyWith(
            step: AuthStep.phone,
            otp: '',
            isVerifying: false,
            clearError: true,
          ),
        );
      }
      return;
    }

    emit(state.copyWith(userId: user.uid, isVerifying: true));

    UserProfile? profile;
    try {
      profile = await _userRepository?.getUserProfile(user.uid);
    } catch (_) {
      // Tolerant of brand-new profiles or initial database synchronization
    }

    if (profile != null && profile.displayName.isNotEmpty) {
      emit(
        state.copyWith(
          step: AuthStep.complete,
          displayName: profile.displayName,
          about: profile.about,
          phone: profile.phoneNumber.isNotEmpty
              ? profile.phoneNumber
              : (user.phoneNumber ?? state.phone),
          publicKey: profile.publicKey,
          userId: user.uid,
          isVerifying: false,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          step: AuthStep.profile,
          userId: user.uid,
          phone: user.phoneNumber ?? state.phone,
          isVerifying: false,
          clearError: true,
        ),
      );
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const AuthResendTicked()),
    );
  }

  @override
  Future<void> close() {
    _resendTimer?.cancel();
    _authStateSubscription?.cancel();
    return super.close();
  }
}
