import 'package:flutter/material.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

/// The native splash (flutter_native_splash) shows the brand mark
/// instantly while the engine loads; this picks up where that leaves off
/// with a short fade/scale reveal of the full logo before handing off to
/// login — giving the launch a single continuous branded moment instead
/// of a jarring cut from native splash to first Flutter frame.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _controller = AnimationController(
      vsync: this,
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    Future.delayed(Duration(milliseconds: reduceMotion ? 200 : 1100), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: const SentechLogo(height: 56),
          ),
        ),
      ),
    );
  }
}
