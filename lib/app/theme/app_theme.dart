import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentech_connect_app/app/theme/app_colors.dart';

/// Light/dark ColorScheme pair derived from docs/brand-tokens.md.
///
/// Dark mode uses the brand's own dark-navy surface (AppColors.darkBlue)
/// rather than a generic near-black, matching how the CI manual already
/// treats dark backgrounds throughout the stationery/brand-application pages.
///
/// The app bar carries a solid brand-colour background (SENTECH Blue in
/// light mode) rather than sitting transparent over a plain white page —
/// matching how the CI manual's own screens (newsletters, letterheads,
/// internal communiques) always use a coloured header band, not a
/// colourless one.
abstract class AppTheme {
  /// [primary] is the tenant's branding colour (white-label, spec §12);
  /// null keeps the Sentech brand.
  static ThemeData light({Color? primary}) {
    final brand = primary ?? AppColors.sentechBlue;
    final onBrand = _onColor(brand);
    final scheme = ColorScheme.light(
      primary: brand,
      onPrimary: onBrand,
      secondary: AppColors.lightBlue,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.darkGrey,
      error: AppColors.red,
      onError: Colors.white,
    );
    return _themeFrom(scheme, scaffoldBg: AppColors.lightBg, appBarBg: brand, appBarFg: onBrand, navBarBg: Colors.white);
  }

  /// Dark mode lightens a tenant colour so it stays readable on navy.
  static ThemeData dark({Color? primary}) {
    final accent = primary == null ? AppColors.lightBlue : Color.lerp(primary, Colors.white, 0.35)!;
    final scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: primary == null ? AppColors.darkBlue : _onColor(accent),
      secondary: AppColors.orange,
      onSecondary: Colors.black,
      surface: AppColors.darkBlue,
      onSurface: Colors.white,
      error: AppColors.red,
      onError: Colors.white,
    );
    return _themeFrom(scheme, scaffoldBg: AppColors.darkBg, appBarBg: AppColors.darkBlue, appBarFg: Colors.white, navBarBg: AppColors.darkSurface);
  }

  static Color _onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? Colors.white : Colors.black;

  static ThemeData _themeFrom(
    ColorScheme scheme, {
    required Color scaffoldBg,
    required Color appBarBg,
    required Color appBarFg,
    required Color navBarBg,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: _textTheme(scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        centerTitle: false,
        // Light status-bar icons on a dark bar; dark icons on a light tenant colour.
        systemOverlayStyle: appBarFg == Colors.white ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: appBarFg,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
        elevation: scheme.brightness == Brightness.dark ? 0 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBarBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? scheme.primary : scheme.onSurfaceVariant);
        }),
      ),
    );
  }

  static TextTheme _textTheme(Color base) {
    // Avenir Next is licensed and not embeddable here; the CI manual's own
    // system fallback (Arial) is used at the platform's default sans-serif.
    return TextTheme(
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: base),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: base),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: base),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: base),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: base),
      bodyMedium: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, color: base),
      labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: base),
    );
  }
}
