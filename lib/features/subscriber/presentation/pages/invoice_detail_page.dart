import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/dev_payment_simulator.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/fake_gateway_sheet.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_web_view_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/widgets/buy_now_sheet.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/invoice_detail_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/invoice_payment_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/invoice_presentation.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// One invoice: lines, VAT, status, and Pay for an open one. Needs an
/// [InvoiceDetailCubit] and an [InvoicePaymentCubit] above it.
class InvoiceDetailPage extends StatelessWidget {
  const InvoiceDetailPage({super.key, this.devSimulator});

  /// Local stack + debug only (ruling R-M4-13), same as order payments.
  final DevPaymentSimulator? devSimulator;

  Future<void> _handOff(BuildContext context, PaymentHandoff handoff) async {
    final cubit = context.read<InvoicePaymentCubit>();
    if (handoff.isDemo) {
      await cubit.handoffFinished();
      return;
    }
    final simulator = devSimulator;
    if (handoff.isFakeGateway && kDebugMode && simulator != null) {
      final approve = await showFakeGatewaySheet(context, handoff);
      if (approve != null) {
        await simulator.simulate(paymentId: handoff.paymentId, accepted: approve);
      }
      await cubit.handoffFinished();
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => PaymentWebViewPage(handoff: handoff)),
    );
    await cubit.handoffFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoiceDetailTitle)),
      body: BlocListener<InvoicePaymentCubit, InvoicePaymentState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == InvoicePaymentStatus.handoff && state.handoff != null) {
            _handOff(context, state.handoff!);
          }
          // The server now says paid (or closed): show the invoice as it is.
          if (state.status == InvoicePaymentStatus.paid || state.status == InvoicePaymentStatus.closed) {
            context.read<InvoiceDetailCubit>().refresh();
          }
        },
        child: BlocBuilder<InvoiceDetailCubit, InvoiceDetailState>(
          builder: (context, state) {
            final cubit = context.read<InvoiceDetailCubit>();
            switch (state.status) {
              case InvoiceDetailStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case InvoiceDetailStatus.failed:
                return FailureView(failure: state.failure, onRetry: cubit.load);
              case InvoiceDetailStatus.loaded:
                return _Loaded(invoice: state.invoice!, onRefresh: cubit.refresh);
            }
          },
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.invoice, required this.onRefresh});

  final SubscriberInvoice invoice;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(invoiceKindLabel(l10n, invoice.kind), style: theme.textTheme.titleLarge)),
                      InvoiceStatusChip(status: invoice.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invoice.invoiceNo,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.invoicePeriod(
                      formatInvoiceDate(context, invoice.periodStart),
                      formatInvoiceDate(context, invoice.periodEnd),
                    ),
                  ),
                  Text(l10n.invoiceIssuedOn(formatInvoiceDate(context, invoice.issueDate))),
                  if (invoice.isOpen)
                    Text(l10n.invoiceDueOn(formatInvoiceDate(context, invoice.dueDate)))
                  else if (invoice.paidAt case final paidAt?)
                    Text(l10n.invoicePaidOn(formatInvoiceInstant(context, paidAt))),
                  const SizedBox(height: 20),
                  if (invoice.lines.isNotEmpty) ...[
                    Text(l10n.invoiceLinesHeading, style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
                    const SizedBox(height: 8),
                    for (final line in invoice.lines) _LineRow(line: line),
                    const Divider(height: 24),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.invoiceTotal, style: theme.textTheme.titleMedium),
                      Text(formatRands(invoice.amountCents), style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.invoiceIncludesVat(formatRands(invoice.vatCents)),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (invoice.amountPaidCents > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.invoiceAmountPaid),
                        Text(formatRands(invoice.amountPaidCents)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          _PayArea(invoice: invoice),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final InvoiceLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.description),
                if (line.quantity != 1)
                  Text(
                    context.l10n.invoiceLineQuantity('${line.quantity}', formatRands(line.unitPriceCents)),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatRands(line.lineTotalCents)),
        ],
      ),
    );
  }
}

/// The bottom area: Pay for a payable invoice, otherwise what is true about it
/// or about the payment in progress.
class _PayArea extends StatelessWidget {
  const _PayArea({required this.invoice});

  final SubscriberInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<InvoicePaymentCubit, InvoicePaymentState>(
      builder: (context, pay) {
        final cubit = context.read<InvoicePaymentCubit>();
        Widget child;
        switch (pay.status) {
          case InvoicePaymentStatus.paid:
            child = _Notice(
              icon: Icons.check_circle_outline,
              title: l10n.invoicePaidTitle,
              text: invoicePaidOutcomeText(l10n, invoicePaidOutcome(pay.service)),
            );
          case InvoicePaymentStatus.confirming:
            child = Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.invoiceConfirming)),
              ],
            );
          case InvoicePaymentStatus.stillPending:
            child = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.invoiceStillPending),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: cubit.checkAgain, child: Text(l10n.paymentCheckAgain)),
                const SizedBox(height: 4),
                TextButton(onPressed: cubit.pay, child: Text(l10n.paymentPayAgain)),
              ],
            );
          case InvoicePaymentStatus.closed:
            if (pay.failure is CollectionExternalFailure) {
              child = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.invoiceCollectionExternal),
                  const SizedBox(height: 12),
                  Center(child: ProviderContactLinks(provider: providerContactOf(context))),
                ],
              );
            } else {
              child = Text(_text(context, pay.failure ?? const InvoiceNotPayableFailure()));
            }
          default:
            child = _idleArea(context, cubit, pay);
        }
        if (child is SizedBox) return child;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: DefaultTextStyle.merge(style: theme.textTheme.bodyMedium, child: child),
        );
      },
    );
  }

  Widget _idleArea(BuildContext context, InvoicePaymentCubit cubit, InvoicePaymentState pay) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final busy = pay.status == InvoicePaymentStatus.starting || pay.status == InvoicePaymentStatus.handoff;
    if (invoice.isPartPaid) return Text(l10n.invoicePartPaid);
    if (invoice.status == InvoiceStatus.voided) return Text(l10n.invoiceVoidNote);
    if (invoice.status == InvoiceStatus.writtenOff) return Text(l10n.invoiceWrittenOffNote);
    if (!invoice.isPayable) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pay.status == InvoicePaymentStatus.payFailed) ...[
          FailureView(failure: _displayFailure(context, pay.failure), compact: true, onRetry: cubit.pay),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.invoicePayOnSecurePage,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const ValueKey('pay-invoice'),
          onPressed: busy ? null : cubit.pay,
          child: busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l10n.invoicePayNow(formatRands(invoice.amountCents))),
        ),
      ],
    );
  }

  Failure? _displayFailure(BuildContext context, Failure? failure) {
    if (failure is ValidationFailure && failure.code == InvoicePaymentCubit.handoffInvalidCode) {
      return ValidationFailure(context.l10n.paymentHandoffInvalid, failure.code);
    }
    return failure;
  }

  String _text(BuildContext context, Failure failure) {
    final l10n = context.l10n;
    if (failure is NetworkFailure) return l10n.failureYouReOfflineCheckYourConnection;
    return typedFailureText(l10n, failure) ?? localizedFailureText(l10n, failure.message);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
