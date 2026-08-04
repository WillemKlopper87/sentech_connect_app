// Entry point — build/maintained by W. Klopper, Research & Innovation.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Explicit edge-to-edge: content draws behind the system status/nav
  // bars, with our own SafeArea usage controlling what sits clear of them,
  // rather than leaving it to each Android version's differing defaults.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  setupLocator();

  final savedThemeMode = await AppPreferences.loadThemeMode();
  final savedUser = await AppPreferences.loadUser();

  runApp(SentechConnectApp(
    initialThemeMode: savedThemeMode,
    initialAuthState: savedUser == null
        ? const AuthState()
        : AuthState(status: AuthStatus.success, user: savedUser),
  ));
}
