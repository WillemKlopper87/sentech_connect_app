import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Loads the order by id (from the route) via [OrderCubit]; never relies on
/// an object passed through navigation.
class ConfirmationPage extends StatelessWidget {
  const ConfirmationPage({
    super.key,
    required this.onDone,
    required this.onResume,
    this.onViewPasses,
  });

  final VoidCallback onDone;
  final void Function(Order order) onResume;
  final VoidCallback? onViewPasses;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderCubit, OrderState>(
      builder: (context, state) {
        if (state.status == OrderLoadStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final order = state.order;
        if (order == null) {
          return Scaffold(
            appBar: AppBar(),
            body: FailureView(
              failure: state.failure,
              onRetry: () => context.read<OrderCubit>().load(),
            ),
          );
        }
        if (order.status != OrderStatus.paid) {
          // Deep link / restored state pointing at an order that is not
          // complete: never claim "connected" for an unpaid order.
          final closed =
              order.status == OrderStatus.expired ||
              order.status == OrderStatus.cancelled;
          final message = switch (order.status) {
            OrderStatus.expired => context.l10n.orderExpiredBeforePayment(
              order.orderNumber,
            ),
            OrderStatus.cancelled => context.l10n.orderCancelled(
              order.orderNumber,
            ),
            _ => context.l10n.orderNotComplete(order.orderNumber),
          };
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.confirmationOrder)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    closed
                        ? ElevatedButton(
                            onPressed: onDone,
                            child: Text(context.l10n.confirmationBackToHome),
                          )
                        : ElevatedButton(
                            onPressed: () => onResume(order),
                            child: Text(
                              context.l10n.confirmationContinueYourOrder,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          );
        }
        return _ConfirmationView(
          order: order,
          onDone: onDone,
          onViewPasses: onViewPasses,
        );
      },
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({
    required this.order,
    required this.onDone,
    this.onViewPasses,
  });

  final Order order;
  final VoidCallback onDone;
  final VoidCallback? onViewPasses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8EAF3F).withValues(alpha: 0.16),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF6F9126),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                order.isHotspotPass
                    ? context.l10n.confirmationPassPaid
                    : context.l10n.confirmationReady,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.orderNumberLabel(order.orderNumber),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (order.isHotspotPass) ...[
                Text(
                  order.planName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.confirmationConnectHint,
                  textAlign: TextAlign.center,
                ),
              ] else
                const _Timeline(),
              const Spacer(),
              if (order.isHotspotPass && onViewPasses != null) ...[
                OutlinedButton(
                  onPressed: onViewPasses,
                  child: Text(context.l10n.confirmationViewPasses),
                ),
                const SizedBox(height: 10),
              ],
              ElevatedButton(
                onPressed: onDone,
                child: Text(
                  order.isHotspotPass
                      ? context.l10n.confirmationBackToHome
                      : context.l10n.confirmationTrackMyInstallation,
                ),
              ),
              const SizedBox(height: 8),
              if (!order.isHotspotPass)
                TextButton(
                  onPressed: onDone,
                  child: Text(context.l10n.confirmationBackToHome),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (
        context.l10n.confirmationCourierDispatched,
        context.l10n.confirmationRouterKitOnItsWay,
        true,
        false,
      ),
      (
        context.l10n.confirmationSelfInstall,
        context.l10n.confirmationFollowTheSetupGuideInThe,
        false,
        true,
      ),
      (
        context.l10n.confirmationActivation,
        context.l10n.confirmationSignalConfirmedServiceLive,
        false,
        false,
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _TimelineItem(
            title: items[i].$1,
            subtitle: items[i].$2,
            done: items[i].$3,
            current: items[i].$4,
            isLast: i == items.length - 1,
            theme: theme,
          ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.current,
    required this.isLast,
    required this.theme,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool current;
  final bool isLast;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final dotColor = done
        ? const Color(0xFF6F9126)
        : current
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
