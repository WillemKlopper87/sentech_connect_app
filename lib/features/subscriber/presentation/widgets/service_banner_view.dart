import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_banner.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_entries.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Everything a service says about its own state beyond the status chip: the
/// activation or suspension banner, a scheduled cancellation and a scheduled
/// plan change. Renders nothing for a plain active service.
class ServiceBannerView extends StatelessWidget {
  const ServiceBannerView(this.service, {super.key, this.showActions = true});

  final SubscriberService service;

  /// False inside a tappable card, where a nested button would fight the tap.
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final banner = serviceBannerFor(service);
    final blocks = <Widget>[];
    if (banner != null) {
      final route = switch (banner.action) {
        ServiceBannerAction.openInvoices => AppRoutes.invoices,
        ServiceBannerAction.startIdCheck => AppRoutes.kyc,
        ServiceBannerAction.none => null,
      };
      final label = switch (banner.action) {
        ServiceBannerAction.openInvoices => l10n.serviceActionViewInvoices,
        ServiceBannerAction.startIdCheck => l10n.serviceActionIdCheck,
        ServiceBannerAction.none => '',
      };
      blocks.add(
        _Block(
          icon: banner.isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
          warning: banner.isWarning,
          text: _bannerText(context, banner.kind),
          // The button exists only once the target screen is registered.
          actionLabel: showActions && route != null && subscriberEntryRegistered(route) ? label : null,
          onAction: route == null ? null : () => context.push(route),
        ),
      );
    }
    final cancelOn = service.cancelEffectiveOn;
    if (cancelOn != null && service.status != ServiceStatus.cancelled) {
      blocks.add(
        _Block(
          icon: Icons.event_busy_outlined,
          warning: false,
          title: l10n.serviceCancelScheduledTitle,
          text: l10n.serviceEndsOn(formatApiDay(context, cancelOn)),
        ),
      );
    }
    final changeOn = service.planChangeOn;
    if (changeOn != null && service.status != ServiceStatus.cancelled) {
      final date = formatApiDay(context, changeOn);
      final plan = service.pendingPlanName;
      blocks.add(
        _Block(
          icon: Icons.swap_horiz,
          warning: false,
          text: plan == null ? l10n.servicePlanChangeScheduled(date) : l10n.servicePlanChangeOn(plan, date),
        ),
      );
    }
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final b in blocks) Padding(padding: const EdgeInsets.only(top: 10), child: b)],
    );
  }

  String _bannerText(BuildContext context, ServiceBannerKind kind) {
    final l10n = context.l10n;
    return switch (kind) {
      ServiceBannerKind.firstInvoiceUnpaid => l10n.serviceBannerFirstInvoiceUnpaid,
      ServiceBannerKind.kycRequired => l10n.serviceBannerKycRequired,
      ServiceBannerKind.awaitingInstallation => l10n.serviceBannerAwaitingInstallation,
      ServiceBannerKind.customerLinkRequired => l10n.serviceBannerCustomerLinkRequired,
      ServiceBannerKind.serviceContractRequired => l10n.serviceBannerContractRequired,
      ServiceBannerKind.activating => l10n.serviceBannerActivating,
      ServiceBannerKind.providerSettingUp => l10n.serviceBannerProviderSettingUp,
      ServiceBannerKind.suspendedNonPayment => l10n.serviceBannerSuspendedNonPayment,
      ServiceBannerKind.suspendedKyc => l10n.serviceBannerSuspendedKyc,
      ServiceBannerKind.suspendedByProvider => l10n.serviceBannerSuspendedProvider,
    };
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.warning,
    required this.text,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final bool warning;
  final String? title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = warning ? scheme.errorContainer : scheme.surfaceContainerHighest;
    final foreground = warning ? scheme.onErrorContainer : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: foreground)),
                Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: foreground)),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
