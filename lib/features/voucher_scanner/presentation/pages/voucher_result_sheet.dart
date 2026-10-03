import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/bloc/voucher_cubit.dart';

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

  ({IconData icon, String title, String body}) get _content {
    if (state.failure != null) {
      if (state.failure is RateLimitedFailure) {
        return (
          icon: Icons.hourglass_empty,
          title: 'Too many tries',
          body: 'Wait a few minutes, then try again. Your voucher has not been used.',
        );
      }
      return (
        icon: Icons.wifi_off,
        title: state.failure is NetworkFailure ? "You're offline" : 'Something went wrong',
        body: state.failure is NetworkFailure
            ? 'Check your connection and try again. Your voucher has not been used.'
            : 'We could not check this voucher. Please try again.',
      );
    }
    return switch (state.outcome) {
      VoucherOutcome.redeemed => (
          icon: Icons.check_circle,
          title: state.productName == null ? 'Voucher redeemed' : '${state.productName} is ready',
          body: state.dataMb == null
              ? (state.productName == null
                  ? 'Data has been added to your account.'
                  : 'Your pass is on your account. Find it under My passes.')
              : '${(state.dataMb! / 1024).toStringAsFixed(0)} GB has been added to your account.',
        ),
      VoucherOutcome.alreadyUsed => (
          icon: Icons.block,
          title: 'Already used',
          body: 'This voucher has already been redeemed.',
        ),
      VoucherOutcome.expired => (icon: Icons.schedule, title: 'Voucher expired', body: 'This voucher is no longer valid.'),
      _ => switch (state.inputProblem) {
          VoucherCodeProblem.checkSymbol => (
              icon: Icons.error_outline,
              title: 'One character looks wrong',
              body: 'Compare the code with your voucher card, then try again.',
            ),
          VoucherCodeProblem.notInAlphabet => (
              icon: Icons.error_outline,
              title: 'Check the code',
              body: 'Voucher codes never use 0, 1, I, L, O or U. Check those characters.',
            ),
          VoucherCodeProblem.length => (
              icon: Icons.error_outline,
              title: 'Check the code',
              body: 'Voucher codes have 12 letters and numbers.',
            ),
          VoucherCodeProblem.format => (
              icon: Icons.error_outline,
              title: 'Not a voucher code',
              body: 'Check the code on your voucher card and try again.',
            ),
          // The server answers every refusal the same way, on purpose.
          null => (
              icon: Icons.error_outline,
              title: "That code didn't work",
              body: 'It may be mistyped, already used or not active yet. Check it, or ask the shop.',
            ),
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _content;
    final success = state.outcome == VoucherOutcome.redeemed;
    final color = success ? const Color(0xFF6F9126) : theme.colorScheme.error;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(content.icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(content.title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(content.body, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            if ((enteredCode ?? state.maskedCode) != null) ...[
              const SizedBox(height: 10),
              Text(
                enteredCode ?? state.maskedCode!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            if (state.failure != null) ...[
              ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ] else if (!success && onTryAgain != null) ...[
              ElevatedButton(onPressed: onTryAgain, child: const Text('Try again')),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ] else
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
