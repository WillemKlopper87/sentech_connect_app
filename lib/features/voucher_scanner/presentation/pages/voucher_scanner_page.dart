import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/voucher_code_formatter.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
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
  const VoucherScannerPage({super.key, @visibleForTesting this.controller});

  /// Tests inject a camera controller; the app lets the page own one.
  final MobileScannerController? controller;

  @override
  Widget build(BuildContext context) {
    // Only the demo flavor's mock understands the old SEN-XXXX-XXXX codes;
    // prod accepts exactly what the server accepts.
    final isDemo = !locator.isRegistered<AppEnvironment>() || locator<AppEnvironment>().isDemo;
    return BlocProvider(
      create: (_) => VoucherCubit(locator(), allowDemoCodes: isDemo),
      child: _VoucherScannerView(controller: controller),
    );
  }
}

class _VoucherScannerView extends StatefulWidget {
  const _VoucherScannerView({this.controller});

  final MobileScannerController? controller;

  @override
  State<_VoucherScannerView> createState() => _VoucherScannerViewState();
}

class _VoucherScannerViewState extends State<_VoucherScannerView> with WidgetsBindingObserver {
  late final MobileScannerController _controller =
      widget.controller ?? MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _wasTabActive = false;

  /// What the customer last typed, kept on this screen only (never logged,
  /// never stored) so a refused code can be shown back and fixed. Null when
  /// the last submission came from the camera: a scanned payload is never
  /// echoed, so a hostile QR cannot put text in front of the customer.
  String? _typed;

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
      if (_scanning) _startCamera();
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
        if (_scanning) _startCamera();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller.stop();
    }
  }

  /// A start that races another start or a running camera is harmless
  /// ([isBenignCameraStartError]). Other camera errors reach the errorBuilder.
  Future<void> _startCamera() async {
    if (_controller.value.isStarting) return;
    try {
      await _controller.start();
    } on MobileScannerException catch (e) {
      if (!isBenignCameraStartError(e)) rethrow;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // The cubit ignores submissions unless it is in the scanning state, so a
    // QR that stays in frame cannot be re-submitted while a result is open.
    final cubit = context.read<VoucherCubit>();
    if (cubit.state.status == VoucherStatus.scanning) _typed = null;
    cubit.submit(capture.barcodes.firstOrNull?.rawValue);
  }

  Future<void> _onVoucherState(BuildContext context, VoucherState state) async {
    final cubit = context.read<VoucherCubit>();
    if (state.status == VoucherStatus.redeeming) {
      await _controller.stop();
    } else if (state.status == VoucherStatus.result) {
      final typed = _typed;
      final editAgain = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: state.failure == null,
        isScrollControlled: true,
        builder: (sheetContext) => VoucherResultSheet(
          state: state,
          enteredCode: state.outcome == VoucherOutcome.redeemed ? null : typed,
          onRetry: () {
            Navigator.pop(sheetContext);
            cubit.retry();
          },
          onTryAgain: () => Navigator.pop(sheetContext, true),
        ),
      );
      // Sheet closed. If "Try again" started a new redemption the cubit is
      // already past the result state; otherwise resume scanning.
      if (cubit.state.status == VoucherStatus.result) {
        // dismiss() emits the scanning state, and this listener's last
        // branch restarts the camera: no second start here.
        cubit.dismiss();
        _typed = null;
        if (editAgain == true && typed != null && mounted) {
          // Reopen the field with the code still in it, ready to fix.
          await _enterCodeManually(initial: typed);
        }
      }
    } else if (mounted && _wasTabActive) {
      await _startCamera();
    }
  }

  Future<void> _enterCodeManually({String initial = ''}) async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => _ManualEntryDialog(initial: initial),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    _typed = code.trim();
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
              OutlinedButton(onPressed: _enterCodeManually, child: const Text('Type the code instead')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Manual entry: formats as the customer types, pastes, and submits on the
/// keyboard's Done key as well as the Redeem button.
/// The camera is already starting or running: nothing to do, not an error.
bool isBenignCameraStartError(MobileScannerException e) =>
    e.errorCode == MobileScannerErrorCode.controllerInitializing ||
    e.errorCode == MobileScannerErrorCode.controllerAlreadyInitialized;

class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog({required this.initial});

  final String initial;

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || !mounted) return;
    _controller.value = const VoucherCodeFormatter().formatEditUpdate(
      _controller.value,
      TextEditingValue(text: text.trim(), selection: TextSelection.collapsed(offset: text.trim().length)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter voucher code'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        inputFormatters: const [VoucherCodeFormatter()],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'e.g. ABCD-2345-EFGH',
          helperText: '12 letters and numbers, on your voucher card',
          suffixIcon: IconButton(
            tooltip: 'Paste',
            icon: const Icon(Icons.content_paste),
            onPressed: _paste,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Redeem')),
      ],
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
