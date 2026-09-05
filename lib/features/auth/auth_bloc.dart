import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class AuthCountrySelected extends AuthEvent {
  const AuthCountrySelected(this.iso, this.code);
  final String iso, code;
  @override
  List<Object?> get props => [iso, code];
}

final class AuthCountrySearched extends AuthEvent {
  const AuthCountrySearched(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

enum AuthStep { phone, otp, profile, complete }

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
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

final class AuthState extends Equatable {
  const AuthState({
    required this.step,
    this.phone = '+880 1712 345 678',
    this.otp = '',
    this.isVerifying = false,
    this.resendSeconds = 24,
    this.displayName = 'Navid',
    this.about = 'Building things worth keeping open.',
    this.countryIso = 'BD',
    this.countryCode = '+880',
    this.countryQuery = '',
  });

  final AuthStep step;
  final String phone;
  final String otp;
  final bool isVerifying;
  final int resendSeconds;
  final String displayName;
  final String about;
  final String countryIso, countryCode, countryQuery;

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
    );
  }

  @override
  List<Object?> get props => [
    countryIso,
    countryCode,
    countryQuery,
    step,
    phone,
    otp,
    isVerifying,
    resendSeconds,
    displayName,
    about,
  ];
}

final class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({bool previewAuthenticated = true})
    : super(
        AuthState(
          step: previewAuthenticated ? AuthStep.complete : AuthStep.phone,
        ),
      ) {
    on<AuthCountrySelected>(
      (e, emit) => emit(
        state.copyWith(
          countryIso: e.iso,
          countryCode: e.code,
          countryQuery: '',
        ),
      ),
    );
    on<AuthCountrySearched>(
      (e, emit) => emit(state.copyWith(countryQuery: e.query)),
    );
    on<AuthPhoneSubmitted>((event, emit) {
      emit(
        state.copyWith(
          step: AuthStep.otp,
          phone: event.phone,
          otp: '',
          resendSeconds: 24,
        ),
      );
      _startResendTimer();
    });
    on<AuthOtpChanged>((event, emit) {
      emit(state.copyWith(otp: event.code));
      if (event.code.length == 6) add(const AuthOtpVerified());
    });
    on<AuthOtpVerified>((event, emit) async {
      if (state.otp.length != 6 || state.isVerifying) return;
      final epoch = ++_verificationEpoch;
      emit(state.copyWith(isVerifying: true));
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (emit.isDone ||
          epoch != _verificationEpoch ||
          state.step != AuthStep.otp) {
        return;
      }
      _resendTimer?.cancel();
      emit(state.copyWith(step: AuthStep.profile, isVerifying: false));
    });
    on<AuthPhoneEditRequested>((event, emit) {
      _resendTimer?.cancel();
      _verificationEpoch++;
      emit(state.copyWith(step: AuthStep.phone, otp: '', isVerifying: false));
    });
    on<AuthResendRequested>((event, emit) {
      if (state.resendSeconds > 0) return;
      emit(state.copyWith(resendSeconds: 24, otp: ''));
      _startResendTimer();
    });
    on<AuthResendTicked>((event, emit) {
      if (state.resendSeconds <= 1) {
        _resendTimer?.cancel();
        emit(state.copyWith(resendSeconds: 0));
      } else {
        emit(state.copyWith(resendSeconds: state.resendSeconds - 1));
      }
    });
    on<AuthProfileUpdated>((event, emit) {
      if (event.name.trim().isEmpty) return;
      emit(
        state.copyWith(
          step: AuthStep.complete,
          displayName: event.name,
          about: event.about,
        ),
      );
    });
    on<AuthRestarted>((event, emit) {
      _resendTimer?.cancel();
      _verificationEpoch++;
      emit(state.copyWith(step: AuthStep.phone, otp: '', isVerifying: false));
    });
  }

  Timer? _resendTimer;
  int _verificationEpoch = 0;

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
    return super.close();
  }
}
