import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/change_plan_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/service_detail_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/change_plan_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/cancel_service_dialog.dart';
import 'package:sentech_connect_app/features/subscriber/subscriber_gate.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// "Change plan" and "Cancel service" on the service detail screen, with the
/// explanations that stand in for an action the service cannot take. Needs a
/// [ServiceDetailCubit] above it. Everything is hidden when the
/// `subscriber_billing` module is off (the routes redirect in that case too;
/// this covers a config that flips while the screen is open).
class ServiceActionsSection extends StatelessWidget {
  const ServiceActionsSection({super.key, required this.service, this.plansRepository});

  final SubscriberService service;

  /// Where the plan picker gets its plans. Without it the Change plan action
  /// is not offered.
  final SubscriberPlansRepository? plansRepository;

  @override
  Widget build(BuildContext context) {
    TenantCubit? tenant;
    try {
      tenant = context.read<TenantCubit>();
    } on ProviderNotFoundException {
      tenant = null;
    }
    if (tenant == null) return _content(context);
    return BlocBuilder<TenantCubit, TenantState>(
      bloc: tenant,
      builder: (context, state) => subscriberBillingOn(state) ? _content(context) : const SizedBox.shrink(),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final change = plansRepository == null ? ChangePlanAvailability.hidden : changePlanAvailability(service);
    final cancel = cancelAvailability(service);
    final children = <Widget>[
      switch (change) {
        ChangePlanAvailability.available => OutlinedButton(
          key: const Key('service-change-plan'),
          onPressed: () => _changePlan(context),
          child: Text(l10n.serviceChangePlanAction),
        ),
        ChangePlanAvailability.blockedCancelling => Text(l10n.serviceChangePlanBlockedCancelling, key: const Key('change-blocked'), style: muted),
        ChangePlanAvailability.blockedInactive => Text(l10n.serviceChangePlanBlockedInactive, key: const Key('change-blocked'), style: muted),
        ChangePlanAvailability.hidden => const SizedBox.shrink(),
      },
      switch (cancel) {
        CancelAvailability.available => TextButton(
          key: const Key('service-cancel'),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: () => _cancel(context),
          child: Text(l10n.serviceCancelAction),
        ),
        CancelAvailability.contactSupport => Text(l10n.serviceCancelPendingContact, key: const Key('cancel-contact-support'), style: muted),
        CancelAvailability.hidden => const SizedBox.shrink(),
      },
      // A scheduled cancellation cannot be withdrawn: the platform has no
      // route for it, so the screen says so instead of offering an undo.
      if (service.isCancellationScheduled && service.status != ServiceStatus.cancelled)
        Text(l10n.serviceCancelNoUndo, key: const Key('cancel-no-undo'), style: muted),
    ].where((w) => w is! SizedBox).toList();
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (var i = 0; i < children.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 8), child: children[i])],
      ),
    );
  }

  Future<void> _changePlan(BuildContext context) async {
    final detail = context.read<ServiceDetailCubit>();
    final plans = plansRepository!;
    final exit = await Navigator.of(context).push<ChangePlanExit>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => ChangePlanCubit(detail.repository, plans, service),
          child: const ChangePlanPage(),
        ),
      ),
    );
    // Whatever happened (a refusal can mean the service moved on), read it again.
    unawaited(detail.load(keepVisible: true));
    final route = exit?.route;
    if (route != null && context.mounted) unawaited(context.push<void>(route));
  }

  Future<void> _cancel(BuildContext context) async {
    final detail = context.read<ServiceDetailCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final updated = await showCancelServiceDialog(context, repository: detail.repository, service: service);
    if (updated != null) {
      detail.applyService(updated);
      final on = updated.cancelEffectiveOn;
      if (on != null && context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.cancelDone(formatApiDay(context, on)))));
      }
    }
    unawaited(detail.load(keepVisible: true));
  }
}
