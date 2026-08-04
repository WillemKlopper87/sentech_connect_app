import 'package:flutter/material.dart';

/// The dot-grid graphic device from the CI manual (docs/brand-tokens.md),
/// used as a decorative hero panel background on dark, brand-colour surfaces.
class DotGridPanel extends StatelessWidget {
  const DotGridPanel({
    super.key,
    this.height = 120,
    this.child,
    this.gradientColors,
  });

  final double height;
  final Widget? child;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? const [Color(0xFF0B3A63), Color(0xFF062244)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _DotGridPainter()),
            if (child != null) Center(child: child),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    const spacing = 14.0;
    for (double y = 6; y < size.height; y += spacing) {
      for (double x = 6; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}
