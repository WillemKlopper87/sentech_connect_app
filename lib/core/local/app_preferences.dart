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
  static bool _dataSaverNeedsReload = false;
  static bool _bootVideoSeenNeedsReload = false;

  static Future<bool> loadDataSaver() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_dataSaverNeedsReload) {
        await prefs.reload();
        _dataSaverNeedsReload = false;
      }
      return prefs.getBool(_dataSaverKey) ?? false;
    } catch (_) {
      // Unknown setting: avoid network-heavy media until the customer can retry.
      return true;
    }
  }

  static Future<void> saveDataSaver(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final saved = await prefs.setBool(_dataSaverKey, on);
      if (!saved) throw StateError('Data saver preference was not saved');
      _dataSaverNeedsReload = false;
    } catch (_) {
      _dataSaverNeedsReload = true;
      try {
        await prefs.reload();
        _dataSaverNeedsReload = false;
      } catch (_) {
        // Reads stay conservative until a later reload succeeds.
      }
      rethrow;
    }
  }

  static Future<bool> loadBootVideoSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_bootVideoSeenNeedsReload) {
        await prefs.reload();
        _bootVideoSeenNeedsReload = false;
      }
      return prefs.getBool(_bootVideoSeenKey) ?? false;
    } catch (_) {
      // Unknown setting: keep the intro static and retry the read next launch.
      return true;
    }
  }

  static Future<void> markBootVideoSeen() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final saved = await prefs.setBool(_bootVideoSeenKey, true);
      if (!saved) throw StateError('Boot video seen preference was not saved');
      _bootVideoSeenNeedsReload = false;
    } catch (_) {
      _bootVideoSeenNeedsReload = true;
      try {
        await prefs.reload();
        _bootVideoSeenNeedsReload = false;
      } catch (_) {
        // Reads stay conservative until a later reload succeeds.
      }
      rethrow;
    }
  }

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
