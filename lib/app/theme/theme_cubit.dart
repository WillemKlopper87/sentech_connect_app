import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';

/// Manual light/dark/system toggle, independent of the OS setting —
/// exposed from the Account tab so the brand's dark-navy treatment can be
/// seen on demand rather than only when the device happens to be in dark
/// mode. Persisted locally so the choice survives an app restart.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({ThemeMode initial = ThemeMode.system}) : super(initial);

  void setMode(ThemeMode mode) {
    emit(mode);
    AppPreferences.saveThemeMode(mode);
  }

  void toggle() {
    final isCurrentlyDark = state == ThemeMode.dark;
    setMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}
