import 'package:flutter/material.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/privacy/privacy_constants.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Returns true when the customer has a valid consent for [purpose],
/// showing the consent dialog first if they do not. Call this immediately
/// BEFORE capturing location or starting RICA capture; if it returns false,
/// do not proceed. Agreeing stores a versioned, timestamped record.
///
/// A second call for the same purpose while one is running (a double tap)
/// joins it: one dialog, one record.
Future<bool> ensureConsent(
  BuildContext context,
  ConsentPurpose purpose, {
  ConsentRepository? repository,
}) {
  final repo = repository ?? locator<ConsentRepository>();
  final key = (repo, purpose);
  final running = _ensuring[key];
  if (running != null) return running;
  return _ensuring[key] = _ensureConsent(context, purpose, repo).whenComplete(() {
    _ensuring.remove(key);
  });
}

final _ensuring = <(ConsentRepository, ConsentPurpose), Future<bool>>{};

Future<bool> _ensureConsent(BuildContext context, ConsentPurpose purpose, ConsentRepository repo) async {
  final existing = (await repo.currentConsent(purpose)).getOrElse((_) => null);
  if (existing != null) return true;
  if (!context.mounted) return false;

  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ConsentDialog(purpose: purpose),
  );
  if (agreed != true) return false;
  return (await repo.grant(purpose)).isRight();
}

/// Plain-language notice for one purpose, with a link to the full policy.
class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key, required this.purpose});

  final ConsentPurpose purpose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = switch (purpose) {
      ConsentPurpose.locationCapture => l10n.consentLocationBody,
      ConsentPurpose.ricaCapture => l10n.consentRicaBody,
      ConsentPurpose.terms || ConsentPurpose.privacy || ConsentPurpose.marketingSms => l10n.consentLegalBody,
    };
    return AlertDialog(
      title: Text(l10n.consentTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            // Reverse geocoding uses the platform geocoder (Google or Apple):
            // say so before any location is read.
            if (purpose == ConsentPurpose.locationCapture) ...[
              const SizedBox(height: 8),
              Text(l10n.consentLocationMapService),
            ],
            const SizedBox(height: 12),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 48)),
              onPressed: () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication),
              child: Text(l10n.consentPolicyLink),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.consentDecline)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.consentAgree)),
      ],
    );
  }
}
