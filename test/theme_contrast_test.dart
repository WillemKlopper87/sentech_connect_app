import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/theme/app_colors.dart';
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
}
