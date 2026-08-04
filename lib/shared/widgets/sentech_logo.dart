import 'package:flutter/material.dart';

/// The actual Sentech logo lockup (icon + wordmark + "connecting You" tagline),
/// from assets/brand/logo/ (source: Sentech CI Manual 2025).
///
/// Per the CI manual's logo-usage rule (docs/brand-tokens.md): the full-colour
/// lockup is only ever placed on a white/light background; on any other
/// background it must be the reversed all-white lockup. This widget picks the
/// correct asset from the current theme brightness automatically, so callers
/// never need to choose manually.
class SentechLogo extends StatelessWidget {
  const SentechLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark
          ? 'assets/brand/logo/sentech_logo_white.png'
          : 'assets/brand/logo/sentech_logo_full_colour.jpg',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
