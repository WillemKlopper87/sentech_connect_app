import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

final _phoneChars = RegExp(r'^\+?[0-9 ()\-]+$');
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// A cheap check before the request is sent; the platform normalises and judges the contact
/// for real (a refusal comes back as `invalid_contact`). Never logged.
bool isPlausibleContact(ContactKind kind, String raw) {
  final value = raw.trim();
  if (value.isEmpty) return false;
  switch (kind) {
    case ContactKind.phone:
      if (!_phoneChars.hasMatch(value)) return false;
      final digits = value.replaceAll(RegExp(r'\D'), '').length;
      return digits >= 9 && digits <= 13;
    case ContactKind.email:
      return value.length <= 254 && _email.hasMatch(value);
  }
}

/// The contact choice (mobile number or email address) and its field. The value is held
/// by the caller's [controller] and never anywhere else.
class ContactInput extends StatelessWidget {
  const ContactInput({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.kind,
    required this.onKindChanged,
    required this.onChanged,
    this.showError = false,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final ContactKind kind;
  final ValueChanged<ContactKind> onKindChanged;
  final VoidCallback onChanged;

  /// Show the "enter a valid ..." error (after the customer typed something).
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final phone = kind == ContactKind.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ContactKind>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: ContactKind.phone, label: Text(l10n.coverageNotifyContactPhone)),
            ButtonSegment(value: ContactKind.email, label: Text(l10n.coverageNotifyContactEmail)),
          ],
          selected: {kind},
          onSelectionChanged: (selected) => onKindChanged(selected.first),
        ),
        const SizedBox(height: 12),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: phone ? TextInputType.phone : TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 254,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          autofillHints: phone ? const [AutofillHints.telephoneNumber] : const [AutofillHints.email],
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: phone ? l10n.coverageNotifyContactPhone : l10n.coverageNotifyContactEmail,
            hintText: phone ? l10n.coverageNotifyPhoneHint : l10n.coverageNotifyEmailHint,
            errorText: showError && !isPlausibleContact(kind, controller.text) ? l10n.coverageNotifyContactInvalid : null,
          ),
        ),
      ],
    );
  }
}
