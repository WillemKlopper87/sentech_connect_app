import 'package:flutter/material.dart';
import 'package:sentech_connect_app/l10n/demo_copy.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/support/domain/entities/faq.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/actions/support_actions.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key, this.cpe = false, this.whatsAppNumber});
  final bool cpe;
  final String? whatsAppNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportTitle)),
      body: BlocBuilder<SupportCubit, SupportState>(
        builder: (context, state) {
          if (state.status == SupportStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final theme = Theme.of(context);
          final query = state.query.trim().toLowerCase();
          final canWhatsApp = supportWhatsAppUri(whatsAppNumber) != null;
          final faqs = state.allFaqs
              .where(
                (faq) =>
                    cpe || !{'speed', 'topup', 'router-red'}.contains(faq.id),
              )
              .map((faq) => localizeDemoFaq(faq, l10n))
              .where(
                (faq) =>
                    query.isEmpty || faq.question.toLowerCase().contains(query),
              )
              .toList();
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  onChanged: (value) =>
                      context.read<SupportCubit>().search(value),
                  decoration: InputDecoration(
                    hintText: l10n.supportSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: faqs.isEmpty
                      ? Center(
                          child: Text(
                            l10n.supportNoResults(state.query),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: faqs.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) => _FaqTile(
                            faq: faqs[i],
                            expanded: state.expandedId == faqs[i].id,
                            onTap: () => context
                                .read<SupportCubit>()
                                .toggleExpanded(faqs[i].id),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.supportStillStuck,
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                if (canWhatsApp) ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        openWhatsAppChat(context, number: whatsAppNumber),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text(l10n.supportWhatsApp),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => submitSupportTicket(context),
                  icon: const Icon(
                    Icons.confirmation_number_outlined,
                    size: 18,
                  ),
                  label: Text(l10n.supportSubmitTicket),
                ),
              ],
            ),
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
