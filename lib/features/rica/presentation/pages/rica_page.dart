import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/consent_gate.dart';
import 'package:sentech_connect_app/features/rica/presentation/bloc/rica_cubit.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';
import 'package:sentech_connect_app/shared/widgets/viewfinder_corners.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';

class RicaPage extends StatelessWidget {
  const RicaPage({super.key, required this.onVerified});

  final VoidCallback onVerified;

  /// POPIA: a valid, versioned consent record must exist before any
  /// identity capture begins.
  Future<void> _start(BuildContext context) async {
    final cubit = context.read<RicaCubit>();
    if (!await ensureConsent(context, ConsentPurpose.ricaCapture)) return;
    await cubit.verify();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Identity capture: block screenshots / screen recording / recents preview.
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.ricaVerifyYourIdentity)),
        body: BlocConsumer<RicaCubit, RicaState>(
          listener: (context, state) {
            if (state.status == RicaStatus.verified) onVerified();
          },
          builder: (context, state) {
            final verifying = state.status == RicaStatus.verifying;
            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: List.generate(3, (i) {
                              final done = i < 2;
                              return Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: done
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.ricaLawNotice,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _Viewfinder(active: verifying),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (verifying) ...[
                                SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  verifying
                                      ? context.l10n.ricaLookAtTheCameraAndBlink
                                      : context
                                            .l10n
                                            .ricaReadyToVerifyWhenYouAre,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (state.status == RicaStatus.failure) ...[
                            const SizedBox(height: 12),
                            _FailureNotice(reason: state.failureReason),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            context.l10n.ricaPrivacyNotice,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                      onPressed: verifying ? null : () => _start(context),
                      child: verifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              state.status == RicaStatus.failure
                                  ? context.l10n.commonTryAgain
                                  : context.l10n.commonContinue,
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shown when verification did not complete. The order is kept (and not yet
/// charged), so the only ask of the customer is to try again — or come back
/// later via the dashboard.
class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.reason});

  final RicaFailureReason? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (reason) {
      RicaFailureReason.network => context.l10n.ricaWeCouldnTReachOurServers,
      RicaFailureReason.orderError => context.l10n.ricaWeCouldnTUpdateYourOrder,
      _ => context.l10n.ricaWeCouldnTVerifyYourIdentity,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: theme.colorScheme.error, width: 3),
        ),
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }
}

class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.active});

  final bool active;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        (context.watch<DataSaverCubit?>()?.state ?? false);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.active && !_reduceMotion && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if ((!widget.active || _reduceMotion) && _controller.isAnimating) {
      _controller.stop();
    }
  }

  // Only animate while verification is running, so an idle screen has no
  // perpetual ticker (saves battery, and lets tests settle).
  @override
  void didUpdateWidget(_Viewfinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _reduceMotion;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D2033), Color(0xFF14314D)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const ViewfinderCorners(),
            Container(
              width: 100,
              height: 124,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 2,
                ),
              ),
            ),
            if (widget.active && !reduceMotion)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Opacity(
                    opacity: 0.4 + 0.6 * _controller.value,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4FD3EA),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
