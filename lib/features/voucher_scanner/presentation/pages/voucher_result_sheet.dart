import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/bloc/voucher_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/widgets/pass_ready_view.dart';

/// Result of a redemption attempt. Shows fixed wording plus the masked code;
/// a scanned payload is never shown, so a hostile QR code cannot put
/// arbitrary text in front of the customer. A code the customer TYPED is
/// shown back unmasked when it was refused ([enteredCode]), so a typo can be
/// seen and fixed.
class VoucherResultSheet extends StatelessWidget {
  const VoucherResultSheet({
    super.key,
    required this.state,
    required this.onRetry,
    this.onTryAgain,
    this.enteredCode,
  });

  final VoucherState state;

  /// Offered only after a network failure: repeats the same request.
  final VoidCallback onRetry;

  /// Offered when the code was refused: lets the customer fix it.
  final VoidCallback? onTryAgain;

  /// What the customer typed, shown instead of the masked code on a refusal.
  final String? enteredCode;

  ({IconData icon, String title, String body}) _content(BuildContext context) {
    if (state.failure != null) {
      if (state.failure is RateLimitedFailure) {
        return (
          icon: Icons.hourglass_empty,
          title: context.l10n.voucherTooManyTries,
          body: context.l10n.voucherWaitAFewMinutesThenTry,
        );
      }
      return (
        icon: Icons.wifi_off,
        title: state.failure is NetworkFailure
            ? context.l10n.voucherYouReOffline
            : context.l10n.voucherSomethingWentWrong,
        body: state.failure is NetworkFailure
            ? context.l10n.voucherCheckYourConnectionAndTryAgain
            : context.l10n.voucherWeCouldNotCheckThisVoucher,
      );
    }
    return switch (state.outcome) {
      VoucherOutcome.redeemed => (
        icon: Icons.check_circle,
        title: (state.productName ?? state.pass?.productName) == null
            ? context.l10n.voucherVoucherRedeemed
            : context.l10n.voucherProductReady(
                (state.productName ?? state.pass?.productName)!,
              ),
        body: context.l10n.voucherYourPassIsOnYourAccount,
      ),
      VoucherOutcome.alreadyUsed => (
        icon: Icons.block,
        title: context.l10n.voucherAlreadyUsed,
        body: context.l10n.voucherThisVoucherHasAlreadyBeenRedeemed,
      ),
      VoucherOutcome.expired => (
        icon: Icons.schedule,
        title: context.l10n.voucherVoucherExpired,
        body: context.l10n.voucherThisVoucherIsNoLongerValid,
      ),
      _ => switch (state.inputProblem) {
        VoucherCodeProblem.checkSymbol => (
          icon: Icons.error_outline,
          title: context.l10n.voucherOneCharacterLooksWrong,
          body: context.l10n.voucherCompareTheCodeWithYourVoucher,
        ),
        VoucherCodeProblem.notInAlphabet => (
          icon: Icons.error_outline,
          title: context.l10n.voucherCheckTheCode,
          body: context.l10n.voucherVoucherCodesNeverUse01,
        ),
        VoucherCodeProblem.length => (
          icon: Icons.error_outline,
          title: context.l10n.voucherCheckTheCode,
          body: context.l10n.voucherVoucherCodesHave12LettersAnd,
        ),
        VoucherCodeProblem.format => (
          icon: Icons.error_outline,
          title: context.l10n.voucherNotAVoucherCode,
          body: context.l10n.voucherCheckTheCodeOnYourVoucher,
        ),
        // The server answers every refusal the same way, on purpose.
        null => (
          icon: Icons.error_outline,
          title: context.l10n.voucherThatCodeDidnTWork,
          body: context.l10n.voucherItMayBeMistypedAlreadyUsed,
        ),
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _content(context);
    final success = state.outcome == VoucherOutcome.redeemed;
    if (success) {
      final pass = state.pass;
      final data = pass == null ? state.dataMb : pass.dataMb;
      final detail = pass != null
          ? context.l10n.voucherPassDetail(
              data == null
                  ? context.l10n.voucherUncappedData
                  : context.l10n.voucherDataMb(data),
              pass.durationMinutes,
              pass.maxDevices,
            )
          : data == null
          ? context.l10n.voucherYourPassIsOnYourAccount
          : context.l10n.voucherDataMb(data);
      return PassReadyView(
        title: content.title,
        detail: [
          detail,
          if (state.maskedCode != null) state.maskedCode!,
        ].join('\n'),
        onDone: () => Navigator.pop(context),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(content.icon, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              content.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              content.body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if ((enteredCode ?? state.maskedCode) != null) ...[
              const SizedBox(height: 10),
              Text(
                enteredCode ?? state.maskedCode!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (state.failure != null) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 15),
                ),
                onPressed: onRetry,
                child: Text(context.l10n.commonTryAgain),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 15),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonCancel),
              ),
            ] else if (onTryAgain != null) ...[
              ElevatedButton(
                onPressed: onTryAgain,
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 15),
                ),
                child: Text(context.l10n.commonCheckCode),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 15),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonDone),
              ),
            ] else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 15),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonDone),
              ),
          ],
        ),
      ),
    );
  }
}
