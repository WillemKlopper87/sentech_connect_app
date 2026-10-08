import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reviews one pass or voucher without changing the app's existing cart.
/// Creating an unpaid order is deferred until the customer presses Pay.
///
/// When the provider collects its own money ([buyInApp] false) the sheet still
/// describes the product but offers no way to pay: it says who to contact.
Future<void> showBuyNowSheet(
  BuildContext context,
  Plan plan, {
  required void Function(Order) onOrderCreated,
  bool showDemoMethods = false,
  bool showCashVoucher = false,
  bool buyInApp = true,
}) async {
  // Read before the route opens: the sheet sits above this context's providers.
  final provider = providerContactOf(context);
  final reviewCart = CartCubit()
    ..clear()
    ..addItem(plan);
  final reduceMotion =
      MediaQuery.disableAnimationsOf(context) ||
      (context.read<DataSaverCubit?>()?.state ?? false);
  try {
    final order = await showModalBottomSheet<Order>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
      builder: (sheetContext) => BlocProvider(
        create: (_) => CheckoutCubit(locator<CheckoutRepository>(), reviewCart),
        child: _BuyNowReview(
          plan: plan,
          reduceMotion: reduceMotion,
          showDemoMethods: showDemoMethods,
          showCashVoucher: showCashVoucher,
          buyInApp: buyInApp,
          provider: provider,
          onCreated: (order) {
            // A dismissed route can remain mounted during its reverse
            // transition. It must never pop the route beneath it.
            if (ModalRoute.of(sheetContext)?.isCurrent ?? false) {
              Navigator.of(sheetContext).pop(order);
            }
          },
        ),
      ),
    );
    if (order != null && context.mounted) onOrderCreated(order);
  } finally {
    await reviewCart.close();
  }
}

class _BuyNowReview extends StatelessWidget {
  const _BuyNowReview({
    required this.plan,
    required this.reduceMotion,
    required this.showDemoMethods,
    required this.showCashVoucher,
    required this.onCreated,
    required this.buyInApp,
    required this.provider,
  });

  final Plan plan;
  final bool reduceMotion;
  final bool showDemoMethods;
  final bool showCashVoucher;
  final void Function(Order) onCreated;
  final bool buyInApp;
  final ProviderContact provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = context.l10n.priceInclVat(
      formatRands(plan.priceCents, wholeRands: true),
    );
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listenWhen: (before, after) =>
          before.status != after.status &&
          after.status == CheckoutStatus.created,
      listener: (context, state) {
        if (state.order case final order?) onCreated(order);
      },
      builder: (context, state) {
        final busy =
            state.status == CheckoutStatus.creating ||
            state.status == CheckoutStatus.created;
        // Also when the server says so after the config was cached: there is
        // nothing to retry, so show the notice rather than an error.
        final buyElsewhere =
            !buyInApp || state.failure is CollectionExternalFailure;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(plan.name, style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 12),
                          Text(price, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 20),
                          Text(
                            context.l10n.buyNowWhatYouGet,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            plan.dataDescription,
                            style: theme.textTheme.bodyLarge,
                          ),
                          if (plan.speedMbps > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.buyNowSpeed(
                                plan.speedMbps.toString(),
                              ),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                          if (buyElsewhere) ...[
                            const SizedBox(height: 20),
                            BuyFromProviderNotice(provider: provider),
                          ],
                          if (showDemoMethods && !buyElsewhere) ...[
                            const SizedBox(height: 20),
                            PaymentMethodsRow(showCashVoucher: showCashVoucher),
                          ],
                          if (state.status == CheckoutStatus.failure &&
                              !buyElsewhere) ...[
                            const SizedBox(height: 20),
                            FailureView(
                              failure: state.failure,
                              compact: true,
                              retryLabel: context.l10n.buyNowTryAgain,
                              onRetry: () =>
                                  context.read<CheckoutCubit>().createOrder(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!buyElsewhere) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => context.read<CheckoutCubit>().createOrder(),
                      child: busy
                          ? reduceMotion
                                ? Text(context.l10n.buyNowCreatingOrder)
                                : const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                          : Text(context.l10n.buyNowPay(price)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The provider's name and public support channels, as sent by the server.
typedef ProviderContact = ({String name, SupportChannels support});

/// Reads the selected provider. Without a provider (tests, first launch) it
/// falls back to the app name and no channels.
ProviderContact providerContactOf(BuildContext context) {
  final config = context.read<TenantCubit?>()?.state.config;
  return (
    name: config?.tenant.name ?? 'Sentech Connect',
    support: config?.support ?? const SupportChannels(),
  );
}

/// "Buy this from {provider} directly." with the provider's support email and
/// phone as buttons, each only when the provider has published it.
class BuyFromProviderNotice extends StatelessWidget {
  const BuyFromProviderNotice({super.key, required this.provider});

  final ProviderContact provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.paymentBuyFromProvider(provider.name),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ProviderContactLinks(provider: provider),
      ],
    );
  }
}

/// "Contact {provider}." and one button per published support channel.
class ProviderContactLinks extends StatelessWidget {
  const ProviderContactLinks({super.key, required this.provider});

  final ProviderContact provider;

  Future<void> _launch(BuildContext context, Uri uri) async {
    bool opened;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.legalLinkOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = provider.support.email;
    final phone = provider.support.phone;
    if (email == null && phone == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          context.l10n.paymentContactProvider(provider.name),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Wrap(
          spacing: 8,
          children: [
            if (email != null)
              TextButton(
                onPressed: () =>
                    _launch(context, Uri(scheme: 'mailto', path: email)),
                child: Text(email),
              ),
            if (phone != null)
              TextButton(
                onPressed: () => _launch(
                  context,
                  Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
                ),
                child: Text(phone),
              ),
          ],
        ),
      ],
    );
  }
}

/// Demo payment choices. The production hosted gateway decides its own methods.
class PaymentMethodsRow extends StatelessWidget {
  const PaymentMethodsRow({super.key, this.showCashVoucher = false});

  final bool showCashVoucher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget method(IconData icon, String label) => ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 40,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: theme.textTheme.labelLarge)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.paymentMethodsHeading,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            method(Icons.credit_card, context.l10n.paymentMethodCard),
            method(Icons.account_balance, context.l10n.paymentMethodInstantEft),
            if (showCashVoucher)
              method(
                Icons.confirmation_number_outlined,
                context.l10n.paymentMethodCashVoucher,
              ),
          ],
        ),
      ],
    );
  }
}
