import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/bloc/voucher_cubit.dart';

/// Result of a redemption attempt. Shows only fixed, generic wording plus
/// the masked code — never the scanned/typed payload, so a hostile QR code
/// cannot put arbitrary text in front of the customer.
class VoucherResultSheet extends StatelessWidget {
  const VoucherResultSheet({super.key, required this.state, required this.onRetry});

  final VoucherState state;

  /// Offered only after a network failure.
  final VoidCallback onRetry;

  ({IconData icon, String title, String body}) get _content {
    if (state.failure != null) {
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
          title: 'Voucher redeemed',
          body: state.dataMb == null
              ? 'Data has been added to your account.'
              : '${(state.dataMb! / 1024).toStringAsFixed(0)} GB has been added to your account.',
        ),
      VoucherOutcome.alreadyUsed => (
          icon: Icons.block,
          title: 'Already used',
          body: 'This voucher has already been redeemed.',
        ),
      VoucherOutcome.expired => (icon: Icons.schedule, title: 'Voucher expired', body: 'This voucher is no longer valid.'),
      _ => (
          icon: Icons.error_outline,
          title: 'Not a valid voucher',
          body: 'That is not a valid Sentech voucher. Check the code and try again.',
        ),
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
            if (state.maskedCode != null) ...[
              const SizedBox(height: 10),
              Text(
                state.maskedCode!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            if (state.failure != null) ...[
              ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ] else
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
