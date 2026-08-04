import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sentech_connect_app/shared/widgets/viewfinder_corners.dart';

/// Real camera-based QR scanning via `mobile_scanner` (Module E,
/// docs/reconciled-spec.md). Reuses the same corner-bracket frame
/// established in the RICA capture screen so the scanning gesture feels
/// familiar rather than introducing a second, unrelated camera pattern.
///
/// This screen is kept alive inside the bottom-nav shell's IndexedStack
/// (so switching tabs doesn't lose scroll position etc. elsewhere), which
/// means it never gets a natural dispose/re-create when the user leaves
/// the Scan tab. Without explicit handling, the camera session keeps
/// running in the background and can end up in a stuck error state after
/// the app is backgrounded or another tab is used for a while — hence the
/// lifecycle + tab-visibility observers below, which explicitly stop the
/// camera when it isn't the visible, foregrounded tab and restart it when
/// it is.
class VoucherScannerPage extends StatefulWidget {
  const VoucherScannerPage({super.key});

  @override
  State<VoucherScannerPage> createState() => _VoucherScannerPageState();
}

class _VoucherScannerPageState extends State<VoucherScannerPage>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  bool _wasTabActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTabActive = TickerMode.valuesOf(context).enabled;
    if (isTabActive && !_wasTabActive) {
      _controller.start();
    } else if (!isTabActive && _wasTabActive) {
      _controller.stop();
    }
    _wasTabActive = isTabActive;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_wasTabActive) return; // don't fight the tab-visibility logic above
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    _redeem(code);
  }

  void _redeem(String code) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Voucher "$code" redeemed — data added to your account.'),
      ));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _handled = false);
    });
  }

  Future<void> _enterCodeManually() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter voucher code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. SEN-4XJ2-9KLM'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    _redeem(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan voucher'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off);
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(icon: const Icon(Icons.keyboard), onPressed: _enterCodeManually),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 320,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) => _CameraError(error: error),
                    ),
                    const ViewfinderCorners(color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Align the voucher's QR code within the frame",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            OutlinedButton(onPressed: _enterCodeManually, child: const Text('Enter code manually instead')),
          ],
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera permission denied — enable it in system settings, or enter the code manually below.',
      _ => 'Camera unavailable — enter the code manually below.',
    };
    return ColoredBox(
      color: const Color(0xFF0D2033),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
