import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';

/// Small local-device persistence layer for settings that should survive
/// app restarts (theme choice, logged-in session) — there's no backend
/// session store yet, so "keeping a profile on the phone" means this.
class AppPreferences {
  static const _themeModeKey = 'pref_theme_mode';
  static const _userIdKey = 'pref_user_id';
  static const _userNameKey = 'pref_user_name';
  static const _userMobileKey = 'pref_user_mobile';

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere((m) => m.name == raw, orElse: () => ThemeMode.system);
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  static Future<User?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_userIdKey);
    if (id == null) return null;
    return User(
      id: id,
      fullName: prefs.getString(_userNameKey) ?? '',
      mobileNumber: prefs.getString(_userMobileKey) ?? '',
    );
  }

  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, user.id);
    await prefs.setString(_userNameKey, user.fullName);
    await prefs.setString(_userMobileKey, user.mobileNumber);
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userMobileKey);
  }

  // --- Free WiFi (ad-gated) session + daily ad-view cap ---
  static const _adWatchDateKey = 'pref_ad_watch_date';
  static const _adWatchCountKey = 'pref_ad_watch_count';
  static const _sessionGrantedAtKey = 'pref_wifi_session_granted_at';
  static const _sessionDurationKey = 'pref_wifi_session_duration_mins';

  /// Ads watched "today" — resets automatically once the stored date no
  /// longer matches today's date, rather than needing a background job.
  static Future<int> getAdsWatchedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_adWatchDateKey);
    final todayKey = _dateKey(DateTime.now());
    if (storedDate != todayKey) return 0;
    return prefs.getInt(_adWatchCountKey) ?? 0;
  }

  static Future<int> recordAdWatched() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateKey(DateTime.now());
    final current = await getAdsWatchedToday();
    final updated = current + 1;
    await prefs.setString(_adWatchDateKey, todayKey);
    await prefs.setInt(_adWatchCountKey, updated);
    return updated;
  }

  static Future<void> saveFreeWifiSession(DateTime grantedAt, int durationMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionGrantedAtKey, grantedAt.toIso8601String());
    await prefs.setInt(_sessionDurationKey, durationMinutes);
  }

  /// Returns (grantedAt, durationMinutes) if a session was saved, else null.
  static Future<(DateTime, int)?> loadFreeWifiSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDate = prefs.getString(_sessionGrantedAtKey);
    final duration = prefs.getInt(_sessionDurationKey);
    if (rawDate == null || duration == null) return null;
    return (DateTime.parse(rawDate), duration);
  }

  static Future<void> clearFreeWifiSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionGrantedAtKey);
    await prefs.remove(_sessionDurationKey);
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
