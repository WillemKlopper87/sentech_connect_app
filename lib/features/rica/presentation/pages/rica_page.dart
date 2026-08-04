import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/rica/presentation/bloc/rica_cubit.dart';
import 'package:sentech_connect_app/shared/widgets/viewfinder_corners.dart';

class RicaPage extends StatelessWidget {
  const RicaPage({super.key, required this.onVerified});

  final VoidCallback onVerified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your identity')),
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
                                  color: done ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Required by South African law (RICA) before we can activate your service.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                verifying ? 'Look at the camera and blink slowly…' : 'Ready to verify when you are.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: state.consentGiven,
                              onChanged: (v) => context.read<RicaCubit>().toggleConsent(v ?? false),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'I consent to Sentech processing my ID document and biometric data under POPIA, for verification purposes only.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: (!state.consentGiven || verifying)
                        ? null
                        : () => context.read<RicaCubit>().verify(),
                    child: verifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.active});

  final bool active;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
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
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4FD3EA)),
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
