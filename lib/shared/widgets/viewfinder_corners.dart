import 'package:flutter/material.dart';

/// The four L-shaped corner brackets used on both the RICA capture and
/// voucher-scanner viewfinders in the HTML concept walkthrough — reusing
/// this widget in both places keeps that visual language consistent, the
/// same way the real screens are meant to feel like the same capture
/// pattern reused for two different purposes.
class ViewfinderCorners extends StatelessWidget {
  const ViewfinderCorners({super.key, this.color = const Color(0xFF4FD3EA), this.inset = 10, this.length = 16});

  final Color color;
  final double inset;
  final double length;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CornersPainter(color: color, inset: inset, length: length),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter({required this.color, required this.inset, required this.length});

  final Color color;
  final double inset;
  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(dx * length, 0), paint);
      canvas.drawLine(origin, origin.translate(0, dy * length), paint);
    }

    corner(Offset(inset, inset), 1, 1); // top-left
    corner(Offset(size.width - inset, inset), -1, 1); // top-right
    corner(Offset(inset, size.height - inset), 1, -1); // bottom-left
    corner(Offset(size.width - inset, size.height - inset), -1, -1); // bottom-right
  }

  @override
  bool shouldRepaint(covariant _CornersPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.inset != inset || oldDelegate.length != length;
}
