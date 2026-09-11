import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/services/app_settings_storage.dart';

sealed class AppEvent extends Equatable {
  const AppEvent();
  @override
  List<Object?> get props => [];
}

final class AppThemeChanged extends AppEvent {
  const AppThemeChanged(this.mode);
  final ThemeMode mode;
  @override
  List<Object?> get props => [mode];
}

final class AppPreferenceChanged extends AppEvent {
  const AppPreferenceChanged(this.key, this.value);
  final String key;
  final bool value;
  @override
  List<Object?> get props => [key, value];
}

final class AppCacheCleared extends AppEvent {
  const AppCacheCleared();
}

final class AppState extends Equatable {
  const AppState({
    this.themeMode = ThemeMode.system,
    this.cacheMb = 186,
    this.preferences = const {
      'Last seen': true,
      'Read receipts': true,
      'App lock': false,
      'Message notifications': true,
      'Message previews': true,
      'Quiet hours': false,
      'Save photos': false,
      'Download on Wi-Fi': true,
    },
  });
  final ThemeMode themeMode;
  final int cacheMb;
  final Map<String, bool> preferences;
  AppState copyWith({
    ThemeMode? themeMode,
    int? cacheMb,
    Map<String, bool>? preferences,
  }) => AppState(
    themeMode: themeMode ?? this.themeMode,
    cacheMb: cacheMb ?? this.cacheMb,
    preferences: preferences ?? this.preferences,
  );
  @override
  List<Object?> get props => [themeMode, cacheMb, preferences];
}

final class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc({
    AppState initialState = const AppState(),
    AppSettingsStorage? storage,
  })  : _storage = storage ?? const AppSettingsStorage(),
        super(initialState) {
    on<AppThemeChanged>((e, emit) {
      final updated = state.copyWith(themeMode: e.mode);
      emit(updated);
      _storage.saveSettings(updated);
    });
    on<AppPreferenceChanged>((e, emit) {
      final updated = state.copyWith(
        preferences: {...state.preferences, e.key: e.value},
      );
      emit(updated);
      _storage.saveSettings(updated);
    });
    on<AppCacheCleared>((e, emit) {
      final updated = state.copyWith(cacheMb: 0);
      emit(updated);
      _storage.saveSettings(updated);
    });
  }

  final AppSettingsStorage _storage;
}
