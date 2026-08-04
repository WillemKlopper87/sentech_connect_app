import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';

/// App-lifetime state (auth session, cart contents, theme choice) is
/// provided once here at the root, rather than per-route, so it survives
/// navigation — e.g. logging out and back in doesn't lose the cart, and
/// the theme toggle in Account applies everywhere immediately.
class SentechConnectApp extends StatelessWidget {
  SentechConnectApp({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.initialAuthState = const AuthState(),
  });

  final ThemeMode initialThemeMode;
  final AuthState initialAuthState;
  final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(locator(), initial: initialAuthState)),
        BlocProvider(create: (_) => CartCubit()),
        BlocProvider(create: (_) => ThemeCubit(initial: initialThemeMode)),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'Sentech Connect',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
