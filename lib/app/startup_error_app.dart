import 'package:flutter/material.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Shown instead of a blank screen when the build-time configuration is
/// invalid (bad APP_FLAVOR / API_BASE_URL). Uses bundled localizations and stays
/// detail-free: it works before any service exists and must not leak
/// configuration to whoever holds the device.
Widget buildStartupErrorApp() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  debugShowCheckedModeBanner: false,
  home: Builder(
    builder: (context) => Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              context.l10n.startupErrorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    ),
  ),
);
