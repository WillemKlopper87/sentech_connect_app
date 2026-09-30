import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';

/// UI language chosen in Account; null follows the device language. Persisted
/// in SharedPreferences (not personal data).
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit({Locale? initial, Future<void> Function(Locale?)? save})
      : _save = save ?? AppPreferences.saveLocale,
        super(initial);

  final Future<void> Function(Locale?) _save;

  void setLocale(Locale? locale) {
    emit(locale);
    _save(locale);
  }
}
