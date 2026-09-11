import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app_bloc.dart';

/// Storage service for persisting user preferences and theme settings to disk.
class AppSettingsStorage {
  const AppSettingsStorage({this.customDir});

  final Directory? customDir;

  Future<File> _getSettingsFile() async {
    final dir = customDir ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/relay_settings.json');
  }

  /// Loads saved AppState from disk, falling back to defaults if not found.
  Future<AppState> loadSettings() async {
    try {
      final file = await _getSettingsFile();
      if (!await file.exists()) {
        return const AppState();
      }
      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;

      final themeStr = data['themeMode'] as String? ?? 'system';
      final themeMode = switch (themeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

      final rawPrefs = data['preferences'] as Map<String, dynamic>?;
      final preferences = rawPrefs?.map(
            (k, v) => MapEntry(k, v is bool ? v : true),
          ) ??
          const AppState().preferences;

      final cacheMb = data['cacheMb'] as int? ?? 186;

      return AppState(
        themeMode: themeMode,
        preferences: preferences,
        cacheMb: cacheMb,
      );
    } catch (_) {
      return const AppState();
    }
  }

  /// Persists the active AppState to disk asynchronously.
  Future<void> saveSettings(AppState state) async {
    try {
      final file = await _getSettingsFile();
      final themeStr = switch (state.themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

      final data = <String, dynamic>{
        'themeMode': themeStr,
        'preferences': state.preferences,
        'cacheMb': state.cacheMb,
        'savedAt': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }
}
