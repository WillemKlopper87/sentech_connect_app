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
    final isDemo =
        !locator.isRegistered<AppEnvironment>() ||
        locator<AppEnvironment>().isDemo;
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

class _VoucherScannerViewState extends State<_VoucherScannerView>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller =
      widget.controller ??
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _wasTabActive = false;
  bool _cameraPaused = false;
  bool _entryOpen = false;
  TextEditingController? _entryController;
  ModalRoute<dynamic>? _entryRoute;
  ModalRoute<dynamic>? _resultRoute;
  int _resultVersion = 0;

  /// What the customer last typed, kept on this screen only (never logged,
  /// never stored) so a refused code can be shown back and fixed. Null when
  /// the last submission came from the camera: a scanned payload is never
  /// echoed, so a hostile QR cannot put text in front of the customer.
  String? _typed;

  /// Scanning is paused from the moment a code is submitted until its
  /// result sheet is dismissed (see [VoucherCubit]).
  bool get _scanning =>
      context.read<VoucherCubit>().state.status == VoucherStatus.scanning;

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
      _pauseCamera();
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
        _pauseCamera();
    }
  }

  /// A start that races another start or a running camera is harmless
  /// ([isBenignCameraStartError]). Other camera errors reach the errorBuilder.
  Future<void> _startCamera() async {
    if (!_scanning || _controller.value.isStarting) return;
    _cameraPaused = false;
    try {
      await _controller.start();
    } on MobileScannerException catch (e) {
      if (!isBenignCameraStartError(e)) rethrow;
    }
  }

  Future<void> _pauseCamera() async {
    if (_cameraPaused) return;
    _cameraPaused = true;
    await _controller.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typed = null;
    // Popup routes can outlive their underlying page during auth redirects.
    // Erase the field immediately and remove only our own routes afterward.
    _entryController?.clear();
    for (final route in [_entryRoute, _resultRoute]) {
      final navigator = route?.navigator;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route != null && route.isActive && navigator?.mounted == true) {
          navigator!.removeRoute(route);
        }
      });
    }
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // The cubit ignores submissions unless it is in the scanning state, so a
    // QR that stays in frame cannot be re-submitted while a result is open.
    final cubit = context.read<VoucherCubit>();
    if (cubit.state.status != VoucherStatus.scanning) return;
    _typed = null;
    cubit.submit(capture.barcodes.firstOrNull?.rawValue);
  }

  Future<void> _onVoucherState(BuildContext context, VoucherState state) async {
    final cubit = context.read<VoucherCubit>();
    if (state.status == VoucherStatus.redeeming ||
        state.status == VoucherStatus.entering) {
      await _pauseCamera();
    } else if (state.status == VoucherStatus.result) {
      await _pauseCamera();
      // Camera stop can outlast this result. A newer entry/result must not
      // be covered by a sheet from the earlier captured state.
      if (!context.mounted ||
          cubit.isClosed ||
          !identical(cubit.state, state)) {
        return;
      }
      final version = ++_resultVersion;
      var retrying = false;
      final typed = _typed;
      final editAgain = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: state.failure == null,
        isScrollControlled: true,
        builder: (sheetContext) {
          _resultRoute = ModalRoute.of(sheetContext);
          return VoucherResultSheet(
            state: state,
            enteredCode: state.outcome == VoucherOutcome.redeemed
                ? null
                : typed,
            onRetry: () {
              if (retrying) return;
              retrying = true;
              Navigator.pop(sheetContext);
              cubit.retry();
            },
            onTryAgain: () => Navigator.pop(sheetContext, true),
          );
        },
      );
      if (version == _resultVersion) _resultRoute = null;
      if (!mounted || cubit.isClosed) return;
      if (retrying) return;
      // Sheet closed. If "Try again" started a new redemption the cubit is
      // already past the result state; otherwise resume scanning.
      if (cubit.state.status == VoucherStatus.result) {
        // dismiss() emits the scanning state, and this listener's last
        // branch restarts the camera: no second start here.
        if (editAgain == true && mounted) {
          // Reopen the field with the code still in it, ready to fix.
          await _enterCodeManually(initial: typed ?? '');
        } else {
          _typed = null;
          cubit.dismiss();
        }
      }
    } else if (mounted && _wasTabActive) {
      await _startCamera();
    }
  }

  Future<void> _enterCodeManually({String initial = ''}) async {
    final cubit = context.read<VoucherCubit>();
    if (_entryOpen || !cubit.beginEntry()) return;
    _entryOpen = true;
    await _pauseCamera();
    if (!mounted) return;
    final controller = TextEditingController(text: initial);
    _entryController = controller;
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        _entryRoute = ModalRoute.of(sheetContext);
        return _ManualEntrySheet(controller: controller);
      },
    );
    _entryOpen = false;
    _entryRoute = null;
    _entryController = null;
    controller.clear();
    if (!mounted || cubit.isClosed) return;
    if (code == null || code.trim().isEmpty) {
      _typed = null;
      cubit.dismiss();
      return;
    }
    _typed = code.trim();
    cubit.submit(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<VoucherCubit, VoucherState>(
      listener: _onVoucherState,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.scanScanVoucher),
          actions: [
            IconButton(
              tooltip: context.l10n.a11yToggleTorch,
              icon: ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, state, child) {
                  return Icon(
                    state.torchState == TorchState.on
                        ? Icons.flash_on
                        : Icons.flash_off,
                  );
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
        body: SingleChildScrollView(
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
                        errorBuilder: (context, error) =>
                            _CameraError(error: error),
                      ),
                      const ViewfinderCorners(color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.scanAlignTheVoucherSQrCode,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 15),
                ),
                onPressed: _enterCodeManually,
                child: Text(context.l10n.scanTypeTheCodeInstead),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The camera is already starting or running: nothing to do, not an error.
bool isBenignCameraStartError(MobileScannerException e) =>
    e.errorCode == MobileScannerErrorCode.controllerInitializing ||
    e.errorCode == MobileScannerErrorCode.controllerAlreadyInitialized;

/// Formats customer input and reads the clipboard only after tapping Paste.
class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet({required this.controller});

  final TextEditingController controller;

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  TextEditingController get _controller => widget.controller;
  bool _submitted = false;
  bool _pasting = false;

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    _submitted = true;
    Navigator.pop(context, _controller.text);
  }

  Future<void> _paste() async {
    if (_pasting || _submitted) return;
    _pasting = true;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    _pasting = false;
    if (text == null ||
        !mounted ||
        _submitted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _controller.value = const VoucherCodeFormatter().formatEditUpdate(
      _controller.value,
      TextEditingValue(
        text: text.trim(),
        selection: TextSelection.collapsed(offset: text.trim().length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.scanEnterVoucherCode,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              style: Theme.of(context).textTheme.bodyLarge,
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: const [VoucherCodeFormatter()],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: context.l10n.scanEGAbcd2345Efgh,
                helperText: context.l10n.scanVoucherCodeHelper,
                helperMaxLines: 4,
                helperStyle: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              style: OutlinedButton.styleFrom(textStyle: buttonText),
              label: Text(context.l10n.scanPaste),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(textStyle: buttonText),
              child: Text(context.l10n.scanRedeem),
            ),
            TextButton(
              style: TextButton.styleFrom(textStyle: buttonText),
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
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
        context.l10n.scanEnableTheCameraInSystemSettings,
      _ => context.l10n.scanCameraUnavailablePleaseTypeTheCode,
    };
    return ColoredBox(
      color: const Color(0xFF0D2033),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
