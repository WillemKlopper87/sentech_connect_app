import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sentech_connect_app/app/connectivity_cubit.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
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
    this.initialDataSaver = false,
    this.quickSplash = false,
  });

  final ThemeMode initialThemeMode;
  final AuthState initialAuthState;
  final Locale? initialLocale;
  final bool initialDataSaver;

  /// True when the boot video already provided the branded moment, so the
  /// in-app splash only waits for the tenant and hands over without its reveal.
  final bool quickSplash;

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
    sessionExpired: locator<SessionEvents>().expired,
    providerUnavailable: locator<SessionEvents>().providerUnavailable,
    activeTenantSlug: () => locator<TenantContext>().slug,
    consents: locator(),
  );
  // Switching ISP signs the customer out first (ruling: one session per tenant).
  late final TenantCubit _tenantCubit = TenantCubit(
    repository: locator(),
    context: locator(),
    preferences: locator(),
    onTenantChanging: () => _authCubit.logOut(),
    onTenantApplied: _authCubit.ensureSessionMatches,
  )..bootstrap();
  late final AppRouter _appRouter = AppRouter(
    _authCubit,
    tenantCubit: _tenantCubit,
    quickSplash: widget.quickSplash,
  );

  StreamSubscription<String>? _moduleRefusedSub;

  @override
  void initState() {
    super.initState();
    // A module the API refuses is hidden at once (see TenantCubit.moduleRefused).
    if (locator.isRegistered<SessionEvents>()) {
      _moduleRefusedSub = locator<SessionEvents>().moduleRefused.listen(
        _tenantCubit.moduleRefused,
      );
    }
  }

  @override
  void dispose() {
    _moduleRefusedSub?.cancel();
    _appRouter.dispose();
    _tenantCubit.close();
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authCubit),
        BlocProvider.value(value: _tenantCubit),
        BlocProvider(create: (_) => CartCubit()),
        BlocProvider(create: (_) => ConnectivityCubit(locator())),
        BlocProvider(
          create: (_) => ThemeCubit(initial: widget.initialThemeMode),
        ),
        BlocProvider(create: (_) => LocaleCubit(initial: widget.initialLocale)),
        BlocProvider(
          create: (_) => DataSaverCubit(initial: widget.initialDataSaver),
        ),
      ],
      // Personal data must not outlive the session: when the user goes from
      // signed in to signed out (logout or account deletion) the in-memory
      // cart is emptied too, so the next person on a shared phone starts clean.
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) =>
            previous.isSignedIn && !current.isSignedIn,
        listener: (context, _) => context.read<CartCubit>().clear(),
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            final locale = context.watch<LocaleCubit>().state;
            final tenant = context.watch<TenantCubit>().state.config?.tenant;
            final primary = tenant?.branding.primaryColor;
            final secondary = tenant?.branding.secondaryColor;
            return MaterialApp.router(
              title:
                  tenant?.branding.appDisplayName ??
                  tenant?.name ??
                  'Sentech Connect',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(primary: primary, secondary: secondary),
              darkTheme: AppTheme.dark(primary: primary, secondary: secondary),
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
              builder: (context, child) =>
                  OfflineBannerHost(child: child ?? const SizedBox.shrink()),
            );
          },
        ),
      ),
    );
  }
}
