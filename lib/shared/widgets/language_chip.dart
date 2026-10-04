import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Early language choice using the app root's existing locale preference.
class LanguageChip extends StatelessWidget {
  const LanguageChip({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<LocaleCubit?>();
    final l10n = context.l10n;
    String name(Locale locale) => switch (locale.languageCode) {
      'zu' => l10n.languageZulu,
      'af' => l10n.languageAfrikaans,
      _ => l10n.languageEnglish,
    };
    return PopupMenuButton<Locale?>(
      enabled: cubit != null,
      tooltip: l10n.accountLanguage,
      onSelected: cubit?.setLocale,
      itemBuilder: (_) => [
        // PopupMenuItem treats null as cancellation; explicitly handle device
        // default in onTap, while locale items use onSelected.
        PopupMenuItem<Locale?>(
          onTap: () => cubit?.setLocale(null),
          child: Text(l10n.accountLanguageSystem),
        ),
        for (final locale in AppLocalizations.supportedLocales)
          PopupMenuItem<Locale?>(value: locale, child: Text(name(locale))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name(cubit?.state ?? Localizations.localeOf(context)),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
