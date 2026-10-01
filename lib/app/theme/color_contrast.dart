import 'package:flutter/material.dart';

/// WCAG 2 contrast helpers. Tenant colours come from the server, so the theme
/// must never trust them to be legible.
abstract class ColorContrast {
  /// WCAG minimum for normal text.
  static const minimumText = 4.5;

  /// Contrast ratio between two colours, 1.0 (identical) to 21.0.
  static double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// White or black, whichever reads better on [background].
  static Color onColor(Color background) =>
      ratio(Colors.white, background) >= ratio(Colors.black, background) ? Colors.white : Colors.black;

  /// Darkens [colour] (towards black) until it reaches [minimum] against [against].
  static Color darkenUntil(Color colour, Color against, {double minimum = minimumText}) =>
      _blendUntil(colour, against, Colors.black, minimum);

  /// Lightens [colour] (towards white) until it reaches [minimum] against [against].
  static Color lightenUntil(Color colour, Color against, {double minimum = minimumText}) =>
      _blendUntil(colour, against, Colors.white, minimum);

  static Color _blendUntil(Color colour, Color against, Color target, double minimum) {
    final opaque = colour.withValues(alpha: 1);
    for (var step = 0; step <= 20; step++) {
      final candidate = Color.lerp(opaque, target, step / 20)!;
      if (ratio(candidate, against) >= minimum) return candidate;
    }
    return target;
  }
}
