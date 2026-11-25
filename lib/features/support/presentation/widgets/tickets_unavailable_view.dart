import 'package:flutter/material.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/actions/support_actions.dart';

/// Shown in place of a ticket screen when ticketing is not available (the provider has it off, or the
/// server is older than the routes). It says so in plain words and still offers the one-way message form,
/// so the customer is never left without a way to reach support.
class TicketsUnavailableView extends StatelessWidget {
  const TicketsUnavailableView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.ticketsUnavailable, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('tickets-message-support'),
              onPressed: () => submitSupportTicket(context),
              icon: const Icon(Icons.mail_outline, size: 18),
              label: Text(l10n.supportComposeTitle),
            ),
          ],
        ),
      ),
    );
  }
}
