import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/privacy/privacy_constants.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// The public tenant policy when configured, otherwise the release fallback.
Uri privacyReadingUrl(BuildContext context) =>
    context.read<TenantCubit?>()?.state.config?.tenant.branding.privacyUrl ??
    Uri.parse(privacyPolicyUrl);

class LegalLanguageNote extends StatelessWidget {
  const LegalLanguageNote({
    super.key,
    required this.body,
    required this.englishBody,
  });
  final String body;
  final String englishBody;

  @override
  Widget build(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'en' ||
        body != englishBody) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        context.l10n.legalBodyLanguageNote,
        key: const Key('legal-language-note'),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

/// Public configured destinations only; consent still uses the existing ledger.
class LegalReadingLinks extends StatelessWidget {
  const LegalReadingLinks({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    bool opened;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.legalLinkOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = context
        .watch<TenantCubit?>()
        ?.state
        .config
        ?.tenant
        .branding;
    final terms = branding?.termsUrl;
    // Existing privacy destination remains a release placeholder without config.
    final privacy = privacyReadingUrl(context);
    final l10n = context.l10n;
    return Wrap(
      spacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => _open(context, privacy),
          child: Text(l10n.consentPolicyLink),
        ),
        if (terms != null)
          TextButton(
            onPressed: () => _open(context, terms),
            child: Text(l10n.consentTermsLink),
          )
        else
          Text(
            l10n.consentTermsUnavailable,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
      ],
    );
  }
}
