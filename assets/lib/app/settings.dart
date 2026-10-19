import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Which information layer the world map renders.
enum GameMapMode { political, military }

/// User preferences, persisted independently of any campaign.
@immutable
class AppSettings {
  const AppSettings({
    this.localeCode = 'en',
    this.soundEnabled = false,
    this.musicEnabled = false,
    this.animationsEnabled = true,
    this.defaultMapMode = GameMapMode.political,
  });

  final String localeCode;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool animationsEnabled;
  final GameMapMode defaultMapMode;

  Locale get locale => Locale(localeCode);

  bool get isPersian => localeCode == 'fa';

  AppSettings copyWith({
    String? localeCode,
    bool? soundEnabled,
    bool? musicEnabled,
    bool? animationsEnabled,
    GameMapMode? defaultMapMode,
  }) => AppSettings(
    localeCode: localeCode ?? this.localeCode,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    musicEnabled: musicEnabled ?? this.musicEnabled,
    animationsEnabled: animationsEnabled ?? this.animationsEnabled,
    defaultMapMode: defaultMapMode ?? this.defaultMapMode,
  );

  Map<String, dynamic> toJson() => {
    'locale': localeCode,
    'sound': soundEnabled,
    'music': musicEnabled,
    'animations': animationsEnabled,
    'mapMode': defaultMapMode.name,
  };

  static AppSettings fromJson(Map<String, dynamic> json) => AppSettings(
    localeCode: json['locale'] == 'fa' ? 'fa' : 'en',
    soundEnabled: json['sound'] == true,
    musicEnabled: json['music'] == true,
    animationsEnabled: json['animations'] != false,
    defaultMapMode: json['mapMode'] == 'military'
        ? GameMapMode.military
        : GameMapMode.political,
  );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(GameConstants.settingsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = AppSettings.fromJson(decoded);
      } else if (decoded is Map) {
        state = AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Corrupt preferences fall back to defaults rather than crashing.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        GameConstants.settingsKey,
        jsonEncode(state.toJson()),
      );
    } catch (_) {
      // Persisting preferences is best-effort.
    }
  }

  void setLocale(String code) {
    state = state.copyWith(localeCode: code == 'fa' ? 'fa' : 'en');
    _persist();
  }

  void toggleSound(bool value) {
    state = state.copyWith(soundEnabled: value);
    _persist();
  }

  void toggleMusic(bool value) {
    state = state.copyWith(musicEnabled: value);
    _persist();
  }

  void toggleAnimations(bool value) {
    state = state.copyWith(animationsEnabled: value);
    _persist();
  }

  void setDefaultMapMode(GameMapMode mode) {
    state = state.copyWith(defaultMapMode: mode);
    _persist();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});
