import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/home/home_overview_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_card.dart';
import 'package:sentech_connect_app/features/subscriber/subscriber_gate.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// True when the Home dashboard should show subscriber content: the provider
/// has the `subscriber_billing` module on. With no tenant above (tests) or the
/// module off it is false and the dashboard is the pass-only one.
bool homeSubscriberOn(BuildContext context) =>
    context.select<TenantCubit?, bool>(
      (c) => c != null && subscriberBillingOn(c.state),
    );

/// The subscriber part of Home, between the pass card and the shortcuts:
/// service cards, open invoices with Pay, and the ID check status. Needs a
/// [HomeOverviewCubit] above it. Absent (and nothing is requested) when the
/// module is off; absent while there is no account. Each source shows its own
/// loading and failure, so one failing never hides the others.
class HomeSubscriberSection extends StatefulWidget {
  const HomeSubscriberSection({super.key});

  @override
  State<HomeSubscriberSection> createState() => _HomeSubscriberSectionState();
}

class _HomeSubscriberSectionState extends State<HomeSubscriberSection> {
  @override
  void initState() {
    super.initState();
    context.read<HomeOverviewCubit>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<HomeOverviewCubit, HomeOverviewState>(
      builder: (context, state) {
        final cubit = context.read<HomeOverviewCubit>();
        final services = state.services;
        final hasServices = state.hasServices;
        final children = <Widget>[];

        // Services.
        switch (services.load) {
          case HomeLoad.loading:
            children.add(const _LoadingCard(key: Key('home-services-loading')));
          case HomeLoad.failure:
            children.add(
              _Boxed(
                key: const Key('home-services-failure'),
                child: FailureView(
                  failure: services.failure,
                  compact: true,
                  onRetry: cubit.loadServices,
                ),
              ),
            );
          case HomeLoad.loaded:
            if (hasServices) {
              children.add(
                Text(
                  l10n.homeSubscriberHeading,
                  style: theme.textTheme.titleMedium,
                ),
              );
              for (final s in services.data!) {
                children.add(
                  ServiceCard(
                    service: s,
                    kycStatus: state.kyc.data?.status,
                    onTap: () => context.push(AppRoutes.serviceFor(s.id)),
                  ),
                );
              }
            }
        }

        // Open invoices: shown whenever there are some (an account can owe
        // money before a service is active). A failure has its own retry.
        final invoices = state.openInvoices;
        switch (invoices.load) {
          case HomeLoad.loading:
            break;
          case HomeLoad.failure:
            children.add(
              _Boxed(
                key: const Key('home-invoices-failure'),
                child: FailureView(
                  failure: invoices.failure,
                  compact: true,
                  onRetry: cubit.loadInvoices,
                ),
              ),
            );
          case HomeLoad.loaded:
            final open = invoices.data ?? const <SubscriberInvoice>[];
            for (final i in open.take(3)) {
              children.add(_InvoiceStrip(invoice: i));
            }
            if (open.length > 3) {
              children.add(
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.invoices),
                    child: Text(l10n.homeInvoicesViewAll),
                  ),
                ),
              );
            }
        }

        // ID check: only for a customer with an account, and only when there
        // is something to do or wait for.
        final kyc = state.kyc;
        final noAccount = kyc.failure is SubscriberNotFoundFailure;
        if (!noAccount &&
            (hasServices ||
                (kyc.load == HomeLoad.loaded && kyc.data != null))) {
          switch (kyc.load) {
            case HomeLoad.loading:
              break;
            case HomeLoad.failure:
              children.add(
                _Boxed(
                  key: const Key('home-kyc-failure'),
                  child: FailureView(
                    failure: kyc.failure,
                    compact: true,
                    onRetry: cubit.loadKyc,
                  ),
                ),
              );
            case HomeLoad.loaded:
              final title = switch (kyc.data?.status) {
                null => l10n.kycNoneTitle,
                KycStatus.pending => l10n.kycPendingTitle,
                KycStatus.rejected => l10n.kycRejectedTitle,
                KycStatus.verified => null,
              };
              if (title != null) children.add(_KycStrip(title: title));
          }
        }

        if (children.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                children[i],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Boxed extends StatelessWidget {
  const _Boxed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({super.key});

  @override
  Widget build(BuildContext context) => const _Boxed(
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      ),
    ),
  );
}

class _InvoiceStrip extends StatelessWidget {
  const _InvoiceStrip({required this.invoice});

  final SubscriberInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final amount = formatRands(invoice.amountCents - invoice.amountPaidCents);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('home-invoice-${invoice.id}'),
        onTap: () => context.push(AppRoutes.invoiceFor(invoice.id)),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.homeInvoiceDue(
                    amount,
                    formatApiDay(context, invoice.dueDate),
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (invoice.isPayable)
                Text(l10n.homeInvoicePay, style: theme.textTheme.labelLarge),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycStrip extends StatelessWidget {
  const _KycStrip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('home-kyc-strip'),
        onTap: () => context.push(AppRoutes.kyc),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
