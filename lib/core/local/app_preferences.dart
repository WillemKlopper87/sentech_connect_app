import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small local-device persistence layer for NON-sensitive settings that
/// should survive app restarts (theme choice, language). Anything personal
/// (session, registration details, consent) lives behind `SecureStore`.
class AppPreferences {
  static const _themeModeKey = 'pref_theme_mode';
  static const _localeKey = 'pref_locale';
  static const _dataSaverKey = 'pref_data_saver';
  static const _bootVideoSeenKey = 'pref_boot_video_seen';

  static Future<bool> loadDataSaver() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_dataSaverKey) ??
          false;
    } catch (_) {
      // Unknown setting: avoid network-heavy media until the customer can retry.
      return true;
    }
  }

  static Future<void> saveDataSaver(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(_dataSaverKey, on);

  static Future<bool> loadBootVideoSeen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(
            _bootVideoSeenKey,
          ) ??
          false;
    } catch (_) {
      // Unknown setting: keep the intro static and retry the read next launch.
      return true;
    }
  }

  static Future<void> markBootVideoSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_bootVideoSeenKey, true);

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  /// Saved UI language code (e.g. 'zu'), or null to follow the device.
  static Future<Locale?> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    return code == null ? null : Locale(code);
  }

  static Future<void> saveLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }
  }
}
