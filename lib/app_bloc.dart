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
  final dynamic value;
  @override
  List<Object?> get props => [key, value];
}

final class AppCacheUpdated extends AppEvent {
  const AppCacheUpdated({
    required this.cacheMb,
    required this.photosBytes,
    required this.voiceBytes,
    required this.fileBytes,
  });
  final int cacheMb;
  final int photosBytes;
  final int voiceBytes;
  final int fileBytes;
  @override
  List<Object?> get props => [cacheMb, photosBytes, voiceBytes, fileBytes];
}

final class AppCacheCleared extends AppEvent {
  const AppCacheCleared();
}

final class AppState extends Equatable {
  const AppState({
    this.themeMode = ThemeMode.system,
    this.cacheMb = 186,
    this.photosBytes = 0,

    this.voiceBytes = 0,
    this.fileBytes = 0,
    this.preferences = const {
      'Last seen': true,
      'Read receipts': true,
      'App lock': false,
      'Message notifications': true,
      'Message previews': true,
      'Quiet hours': false,
      'Quiet hours start': '22:00',
      'Quiet hours end': '07:00',
      'Save photos': false,
      'Download on Wi-Fi': true,
      'Auto-download photos': 'Wi-Fi and Cellular',
      'Auto-download audio': 'Wi-Fi and Cellular',
      'Auto-download documents': 'Wi-Fi only',
      'Enter is send': true,
      'Font size': 'Default',
      'Automatic backups': false,
      'Backup frequency': 'Weekly',
      'Last backup timestamp': '',
    },
  });

  final ThemeMode themeMode;
  final int cacheMb;
  final int photosBytes;
  final int voiceBytes;
  final int fileBytes;
  final Map<String, dynamic> preferences;

  AppState copyWith({
    ThemeMode? themeMode,
    int? cacheMb,
    int? photosBytes,
    int? voiceBytes,
    int? fileBytes,
    Map<String, dynamic>? preferences,
  }) => AppState(
    themeMode: themeMode ?? this.themeMode,
    cacheMb: cacheMb ?? this.cacheMb,
    photosBytes: photosBytes ?? this.photosBytes,
    voiceBytes: voiceBytes ?? this.voiceBytes,
    fileBytes: fileBytes ?? this.fileBytes,
    preferences: preferences ?? this.preferences,
  );

  @override
  List<Object?> get props => [
    themeMode,
    cacheMb,
    photosBytes,
    voiceBytes,
    fileBytes,
    preferences,
  ];
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
    on<AppCacheUpdated>((e, emit) {
      final updated = state.copyWith(
        cacheMb: e.cacheMb,
        photosBytes: e.photosBytes,
        voiceBytes: e.voiceBytes,
        fileBytes: e.fileBytes,
      );
      emit(updated);
      _storage.saveSettings(updated);
    });
    on<AppCacheCleared>((e, emit) {
      final updated = state.copyWith(
        cacheMb: 0,
        photosBytes: 0,
        voiceBytes: 0,
        fileBytes: 0,
      );
      emit(updated);
      _storage.saveSettings(updated);
    });
  }

  final AppSettingsStorage _storage;
}

