import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/dev_payment_simulator.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/fake_gateway_sheet.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_web_view_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/widgets/buy_now_sheet.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Pay for an order on the gateway's hosted page, then wait for the server
/// to confirm. Reached from checkout, RICA success or the dashboard banner.
class PaymentPage extends StatelessWidget {
  const PaymentPage({
    super.key,
    required this.onPaid,
    required this.onNeedsVerification,
    required this.onClosed,
    this.showIdentityVerified = true,
    this.showDemoMethods = false,
    this.devSimulator,
  });

  final void Function(Order order) onPaid;
  final void Function(Order order) onNeedsVerification;
  final VoidCallback onClosed;

  /// "Identity verified" header (only when the RICA flag is on). It shows
  /// only for an order whose RICA check was completed
  /// ([Order.identityVerified]); WiFi passes and vouchers never show it.
  final bool showIdentityVerified;

  /// The demo catalog offers vouchers; production methods are gateway-owned.
  final bool showDemoMethods;

  /// Local stack + debug only (ruling R-M4-13).
  final DevPaymentSimulator? devSimulator;

  Failure? _displayFailure(AppLocalizations l10n, Failure? failure) {
    if (failure is ValidationFailure &&
        failure.code == PaymentCubit.handoffInvalidCode) {
      return ValidationFailure(l10n.paymentHandoffInvalid, failure.code);
    }
    return failure;
  }

  Future<void> _handOff(BuildContext context, PaymentHandoff handoff) async {
    final cubit = context.read<PaymentCubit>();
    if (handoff.isDemo) {
      await cubit.handoffFinished();
      return;
    }
    final simulator = devSimulator;
    if (handoff.isFakeGateway && kDebugMode && simulator != null) {
      final approve = await showFakeGatewaySheet(context, handoff);
      if (approve != null) {
        await simulator.simulate(
          paymentId: handoff.paymentId,
          accepted: approve,
        );
      }
      await cubit.handoffFinished();
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaymentWebViewPage(handoff: handoff),
      ),
    );
    await cubit.handoffFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.paymentPayment)),
      body: BlocConsumer<PaymentCubit, PaymentState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          final order = state.order;
          if (state.status == PaymentStatus.handoff && state.handoff != null) {
            _handOff(context, state.handoff!);
          }
          if (order == null) return;
          if (state.status == PaymentStatus.paid) onPaid(order);
          if (state.status == PaymentStatus.needsVerification) {
            onNeedsVerification(order);
          }
        },
        builder: (context, state) {
          final cubit = context.read<PaymentCubit>();
          final theme = Theme.of(context);
          final l10n = AppLocalizations.of(context);
          switch (state.status) {
            case PaymentStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case PaymentStatus.loadFailed:
              return FailureView(failure: state.failure, onRetry: cubit.load);
            case PaymentStatus.closed:
              if (state.failure is CollectionExternalFailure) {
                final provider = providerContactOf(context);
                return _Message(
                  text: l10n.paymentBuyFromProvider(provider.name),
                  action: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProviderContactLinks(provider: provider),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: onClosed,
                        child: Text(l10n.paymentBackToDashboard),
                      ),
                    ],
                  ),
                );
              }
              return _Message(
                text: state.order?.status == OrderStatus.cancelled
                    ? l10n.paymentClosedCancelled
                    : l10n.paymentClosedExpired,
                action: FilledButton(
                  onPressed: onClosed,
                  child: Text(l10n.paymentBackToDashboard),
                ),
              );
            case PaymentStatus.confirming:
              return _Message(
                text: context.l10n.paymentConfirmingYourPaymentThisCanTake,
                action: CircularProgressIndicator(),
              );
            case PaymentStatus.stillPending:
              return _Message(
                text: l10n.paymentStillPending,
                action: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: cubit.checkAgain,
                      child: Text(l10n.paymentCheckAgain),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.paymentPayAgainHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: cubit.pay,
                      child: Text(l10n.paymentPayAgain),
                    ),
                  ],
                ),
              );
            default:
              break;
          }
          final order = state.order;
          if (order == null) return const SizedBox.shrink();
          final busy =
              state.status == PaymentStatus.starting ||
              state.status == PaymentStatus.handoff;
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OrderCard(
                          order: order,
                          // Only when RICA was actually completed for
                          // this order: WiFi passes and vouchers never.
                          showIdentityVerified:
                              showIdentityVerified && order.identityVerified,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.l10n.paymentChooseHowToPayOnThe,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        if (showDemoMethods) ...[
                          const SizedBox(height: 18),
                          const PaymentMethodsRow(showCashVoucher: true),
                        ],
                        if (state.status == PaymentStatus.payFailed) ...[
                          const SizedBox(height: 16),
                          FailureView(
                            failure: _displayFailure(l10n, state.failure),
                            compact: true,
                            onRetry: cubit.pay,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.l10n.paymentPayOnASecurePaymentPage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: busy ? null : cubit.pay,
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                context.l10n.paymentPaySecurely(
                                  context.l10n.priceInclVat(
                                    formatRands(order.totalCents),
                                  ),
                                ),
                              ),
                      ),
                    ],
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

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Center(child: action),
        ],
      ),
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.showIdentityVerified});

  final Order order;
  final bool showIdentityVerified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = showIdentityVerified
        ? context.l10n.paymentIdentityVerified
        : order.isHotspotPass
        ? context.l10n.paymentWifiPassOrder
        : context.l10n.paymentYourOrder;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (showIdentityVerified) ...[
                const Icon(Icons.verified, size: 18, color: Color(0xFF6F9126)),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Flexible(
                child: Text(
                  '#${order.orderNumber}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(order.planName, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  context.l10n.priceInclVat(formatRands(order.totalCents)),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
