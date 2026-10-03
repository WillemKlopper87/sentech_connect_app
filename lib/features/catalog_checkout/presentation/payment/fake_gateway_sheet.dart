import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';

/// Debug + local stack only (ruling R-M4-13). true = approve, false =
/// decline, null = dismissed.
Future<bool?> showFakeGatewaySheet(
  BuildContext context,
  PaymentHandoff handoff,
) => showModalBottomSheet<bool>(
  context: context,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.paymentTestPaymentLocalStack,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.paymentTestExplanation(
              context.l10n.priceInclVat(formatRands(handoff.amountCents)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.paymentApproveTestPayment),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.paymentDeclineTestPayment),
          ),
        ],
      ),
    ),
  ),
);
