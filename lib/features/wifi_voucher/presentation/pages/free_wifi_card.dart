import 'package:sentech_connect_app/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/theme/app_colors.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/free_wifi_session.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/free_wifi_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/watch_ad_dialog.dart';

/// Sits at the top of the Vouchers category in the Shop tab. Shows either
/// an offer to watch an ad for free WiFi (capped at 3/day), or — while a
/// session is active — a live countdown of remaining time/data, which
/// stands in for what a real integration would poll from Sentech's BSS.
class FreeWifiCard extends StatefulWidget {
  const FreeWifiCard({super.key, required this.onFindHotspots});

  final VoidCallback onFindHotspots;

  @override
  State<FreeWifiCard> createState() => _FreeWifiCardState();
}

class _FreeWifiCardState extends State<FreeWifiCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        context.read<FreeWifiCubit>().checkExpiry();
        setState(
          () {},
        ); // re-read session.remaining/dataUsedMb for the countdown
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _watchAd(BuildContext context) async {
    final cubit = context.read<FreeWifiCubit>();
    cubit.beginWatchingAd();
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const WatchAdDialog(),
    );
    if (completed == true) {
      await cubit.completeAdAndClaim();
    } else {
      cubit.cancelWatchingAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FreeWifiCubit, FreeWifiState>(
      builder: (context, state) {
        if (state.status == FreeWifiStatus.loading) {
          return const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.darkBlue, AppColors.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: state.hasActiveSession
              ? _ActiveSession(
                  session: state.session!,
                  onFindHotspots: widget.onFindHotspots,
                )
              : _AdOffer(
                  adsRemainingToday: state.adsRemainingToday,
                  onWatchAd: state.canWatchAd ? () => _watchAd(context) : null,
                  onFindHotspots: widget.onFindHotspots,
                ),
        );
      },
    );
  }
}

/// White outline button on the brand gradient, sized for a Row or a Column.
final _outlinedOnGradient = OutlinedButton.styleFrom(
  foregroundColor: Colors.white,
  side: const BorderSide(color: Colors.white),
  minimumSize: const Size(0, 48),
);

class _AdOffer extends StatelessWidget {
  const _AdOffer({
    required this.adsRemainingToday,
    required this.onWatchAd,
    required this.onFindHotspots,
  });

  final int adsRemainingToday;
  final VoidCallback? onWatchAd;
  final VoidCallback onFindHotspots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.wifi_tethering, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.freeWifiFreeWifi,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          adsRemainingToday > 0
              ? context.l10n.freeWifiAdOffer(adsRemainingToday.toString())
              : context.l10n.freeWifiYouVeUsedAll3Free,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onWatchAd,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.darkBlue,
                  minimumSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: Text(context.l10n.freeWifiWatchAd),
              ),
            ),
            const SizedBox(width: 8),
            // AppTheme gives outlined buttons a full-width minimumSize
            // (Size.fromHeight), which is infinite inside a Row: without
            // Expanded and a finite minimum the whole row failed to lay out.
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onFindHotspots,
                style: _outlinedOnGradient,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(context.l10n.freeWifiHotspots),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActiveSession extends StatelessWidget {
  const _ActiveSession({required this.session, required this.onFindHotspots});

  final FreeWifiSession session;
  final VoidCallback onFindHotspots;

  @override
  Widget build(BuildContext context) {
    final remaining = session.remaining;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final dataRemaining = session.dataRemainingMb.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.wifi, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.freeWifiFreeWifiActive,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatChip(
                label: context.l10n.freeWifiTimeLeft,
                value: context.l10n.freeWifiTimeRemaining(
                  minutes.toString(),
                  seconds.toString().padLeft(2, '0'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                label: context.l10n.freeWifiDataLeft,
                value: context.l10n.sizeMegabytes(dataRemaining.toString()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.freeWifiUpdatesFromYourAccountAsYou,
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onFindHotspots,
          style: _outlinedOnGradient,
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(context.l10n.freeWifiFindHotspotsNearMe),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        // A darkening tint keeps white text above 4.5:1 on the whole gradient
        // (a white tint lightened the teal end below AA).
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
