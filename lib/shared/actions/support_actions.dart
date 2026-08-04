import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Placeholder WhatsApp Business number — swap for Sentech's real number
/// before this ships. wa.me links use digits only, no "+" or spaces.
const whatsAppNumber = '270000000000';

const supportEmail = 'support@sentech.co.za'; // from the Sentech CI manual

enum TicketCategory { billing, technical, other }

extension TicketCategoryLabel on TicketCategory {
  String get label => switch (this) {
        TicketCategory.billing => 'Billing',
        TicketCategory.technical => 'Technical',
        TicketCategory.other => 'Other',
      };
}

/// Opens a WhatsApp chat with Sentech support. Shared between the Support
/// tab and any other entry point (e.g. the dashboard) that offers a
/// "contact us" action, so there's exactly one place that owns the number
/// and the pre-filled message.
Future<void> openWhatsAppChat(BuildContext context) async {
  final uri = Uri.parse(
    'https://wa.me/$whatsAppNumber?text=${Uri.encodeComponent("Hi Sentech, I need help with my account.")}',
  );
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Could not open WhatsApp — is it installed?')));
  }
}

/// Opens the ticket-category-and-description dialog, then hands off to
/// the device's email app addressed to Sentech support. Shared for the
/// same reason as [openWhatsAppChat] — the dashboard's "Report issue"
/// quick action and the Support tab both need the identical flow.
Future<void> submitSupportTicket(
  BuildContext context, {
  TicketCategory initialCategory = TicketCategory.technical,
}) async {
  final result = await showDialog<(TicketCategory, String)>(
    context: context,
    builder: (context) => _TicketDialog(initialCategory: initialCategory),
  );
  if (result == null || !context.mounted) return;
  final (category, description) = result;

  final uri = Uri(
    scheme: 'mailto',
    path: supportEmail,
    query: 'subject=${Uri.encodeComponent('[${category.label}] Support request')}'
        '&body=${Uri.encodeComponent(description)}',
  );
  final launched = await launchUrl(uri);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(launched
          ? 'Ticket opened in your email app — send it to submit.'
          : 'Could not open an email app on this device.'),
    ));
}

class _TicketDialog extends StatefulWidget {
  const _TicketDialog({required this.initialCategory});

  final TicketCategory initialCategory;

  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  late TicketCategory _category = widget.initialCategory;
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit a ticket'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<TicketCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: TicketCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: (c) => setState(() => _category = c!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            onChanged: (_) => setState(() {}),
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Describe the issue',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _descriptionController.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (_category, _descriptionController.text.trim())),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
