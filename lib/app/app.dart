import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sentech_connect_app/app/connectivity_cubit.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

/// App-lifetime state (auth session, cart contents, theme choice) is
/// provided once here at the root, rather than per-route, so it survives
/// navigation and the theme toggle in Account applies everywhere
/// immediately. The cart is deliberately cleared on logout (see below).
class SentechConnectApp extends StatefulWidget {
  const SentechConnectApp({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.initialAuthState = const AuthState(),
    this.initialLocale,
  });

  final ThemeMode initialThemeMode;
  final AuthState initialAuthState;
  final Locale? initialLocale;

  @override
  State<SentechConnectApp> createState() => _SentechConnectAppState();
}

class _SentechConnectAppState extends State<SentechConnectApp> {
  // The auth cubit lives here (not in a BlocProvider.create) because the
  // router's guards need it before the widget tree below exists.
  late final AuthCubit _authCubit = AuthCubit(
    locator(),
    sessionStore: locator(),
    biometrics: locator(),
    wiper: locator(),
    initial: widget.initialAuthState,
  );
  late final AppRouter _appRouter = AppRouter(_authCubit);

  @override
  void dispose() {
    _appRouter.dispose();
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authCubit),
        BlocProvider(create: (_) => CartCubit()),
        BlocProvider(create: (_) => ConnectivityCubit(locator())),
        BlocProvider(create: (_) => ThemeCubit(initial: widget.initialThemeMode)),
        BlocProvider(create: (_) => LocaleCubit(initial: widget.initialLocale)),
      ],
      // Personal data must not outlive the session: when the user goes from
      // signed in to signed out (logout or account deletion) the in-memory
      // cart is emptied too, so the next person on a shared phone starts clean.
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) => previous.isSignedIn && !current.isSignedIn,
        listener: (context, _) => context.read<CartCubit>().clear(),
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            final locale = context.watch<LocaleCubit>().state;
            return MaterialApp.router(
              title: 'Sentech Connect',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: _appRouter.router,
              builder: (context, child) => OfflineBannerHost(child: child ?? const SizedBox.shrink()),
            );
          },
        ),
      ),
    );
  }
}
