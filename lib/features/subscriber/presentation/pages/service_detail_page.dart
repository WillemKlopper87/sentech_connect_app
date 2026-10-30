import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/service_detail_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_entries.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_actions_section.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_banner_view.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_card.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_status_chip.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// One service: plan facts, status, banners, and links to the other
/// subscriber screens that exist. Needs a [ServiceDetailCubit] above it.
/// Change plan (S6) and cancel at period end (S7) are in the actions area.
class ServiceDetailPage extends StatelessWidget {
  const ServiceDetailPage({super.key, this.plansRepository});

  /// Plans for the change plan picker; without it that action is not offered.
  final SubscriberPlansRepository? plansRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.serviceDetailTitle)),
      body: SafeArea(
        child: BlocBuilder<ServiceDetailCubit, ServiceDetailState>(
          builder: (context, state) {
            final service = state.service;
            if (service == null) {
              return state.status == ServiceDetailStatus.failure
                  ? FailureView(failure: state.failure, onRetry: context.read<ServiceDetailCubit>().load)
                  : const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () => context.read<ServiceDetailCubit>().load(keepVisible: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _Header(service, kycStatus: state.kycStatus),
                  ServiceActionsSection(service: service, plansRepository: plansRepository),
                  ..._links(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Links to the invoices and ID check screens, only those that exist.
  List<Widget> _links(BuildContext context) {
    final l10n = context.l10n;
    final entries = [for (final e in subscriberAccountEntries()) if (e.route != AppRoutes.services) e];
    if (entries.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                minTileHeight: 48,
                leading: Icon(entries[i].icon),
                title: Text(entries[i].label(l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(entries[i].route),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header(this.service, {this.kycStatus});

  final SubscriberService service;
  final KycStatus? kycStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final paidThrough = service.paidThrough;
    final endedOn = serviceEndedDay(service);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(service.planName, style: theme.textTheme.headlineSmall)),
            const SizedBox(width: 8),
            ServiceStatusChip(service.status),
          ],
        ),
        ServiceBannerView(service, kycStatus: kycStatus),
        const SizedBox(height: 16),
        _Fact(l10n.serviceFactType, serviceKindLabel(context, service.kind)),
        _Fact(l10n.serviceFactPrice, l10n.servicePricePerMonth(formatRands(service.priceCents))),
        _Fact(
          l10n.serviceFactSpeed,
          l10n.serviceSpeeds(formatMbps(service.downKbps), formatMbps(service.upKbps)),
        ),
        _Fact(l10n.serviceFactNumber, service.serviceNo),
        if (service.status == ServiceStatus.cancelled && endedOn != null)
          _Fact(l10n.serviceStatusCancelled, l10n.serviceEndedOn(formatApiDay(context, endedOn)))
        else if (paidThrough != null && service.status != ServiceStatus.pending)
          _Fact(l10n.serviceFactPaidThrough, formatApiDay(context, paidThrough)),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(flex: 3, child: Text(value, style: theme.textTheme.bodyMedium, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
