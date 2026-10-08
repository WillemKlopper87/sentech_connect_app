import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/theme/app_colors.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/color_contrast.dart';

void main() {
  test(
    'white text on both brand gradient stops is at least 4.5:1 (WCAG AA body text)',
    () {
      for (final c in [AppColors.darkBlue, AppColors.gradientEnd]) {
        expect(
          ColorContrast.ratio(Colors.white, c),
          greaterThanOrEqualTo(ColorContrast.minimumText),
          reason: '$c',
        );
      }
    },
  );

  test('the old teal end stop really failed (guards the regression)', () {
    expect(
      ColorContrast.ratio(Colors.white, AppColors.lightBlue),
      lessThan(ColorContrast.minimumText),
    );
  });

  test('a pale tenant secondary is darkened to 4.5:1 on the light page', () {
    final t = AppTheme.light(secondary: const Color(0xFFFFFF99));
    expect(
      ColorContrast.ratio(t.colorScheme.secondary, AppColors.lightBg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      ColorContrast.ratio(t.colorScheme.onSecondary, t.colorScheme.secondary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('a dark tenant secondary is lightened to 4.5:1 on navy', () {
    final t = AppTheme.dark(secondary: const Color(0xFF000010));
    expect(
      ColorContrast.ratio(t.colorScheme.secondary, AppColors.darkBlue),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      ColorContrast.ratio(t.colorScheme.onSecondary, t.colorScheme.secondary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('without a tenant secondary the brand secondary is unchanged', () {
    expect(AppTheme.light().colorScheme.secondary, AppColors.lightBlue);
    expect(AppTheme.dark().colorScheme.secondary, AppColors.orange);
  });
}
