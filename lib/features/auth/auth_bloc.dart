import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

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
  const AuthProfileUpdated({
    required this.name,
    required this.about,
    this.avatarFilePath,
    this.avatarUrl,
    this.removeAvatar = false,
  });
  final String name;
  final String about;
  final String? avatarFilePath;
  final String? avatarUrl;
  final bool removeAvatar;

  @override
  List<Object?> get props => [name, about, avatarFilePath, avatarUrl, removeAvatar];
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

final class AuthKeyRegenerated extends AuthEvent {
  const AuthKeyRegenerated();
}

final class AuthKeyVaultRestored extends AuthEvent {
  const AuthKeyVaultRestored(this.vaultJson);
  final String vaultJson;

  @override
  List<Object?> get props => [vaultJson];
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
    this.avatarUrl,
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
  final String? avatarUrl;
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
    String? avatarUrl,
    bool clearAvatar = false,
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
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
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
        avatarUrl,
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
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
    bool previewAuthenticated = true,
  })  : _authRepository = authRepository,
        _userRepository = userRepository,
        _cryptoService = cryptoService,
        _customStorage = storage,
        _customFirestore = firestore,
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
    on<AuthKeyRegenerated>(_onKeyRegenerated);
    on<AuthKeyVaultRestored>(_onKeyVaultRestored);
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
  final FirebaseStorage? _customStorage;
  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
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
                avatarUrl: existingProfile.avatarUrl,
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
      final effectivePub = await _syncOrRestoreKeyVault(
        uid: existingProfile.uid,
        profile: existingProfile,
      );
      emit(
        state.copyWith(
          step: AuthStep.complete,
          displayName: existingProfile.displayName,
          about: existingProfile.about,
          avatarUrl: existingProfile.avatarUrl,
          phone: existingProfile.phoneNumber.isNotEmpty
              ? existingProfile.phoneNumber
              : state.phone,
          publicKey: effectivePub,
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

    final uid = _authRepository?.currentUser?.uid ?? state.userId;

    String? finalAvatarUrl = state.avatarUrl;
    if (event.removeAvatar) {
      finalAvatarUrl = null;
    } else if (event.avatarFilePath != null && event.avatarFilePath!.isNotEmpty) {
      final file = File(event.avatarFilePath!);
      if (await file.exists()) {
        final rawBytes = await file.readAsBytes();
        String? downloadUrl;
        String? base64Data;
        try {
          final storagePath = 'users/${uid ?? "user"}/avatar.jpg';
          final storageRef = _storage.ref(storagePath);
          final uploadTask = await storageRef.putData(
            rawBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          ).timeout(const Duration(milliseconds: 3500));
          downloadUrl = await uploadTask.ref.getDownloadURL().timeout(const Duration(milliseconds: 2500));
        } catch (_) {
          // Inline base64 fallback maintains $0 budget resilience if Cloud Storage is offline or unprovisioned
          if (rawBytes.length < 800 * 1024) {
            base64Data = 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
          }
        }

        // Cache locally in persistent application documents directory
        try {
          final docsDir = await getApplicationDocumentsDirectory();
          final avatarsDir = Directory('${docsDir.path}/relay_avatars');
          if (!await avatarsDir.exists()) {
            await avatarsDir.create(recursive: true);
          }
          final localCacheFile = File('${avatarsDir.path}/avatar_${uid ?? "user"}.jpg');
          await localCacheFile.writeAsBytes(rawBytes);
        } catch (_) {}

        finalAvatarUrl = downloadUrl ?? base64Data ?? file.path;
      }
    } else if (event.avatarUrl != null) {
      finalAvatarUrl = event.avatarUrl;
    }

    // Sync to FirebaseAuth currentUser photoURL
    try {
      if (event.removeAvatar) {
        await _authRepository?.currentUser?.updatePhotoURL(null);
      } else if (finalAvatarUrl != null &&
          (finalAvatarUrl.startsWith('http://') || finalAvatarUrl.startsWith('https://'))) {
        await _authRepository?.currentUser?.updatePhotoURL(finalAvatarUrl);
      }
    } catch (_) {}

    if (_userRepository == null || _cryptoService == null) {
      // Mock / preview mode fallback for tests
      emit(
        state.copyWith(
          step: AuthStep.complete,
          displayName: sanitizedName,
          about: sanitizedAbout,
          avatarUrl: finalAvatarUrl,
          clearAvatar: event.removeAvatar,
          isVerifying: false,
          clearError: true,
        ),
      );
      return;
    }

    try {
      if (uid == null) {
        emit(
          state.copyWith(
            isVerifying: false,
            errorMessage: 'Authentication session not found. Please log in again.',
          ),
        );
        return;
      }

      // Securely retrieve or generate X25519 identity public key and key vault
      final publicKey = await _cryptoService.getOrCreatePublicKey();
      String? keyVault;
      try {
        keyVault = await _cryptoService.exportEncryptedKeyVault(uid);
      } catch (_) {}

      final profile = UserProfile(
        uid: uid,
        phoneNumber: _authRepository?.currentUser?.phoneNumber ?? state.phone,
        displayName: sanitizedName,
        about: sanitizedAbout,
        publicKey: publicKey,
        avatarUrl: finalAvatarUrl,
        encryptedKeyVault: keyVault,
      );

      await _userRepository.saveUserProfile(profile);

      // Propagate updated name and avatar to active user chats asynchronously
      try {
        final chatsQuery = await _firestore
            .collection('chats')
            .where('participantIds', arrayContains: uid)
            .get();
        for (final doc in chatsQuery.docs) {
          final updates = <String, dynamic>{
            'participantNames.$uid': sanitizedName,
          };
          if (finalAvatarUrl != null) {
            updates['participantAvatars.$uid'] = finalAvatarUrl;
          } else {
            updates['participantAvatars.$uid'] = FieldValue.delete();
          }
          doc.reference.update(updates).catchError((_) {});
        }
      } catch (_) {}

      emit(
        state.copyWith(
          step: AuthStep.complete,
          displayName: sanitizedName,
          about: sanitizedAbout,
          avatarUrl: finalAvatarUrl,
          clearAvatar: event.removeAvatar,
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

    String? photoUrl;
    try {
      photoUrl = user.photoURL;
    } catch (_) {}
    String? effectiveAvatar = profile?.avatarUrl ?? photoUrl;
    if (effectiveAvatar == null || effectiveAvatar.isEmpty) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final localFile = File('${docsDir.path}/relay_avatars/avatar_${user.uid}.jpg');
        if (await localFile.exists()) {
          effectiveAvatar = localFile.path;
        }
      } catch (_) {}
    }

    if (profile != null && profile.displayName.isNotEmpty) {
      final effectivePub = await _syncOrRestoreKeyVault(
        uid: user.uid,
        profile: profile,
      );
      emit(
        state.copyWith(
          step: AuthStep.complete,
          displayName: profile.displayName,
          about: profile.about,
          avatarUrl: effectiveAvatar,
          phone: profile.phoneNumber.isNotEmpty
              ? profile.phoneNumber
              : (user.phoneNumber ?? state.phone),
          publicKey: effectivePub,
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
          avatarUrl: effectiveAvatar,
          phone: user.phoneNumber ?? state.phone,
          isVerifying: false,
          clearError: true,
        ),
      );
    }
  }

  Future<String> _syncOrRestoreKeyVault({
    required String uid,
    required UserProfile profile,
  }) async {
    if (_cryptoService == null) return profile.publicKey;

    final hasKey = await _cryptoService.hasLocalPrivateKey();
    if (!hasKey) {
      // Fresh simulator or newly installed device: attempt to restore from vault
      if (profile.encryptedKeyVault != null &&
          profile.encryptedKeyVault!.isNotEmpty) {
        try {
          return await _cryptoService.importEncryptedKeyVault(
            encryptedVault: profile.encryptedKeyVault!,
            uid: uid,
          );
        } catch (_) {
          // If vault decryption fails (e.g. tampered data), generate new keypair
          final newPub = await _cryptoService.getOrCreatePublicKey();
          try {
            final newVault = await _cryptoService.exportEncryptedKeyVault(uid);
            await _userRepository?.saveUserProfile(
              profile.copyWith(publicKey: newPub, encryptedKeyVault: newVault),
            );
          } catch (_) {}
          return newPub;
        }
      } else {
        // Legacy profile without vault: generate keypair and backfill vault
        final newPub = await _cryptoService.getOrCreatePublicKey();
        try {
          final newVault = await _cryptoService.exportEncryptedKeyVault(uid);
          await _userRepository?.saveUserProfile(
            profile.copyWith(publicKey: newPub, encryptedKeyVault: newVault),
          );
        } catch (_) {}
        return newPub;
      }
    } else {
      // Local key exists: backfill vault if absent
      if (profile.encryptedKeyVault == null) {
        try {
          final vault = await _cryptoService.exportEncryptedKeyVault(uid);
          await _userRepository?.saveUserProfile(
            profile.copyWith(encryptedKeyVault: vault),
          );
        } catch (_) {}
      }
      return profile.publicKey;
    }
  }

  Future<void> _onKeyRegenerated(
    AuthKeyRegenerated event,
    Emitter<AuthState> emit,
  ) async {
    if (_cryptoService == null) return;
    try {
      final newPub = await _cryptoService.regenerateKeypair();
      emit(state.copyWith(publicKey: newPub));
      final uid = state.userId ?? _authRepository?.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        final vault = await _cryptoService.exportEncryptedKeyVault(uid);
        final profile = await _userRepository?.getUserProfile(uid);
        if (profile != null) {
          await _userRepository?.saveUserProfile(
            profile.copyWith(publicKey: newPub, encryptedKeyVault: vault),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _onKeyVaultRestored(
    AuthKeyVaultRestored event,
    Emitter<AuthState> emit,
  ) async {
    if (_cryptoService == null) return;
    try {
      final uid = state.userId ?? _authRepository?.currentUser?.uid ?? 'local_user';
      final restoredPub = await _cryptoService.importEncryptedKeyVault(
        encryptedVault: event.vaultJson,
        uid: uid,
      );
      emit(state.copyWith(publicKey: restoredPub));
      final profile = await _userRepository?.getUserProfile(uid);
      if (profile != null) {
        await _userRepository?.saveUserProfile(
          profile.copyWith(
            publicKey: restoredPub,
            encryptedKeyVault: event.vaultJson,
          ),
        );
      }
    } catch (_) {
      rethrow;
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
