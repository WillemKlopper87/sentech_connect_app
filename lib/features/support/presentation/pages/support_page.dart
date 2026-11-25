import 'package:flutter/material.dart';
import 'package:sentech_connect_app/l10n/demo_copy.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/support/domain/entities/faq.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/widgets/incident_notice_card.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/actions/support_actions.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({
    super.key,
    this.cpe = false,
    this.whatsAppNumber,
    this.showFaqs = true,
    this.onOpenTickets,
    this.onNewTicket,
  });
  final bool cpe;

  /// Open My tickets / a new ticket; null when ticketing is off, and then this page
  /// is exactly the old one: the one-way message form is the way to reach support.
  final VoidCallback? onOpenTickets;
  final VoidCallback? onNewTicket;

  /// The FAQ list is mock content: hidden in prod, where only the contact
  /// actions (WhatsApp, message support) show.
  final bool showFaqs;
  final String? whatsAppNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportTitle)),
      // Everything scrolls together (the incident notice can be long, and text can be large), so the
      // contact actions are always reachable. Without FAQs (prod) no SupportCubit is needed.
      body: !showFaqs
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (onOpenTickets != null) const IncidentNoticeCard(),
                _ContactActions(
                  whatsAppNumber: whatsAppNumber,
                  onOpenTickets: onOpenTickets,
                  onNewTicket: onNewTicket,
                ),
              ],
            )
          : BlocBuilder<SupportCubit, SupportState>(
              builder: (context, state) {
                final actions = _ContactActions(
                  whatsAppNumber: whatsAppNumber,
                  onOpenTickets: onOpenTickets,
                  onNewTicket: onNewTicket,
                );
                if (state.status == SupportStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final theme = Theme.of(context);
                final query = state.query.trim().toLowerCase();
                final faqs = state.allFaqs
                    .where(
                      (faq) =>
                          cpe ||
                          !{'speed', 'topup', 'router-red'}.contains(faq.id),
                    )
                    .map((faq) => localizeDemoFaq(faq, l10n))
                    .where(
                      (faq) =>
                          query.isEmpty ||
                          faq.question.toLowerCase().contains(query),
                    )
                    .toList();
                // The FAQs and the incident notice scroll; the contact actions stay below them, in an area that
                // itself scrolls when text is large, so WhatsApp, New ticket and My tickets are always reachable.
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        children: [
                          if (onOpenTickets != null) const IncidentNoticeCard(),
                          TextField(
                            onChanged: (value) =>
                                context.read<SupportCubit>().search(value),
                            decoration: InputDecoration(
                              hintText: l10n.supportSearchHint,
                              prefixIcon: const Icon(Icons.search, size: 20),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (faqs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                l10n.supportNoResults(state.query),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          else
                            for (var i = 0; i < faqs.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _FaqTile(
                                faq: faqs[i],
                                expanded: state.expandedId == faqs[i].id,
                                onTap: () => context
                                    .read<SupportCubit>()
                                    .toggleExpanded(faqs[i].id),
                              ),
                            ],
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: actions,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.faq,
    required this.expanded,
    required this.onTap,
  });

  final Faq faq;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        (context.watch<DataSaverCubit?>()?.state ?? false);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      faq.question,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more, size: 20),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  faq.answer,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Still stuck?": WhatsApp (when the provider published a number) and the
/// real message form.
class _ContactActions extends StatelessWidget {
  const _ContactActions({
    this.whatsAppNumber,
    this.onOpenTickets,
    this.onNewTicket,
  });

  final String? whatsAppNumber;
  final VoidCallback? onOpenTickets;
  final VoidCallback? onNewTicket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canWhatsApp = supportWhatsAppUri(whatsAppNumber) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.supportStillStuck,
          style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        if (canWhatsApp) ...[
          ElevatedButton.icon(
            onPressed: () => openWhatsAppChat(context, number: whatsAppNumber),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text(l10n.supportWhatsApp),
          ),
          const SizedBox(height: 8),
        ],
        if (onNewTicket != null) ...[
          // Ticketing is on: a ticket the customer can follow replaces the one-way form here.
          // (The form stays on the dashboard's "report an issue" and the account contact sheet.)
          FilledButton.icon(
            key: const Key('help-new-ticket'),
            onPressed: onNewTicket,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.ticketsNewTitle),
          ),
          if (onOpenTickets != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('help-my-tickets'),
              onPressed: onOpenTickets,
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: Text(l10n.ticketsTitle),
            ),
          ],
        ] else
          OutlinedButton.icon(
            onPressed: () => submitSupportTicket(context),
            icon: const Icon(Icons.confirmation_number_outlined, size: 18),
            label: Text(l10n.supportSubmitTicket),
          ),
      ],
    );
  }
}
