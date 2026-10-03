import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// A simulated rewarded-ad experience (countdown, skip disabled until
/// done) — there's no real AdMob account/unit ID configured yet, so this
/// stands in for one. Swapping in a real rewarded ad later means
/// replacing the body of this dialog; the surrounding 3/day cap and
/// session-granting logic (FreeWifiCubit) doesn't need to change.
class WatchAdDialog extends StatefulWidget {
  const WatchAdDialog({super.key});

  @override
  State<WatchAdDialog> createState() => _WatchAdDialogState();
}

class _WatchAdDialogState extends State<WatchAdDialog>
    with SingleTickerProviderStateMixin {
  static const _adDuration = Duration(seconds: 6);
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _adDuration)
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          Navigator.of(context).pop(true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog.fullscreen(
        backgroundColor: const Color(0xFF0D2033),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 72,
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.freeWifiYourFreeWifiAdIsPlaying,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.freeWifiSimulatedNoSkipUntilItFinishes,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => LinearProgressIndicator(
                    value: _controller.value,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    color: const Color(0xFF4FD3EA),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
