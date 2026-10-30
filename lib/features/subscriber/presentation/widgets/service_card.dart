import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_banner_view.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_status_chip.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// A service as a card: plan, status, price, how long it is paid for, and its
/// banner. Used by the services list; reusable on Home.
class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, this.onTap, this.kycStatus});

  final SubscriberService service;

  /// The customer's ID check status when known (changes the banner text).
  final KycStatus? kycStatus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final paidThrough = service.paidThrough;
    final endedOn = serviceEndedDay(service);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(service.planName, style: theme.textTheme.titleMedium)),
                  const SizedBox(width: 8),
                  ServiceStatusChip(service.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${serviceKindLabel(context, service.kind)} · ${l10n.servicePricePerMonth(formatRands(service.priceCents))}',
                style: muted,
              ),
              if (service.status == ServiceStatus.cancelled && endedOn != null)
                Text(l10n.serviceEndedOn(formatApiDay(context, endedOn)), style: muted)
              else if (paidThrough != null && service.status != ServiceStatus.pending)
                Text(l10n.servicePaidUntil(formatApiDay(context, paidThrough)), style: muted),
              ServiceBannerView(service, showActions: false, kycStatus: kycStatus),
            ],
          ),
        ),
      ),
    );
  }
}

/// The calendar day a cancelled service ended: the scheduled day when there
/// was one, else the day it was cancelled.
DateTime? serviceEndedDay(SubscriberService s) {
  final scheduled = s.cancelEffectiveOn;
  if (scheduled != null) return scheduled;
  final at = s.cancelledAt?.toUtc();
  return at == null ? null : DateTime.utc(at.year, at.month, at.day);
}
