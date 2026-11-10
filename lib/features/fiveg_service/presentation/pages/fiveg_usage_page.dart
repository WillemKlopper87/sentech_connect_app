import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/repositories/fiveg_repository.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/usage_levels.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/bloc/fiveg_usage_cubit.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/widgets/cycle_summary.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/widgets/unlock_confirm_sheet.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/widgets/unlock_offers_section.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/widgets/usage_meter.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/widgets/usage_state_banner.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// One service's data allowance: the meter, the state, the reset day, the
/// paid unlocks. Needs a [FiveGUsageCubit] above it. Buying an unlock opens
/// the confirmation sheet; the order then goes to the shared payment screen
/// through [onOpenPayment].
class FiveGUsagePage extends StatelessWidget {
  const FiveGUsagePage({
    super.key,
    required this.serviceId,
    required this.repository,
    required this.onOpenPayment,
    this.now = DateTime.now,
  });

  final String serviceId;
  final FiveGRepository repository;

  /// Called with the unpaid unlock order id to pay it.
  final void Function(String orderId) onOpenPayment;

  /// The current instant (tests pin it; the app passes the platform clock).
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.fivegTitle)),
      body: SafeArea(
        child: BlocBuilder<FiveGUsageCubit, FiveGUsageState>(
          builder: (context, state) => switch (state.status) {
            FiveGUsageStatus.loading => const Center(child: CircularProgressIndicator()),
            FiveGUsageStatus.unavailable => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.l10n.fivegUnavailable, textAlign: TextAlign.center),
              ),
            ),
            FiveGUsageStatus.failure => FailureView(
              failure: state.failure,
              onRetry: () => context.read<FiveGUsageCubit>().refresh(),
            ),
            FiveGUsageStatus.loaded => _Loaded(
              usage: state.usage!,
              restoringTimedOut: state.restoringTimedOut,
              serviceId: serviceId,
              repository: repository,
              onOpenPayment: onOpenPayment,
              now: now,
            ),
          },
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.usage,
    required this.restoringTimedOut,
    required this.serviceId,
    required this.repository,
    required this.onOpenPayment,
    required this.now,
  });

  final FiveGUsage usage;
  final bool restoringTimedOut;
  final String serviceId;
  final FiveGRepository repository;
  final void Function(String orderId) onOpenPayment;
  final DateTime Function() now;

  Future<void> _buy(BuildContext context, UnlockOffer offer) async {
    final orderId = await showUnlockConfirmSheet(
      context,
      repository: repository,
      serviceId: serviceId,
      offer: offer,
    );
    if (orderId != null && context.mounted) onOpenPayment(orderId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final headline = headlineFor(usage.state, restoring: usage.restoring);
    final warning = usage.state == UsageState.normal ? warningFor(usage.usedPercent) : UsageWarning.none;
    final cap = usage.effectiveCapMb;
    final counted = usage.countedUsageMb;
    final percent = usage.usedPercent;
    final pending = usage.pendingUnlock;
    return RefreshIndicator(
      onRefresh: () => context.read<FiveGUsageCubit>().refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          UsageHeadlineBanner(headline: headline, restoringTimedOut: restoringTimedOut),
          if (warning != UsageWarning.none) ...[
            const SizedBox(height: 12),
            UsageWarningBanner(warning: warning),
          ],
          const SizedBox(height: 24),
          if (usage.isCapped && cap != null && counted != null && percent != null) ...[
            Text(l10n.fivegAllowanceHeading, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            UsageMeter(usedMb: counted, capMb: cap, usedPercent: percent),
            const SizedBox(height: 16),
          ] else ...[
            Text(l10n.fivegFairUseHeading, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
          ],
          CycleSummary(cycleEnd: usage.cycleEnd, today: now(), rolloverMb: usage.rolloverMb),
          if (pending != null) ...[
            const SizedBox(height: 24),
            PendingUnlockCard(onContinue: () => onOpenPayment(pending.orderId)),
          ],
          if (usage.isCapped) ...[
            const SizedBox(height: 28),
            UnlockOffersSection(
              offers: usage.offers,
              onBuy: (offer) => _buy(context, offer),
            ),
          ],
        ],
      ),
    );
  }
}
