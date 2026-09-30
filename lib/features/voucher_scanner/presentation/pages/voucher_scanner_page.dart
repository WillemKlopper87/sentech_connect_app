import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/bloc/voucher_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_result_sheet.dart';
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
class VoucherScannerPage extends StatelessWidget {
  const VoucherScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => VoucherCubit(locator()), child: const _VoucherScannerView());
  }
}

class _VoucherScannerView extends StatefulWidget {
  const _VoucherScannerView();

  @override
  State<_VoucherScannerView> createState() => _VoucherScannerViewState();
}

class _VoucherScannerViewState extends State<_VoucherScannerView> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _wasTabActive = false;

  /// Scanning is paused from the moment a code is submitted until its
  /// result sheet is dismissed (see [VoucherCubit]).
  bool get _scanning => context.read<VoucherCubit>().state.status == VoucherStatus.scanning;

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
      if (_scanning) _controller.start();
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
        if (_scanning) _controller.start();
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
    // The cubit ignores submissions unless it is in the scanning state, so a
    // QR that stays in frame cannot be re-submitted while a result is open.
    context.read<VoucherCubit>().submit(capture.barcodes.firstOrNull?.rawValue);
  }

  Future<void> _onVoucherState(BuildContext context, VoucherState state) async {
    final cubit = context.read<VoucherCubit>();
    if (state.status == VoucherStatus.redeeming) {
      await _controller.stop();
    } else if (state.status == VoucherStatus.result) {
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: state.failure == null,
        isScrollControlled: true,
        builder: (sheetContext) => VoucherResultSheet(
          state: state,
          onRetry: () {
            Navigator.pop(sheetContext);
            cubit.retry();
          },
        ),
      );
      // Sheet closed. If "Try again" started a new redemption the cubit is
      // already past the result state; otherwise resume scanning.
      if (cubit.state.status == VoucherStatus.result) {
        cubit.dismiss();
        if (mounted && _wasTabActive) await _controller.start();
      }
    } else if (mounted && _wasTabActive) {
      await _controller.start();
    }
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
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Redeem')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    context.read<VoucherCubit>().submit(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<VoucherCubit, VoucherState>(
      listener: _onVoucherState,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan voucher'),
          actions: [
            IconButton(
              tooltip: context.l10n.a11yToggleTorch,
              icon: ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, state, child) {
                  return Icon(state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off);
                },
              ),
              onPressed: () => _controller.toggleTorch(),
            ),
            IconButton(
              tooltip: context.l10n.a11yEnterCode,
              icon: const Icon(Icons.keyboard),
              onPressed: _enterCodeManually,
            ),
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
                        errorBuilder: (context, error) => _CameraError(error: error),
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
