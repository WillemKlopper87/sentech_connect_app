import 'package:flutter/material.dart';

/// Brand tokens extracted from the Sentech CI Manual 2025.
/// See docs/brand-tokens.md in the project root for source values.
abstract class AppColors {
  // Primary
  static const sentechBlue = Color(0xFF005BAA);
  static const darkGrey = Color(0xFF6D6E71);
  static const lightGrey = Color(0xFFBCBEC0);

  // Secondary / accents
  static const darkBlue = Color(0xFF00335C); // brand's own dark-mode surface
  static const orange = Color(0xFFFAA61A);
  static const limeGreen = Color(0xFF8EAF3F);
  static const lightBlue = Color(0xFF00ACC6); // dark-mode primary accent
  static const red = Color(0xFFED1C24);

  /// End stop of the navy-to-teal brand gradient behind white text: a deeper
  /// teal than [lightBlue] (white on [lightBlue] is only 2.7:1), so white
  /// body text on every part of the gradient is at least 4.5:1 (WCAG AA).
  static const gradientEnd = Color(0xFF00788A);

  // Neutrals used only for chrome, not in the CI manual itself
  static const lightBg = Color(0xFFEEF2F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const darkBg = Color(0xFF0A1826);
  static const darkSurface = Color(0xFF102030);
}
