import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/repositories/fiveg_repository.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/usage_levels.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/bloc/unlock_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Shows the unlock for one offer and creates its order. The sheet closes with
/// the order id, which the caller passes to the shared payment screen. Returns
/// null when the customer dismisses the sheet.
Future<String?> showUnlockConfirmSheet(
  BuildContext context, {
  required FiveGRepository repository,
  required String serviceId,
  required UnlockOffer offer,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => BlocProvider(
      create: (_) => UnlockCubit(repository, serviceId)..choose(offer),
      child: const UnlockConfirmSheet(),
    ),
  );
}

/// The confirmation: the data, the price with VAT, the last valid day, and one
/// button to continue to payment.
class UnlockConfirmSheet extends StatelessWidget {
  const UnlockConfirmSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: BlocConsumer<UnlockCubit, UnlockState>(
          listener: (context, state) {
            final orderId = state.orderId;
            if (state.status == UnlockStatus.ready && orderId != null) {
              Navigator.of(context).pop(orderId);
            }
          },
          builder: (context, state) {
            final offer = state.offer;
            final busy = state.status == UnlockStatus.creating;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.fivegSheetTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                if (offer != null) ...[
                  Text(l10n.fivegOfferAdds(formatDataSize(offer.addedMb)), style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(offer.name, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Text(l10n.fivegPriceInclVat(formatRands(offer.priceCents)), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    l10n.fivegValidUntil(formatApiDay(context, offer.validUntil)),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                if (state.status == UnlockStatus.failure && state.failure != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          localizedFailureText(l10n, state.failure!.message),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy || offer == null ? null : () => context.read<UnlockCubit>().confirm(),
                  child: busy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Flexible(child: Text(l10n.fivegSheetBusy)),
                          ],
                        )
                      : Text(l10n.fivegSheetContinue),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
