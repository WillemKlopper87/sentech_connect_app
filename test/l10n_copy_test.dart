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
  String get demoFaq1Question => 'Localized speed question';
  @override
  String get demoPromotion1Title => 'Localized offer title';
  @override
  String get failureNoInternetConnection => 'Localized offline failure';
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
        expiresOn: 'External date',
      );
      final l10n = _TestCopy();
      expect(localizeDemoFaq(externalFaq, l10n), same(externalFaq));
      expect(localizeDemoPromotion(externalPromo, l10n), same(externalPromo));
      expect(
        localizeDemoFaq(
          const Faq(id: 'speed', question: '', answer: '', isDemoCopy: true),
          l10n,
        ).question,
        'Localized speed question',
      );
      expect(
        localizeDemoPromotion(
          const Promotion(
            id: 'promo_upgrade',
            title: '',
            description: '',
            badge: '',
            expiresOn: '',
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
    expect(find.text('Localized speed question'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Localized speed');
    await tester.pump();
    expect(find.text('Localized speed question'), findsOneWidget);
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
