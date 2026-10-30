import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/support/domain/entities/support_message.dart';
import 'package:sentech_connect_app/features/support/presentation/widgets/support_message_sheet.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

/// Uses only the existing tenant branding contact contract.
Uri? supportWhatsAppUri(String? number, {String? message}) {
  final valid = TenantBranding.validWhatsAppNumber(number);
  if (valid == null) return null;
  return Uri.https(
    'wa.me',
    '/${valid.substring(1)}',
    message == null ? null : {'text': message},
  );
}

const supportEmail = 'support@sentech.co.za'; // from the Sentech CI manual

/// Opens a WhatsApp chat with Sentech support. Shared between the Support
/// tab and any other entry point (e.g. the dashboard) that offers a
/// "contact us" action, so there's exactly one place that owns the number
/// and the pre-filled message.
Future<void> openWhatsAppChat(BuildContext context, {String? number}) async {
  final uri = supportWhatsAppUri(
    number,
    message: context.l10n.supportChatGreeting,
  );
  if (uri == null) return;
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.supportWhatsAppFailed)),
      );
  }
}

/// The address "Email us instead" opens when the platform has no support inbox
/// for this provider (`support_contact_not_configured`): the provider's own
/// published address, else the Sentech one for the default provider only.
String? supportFallbackEmail(BuildContext context) {
  final configured = context.read<TenantCubit?>()?.state.config?.support.email;
  if (configured != null) return configured;
  final isDefault =
      locator.isRegistered<TenantContext>() &&
      locator<TenantContext>().slug == TenantContext.defaultSlug;
  return isDefault ? supportEmail : null;
}

/// Opens the "message support" form (a real `POST /v1/support/messages`).
/// Shared between the Support tab and the dashboard's "Report issue" shortcut.
Future<void> submitSupportTicket(
  BuildContext context, {
  SupportTopic topic = SupportTopic.connecting,
}) => showSupportMessageSheet(
  context,
  topic: topic,
  fallbackEmail: supportFallbackEmail(context),
);
