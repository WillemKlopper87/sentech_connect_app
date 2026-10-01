import 'package:flutter/material.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';

/// The customer's data export (`GET /v1/me/export`). Capture-protected:
/// it is all their personal data in one place.
class DataExportPage extends StatelessWidget {
  const DataExportPage({super.key, required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.dataExportTitle)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.dataExportBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SelectableText(json, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
