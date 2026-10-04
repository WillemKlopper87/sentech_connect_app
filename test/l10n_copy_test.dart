import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/domain/entities/faq.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/support_page.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/bloc/voucher_cubit.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_result_sheet.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';
import 'package:sentech_connect_app/l10n/app_localizations_en.dart';
import 'package:sentech_connect_app/l10n/demo_copy.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';
import 'helpers/pump_themed.dart';

// Test markers demonstrate routing through localization; no translations ship.
class _TestCopy extends AppLocalizationsEn {
  @override
  String get hotspotFaq1Question => 'Localized hotspot question';
  @override
  String get demoPromotion1Title => 'Localized offer title';
  @override
  String get failureNoInternetConnection => 'Localized offline failure';
  @override
  String get failureThisProviderIsCurrentlyUnavailable =>
      'Localized internet service failure';
}

class _TestDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _TestDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(_TestCopy());
  @override
  bool shouldReload(_TestDelegate old) => false;
}

void main() {
  test(
    'only explicitly owned demo copy is replaced, even with colliding ids',
    () {
      const externalFaq = Faq(
        id: 'speed',
        question: 'External question',
        answer: 'External answer',
      );
      const externalPromo = Promotion(
        id: 'promo_upgrade',
        title: 'External title',
        description: 'External description',
        badge: 'External badge',
      );
      final l10n = _TestCopy();
      expect(localizeDemoFaq(externalFaq, l10n), same(externalFaq));
      expect(localizeDemoPromotion(externalPromo, l10n), same(externalPromo));
      expect(
        localizeDemoFaq(
          const Faq(
            id: 'hotspot-connect',
            question: '',
            answer: '',
            isDemoCopy: true,
          ),
          l10n,
        ).question,
        'Localized hotspot question',
      );
      expect(
        localizeDemoPromotion(
          const Promotion(
            id: 'promo_upgrade',
            title: '',
            description: '',
            badge: '',
            isDemoCopy: true,
          ),
          l10n,
        ).title,
        'Localized offer title',
      );
    },
  );

  test(
    'owned failure text is localized while external details remain data',
    () {
      final l10n = _TestCopy();
      expect(
        localizedFailureText(l10n, const NetworkFailure().message),
        'Localized offline failure',
      );
      expect(
        localizedFailureText(l10n, 'External customer-specific detail'),
        'External customer-specific detail',
      );
      expect(l10n.priceInclVat('R35'), 'R35 incl. VAT');
    },
  );

  test('owned source identity survives revised English display copy', () {
    final l10n = AppLocalizationsEn();
    final cases = <String, String>{
      const ProviderUnavailableFailure().message:
          l10n.failureThisProviderIsCurrentlyUnavailable,
      const NotFoundFailure('Unknown provider.').message:
          l10n.failureUnknownProvider,
      'This order was replaced by a newer one and can no longer be paid.':
          l10n.failureThisOrderWasReplacedByANewer,
    };
    for (final entry in cases.entries) {
      expect(entry.value, isNot(entry.key), reason: 'Display wording changed');
      expect(localizedFailureText(l10n, entry.key), entry.value);
    }
    expect(
      localizedFailureText(
        _TestCopy(),
        const ProviderUnavailableFailure().message,
      ),
      'Localized internet service failure',
    );
    expect(
      localizedFailureText(l10n, 'External service detail for this customer'),
      'External service detail for this customer',
    );
  });

  testWidgets('FAQ search filters the displayed localized question', (
    tester,
  ) async {
    final cubit = SupportCubit(MockSupportRepository());
    addTearDown(cubit.close);
    await pumpThemed(
      tester,
      Builder(
        builder: (context) => Localizations.override(
          context: context,
          delegates: const [_TestDelegate()],
          child: BlocProvider.value(value: cubit, child: const SupportPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Localized hotspot question'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Localized hotspot');
    await tester.pump();
    expect(find.text('Localized hotspot question'), findsOneWidget);
    expect(find.text('How do I top up my data?'), findsNothing);
  });

  testWidgets(
    'uncertain voucher failure asks for retry without an unused promise',
    (tester) async {
      await pumpThemed(
        tester,
        VoucherResultSheet(
          state: const VoucherState(
            status: VoucherStatus.result,
            failure: NetworkFailure(),
          ),
          onRetry: () {},
        ),
      );
      expect(
        find.textContaining('could not confirm whether this voucher was used'),
        findsOneWidget,
      );
      expect(find.textContaining('has not been used'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    },
  );
}
