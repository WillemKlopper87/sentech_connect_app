import 'package:flutter/widgets.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';
import 'package:sentech_connect_app/l10n/app_localizations_en.dart';

export 'package:sentech_connect_app/l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  /// Localised strings for the current locale. Falls back to English when no
  /// localisation delegate is installed (e.g. a bare `MaterialApp` in a widget
  /// test), so screens never crash for lack of one.
  AppLocalizations get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations) ?? AppLocalizationsEn();
}
