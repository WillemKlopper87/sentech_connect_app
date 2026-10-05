import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/theme/app_colors.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/color_contrast.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/legal_reading_links.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/expanded_localizations.dart';
import 'helpers/first_run_tenant.dart';
import 'helpers/pump_themed.dart';
import 'helpers/screens.dart';
import 'helpers/test_setup.dart';

const _screens = [
  'login',
  'home',
  'shop',
  'cart',
  'passes',
  'voucher',
  'account',
  'help',
];

RenderParagraph paragraph(
  WidgetTester tester,
  String text, {
  bool last = false,
}) => tester.renderObject<RenderParagraph>(
  find
      .descendant(
        of: last ? find.text(text).last : find.text(text).first,
        matching: find.byType(RichText),
      )
      .first,
);

void expectReadableText(WidgetTester tester) {
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    void check(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) return;
      final style = inherited.merge(span.style);
      if (span.text?.trim().isNotEmpty ?? false) {
        if (style.fontFamily != 'MaterialIcons' &&
            style.fontFamily != 'CupertinoIcons') {
          expect(style.fontSize, greaterThanOrEqualTo(12), reason: span.text);
        }
      }
      for (final child in span.children ?? <InlineSpan>[]) {
        check(child, style);
      }
    }

    check(richText.text, const TextStyle());
  }
}

void expectNoLayout(WidgetTester tester) {
  final error = tester.takeException();
  expect(error, isNull);
}

Future<void> checkScroll(WidgetTester tester) async {
  expectNoLayout(tester);
  // Scroll the actual screen, checking lazy content too, not only the first frame.
  final scrolls = find.byType(Scrollable);
  if (scrolls.evaluate().isEmpty) return;
  final state = tester.state<ScrollableState>(scrolls.first);
  for (
    var i = 0;
    i < 30 && state.position.pixels < state.position.maxScrollExtent;
    i++
  ) {
    await tester.drag(scrolls.first, const Offset(0, -350));
    await tester.pumpAndSettle();
    expectNoLayout(tester);
    expectReadableText(tester);
  }
  expect(
    state.position.pixels,
    closeTo(state.position.maxScrollExtent, 1),
    reason: 'The bottom of the populated screen must remain reachable',
  );
}

void main() {
  setUpAppTests();
  for (final brightness in Brightness.values) {
    test('specified shared sizes and AA colors in $brightness', () {
      final theme = brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark();
      final t = theme.textTheme;
      expect(t.bodyLarge!.fontSize, 16);
      expect(t.bodyMedium!.fontSize, 15);
      expect(t.labelLarge!.fontSize, 14);
      expect(t.titleMedium!.fontSize, 17);
      expect(
        theme.navigationBarTheme.labelTextStyle!.resolve({})!.fontSize,
        12,
      );
      expect(
        theme.colorScheme.onSurface,
        brightness == Brightness.light ? const Color(0xFF3D3E40) : Colors.white,
      );
      for (final style in [
        t.titleSmall,
        t.titleMedium,
        t.titleLarge,
        t.headlineSmall,
        t.headlineMedium,
        t.headlineLarge,
      ]) {
        expect(
          style!.color,
          brightness == Brightness.light ? AppColors.darkBlue : Colors.white,
        );
        expect(
          ColorContrast.ratio(style.color!, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
    for (final variant in ['en', 'zu', 'zu-expanded']) {
      final locale = Locale(variant == 'en' ? 'en' : 'zu');
      final l10n = variant == 'zu-expanded'
          ? ExpandedZulu()
          : lookupAppLocalizations(locale);
      for (final screen in _screens) {
        testWidgets(
          '$screen 360x690 2x $variant $brightness has populated reachable content',
          (tester) async {
            await pumpThemed(
              tester,
              buildScreenForTest(screen, l10n),
              brightness: brightness,
              locale: locale,
              textScale: 2,
              size: const Size(360, 690),
              localizationDelegate: variant == 'zu-expanded'
                  ? const ExpandedZuluDelegate()
                  : null,
            );
            await tester.pump(const Duration(seconds: 1));
            await tester.pumpAndSettle();
            expectNoLayout(tester);
            final marker = switch (screen) {
              'login' => l10n.loginSendCode,
              'home' => l10n.dashboardMyPasses,
              'shop' => l10n.buyNow,
              'cart' => l10n.cartCheckout,
              'passes' => l10n.passesShowExpired,
              'voucher' => l10n.scanTypeTheCodeInstead,
              'account' => l10n.accountAppearance,
              _ => l10n.supportSubmitTicket,
            };
            expect(find.text(marker), findsWidgets);
            // Real rendered text must receive the OS scaler unchanged.
            expect(paragraph(tester, marker).textScaler.scale(16), 32);
            expectReadableText(tester);
            await tester.ensureVisible(find.text(marker).last);
            await tester.pumpAndSettle();
            expect(find.text(marker).last.hitTestable(), findsOneWidget);
            expectNoLayout(tester);
            await checkScroll(tester);
            if (screen == 'voucher') {
              await tester.ensureVisible(find.text(marker));
              await tester.tap(find.text(marker));
              await tester.pumpAndSettle();
              final helper = paragraph(tester, l10n.scanVoucherCodeHelper);
              expect(helper.text.style!.fontSize, greaterThanOrEqualTo(15));
              expect(helper.textScaler.scale(16), 32);
              expect(helper.didExceedMaxLines, isFalse);
              await tester.ensureVisible(find.text(l10n.scanRedeem));
              expect(find.text(l10n.scanRedeem).hitTestable(), findsOneWidget);
              expectNoLayout(tester);
            }
          },
        );
      }
    }
  }

  test(
    'synthetic overrides are 30-60% longer than Zulu, including English fallbacks',
    () {
      final expanded = ExpandedZulu();
      final base = lookupAppLocalizations(const Locale('zu'));
      final pairs = [
        (base.loginSendCode, expanded.loginSendCode),
        (base.dashboardMyPasses, expanded.dashboardMyPasses),
        (base.shopAddToCart, expanded.shopAddToCart),
        (base.cartCheckout, expanded.cartCheckout),
        (base.passesShowExpired, expanded.passesShowExpired),
        (base.scanTypeTheCodeInstead, expanded.scanTypeTheCodeInstead),
        (base.accountAppearance, expanded.accountAppearance),
        (base.supportSubmitTicket, expanded.supportSubmitTicket),
        (base.demoFaq1Answer, expanded.demoFaq1Answer),
        (base.priceInclVat('R35'), expanded.priceInclVat('R35')),
      ];
      for (final (original, longer) in pairs) {
        expect(longer.length / original.length, inInclusiveRange(1.3, 1.6));
      }
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'rendered navigation, shop prices and error text meet size and AA in $brightness',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final theme = brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark();
        await pumpThemed(
          tester,
          Scaffold(
            bottomNavigationBar: NavigationBar(
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home),
                  label: l10n.navHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.shopping_bag),
                  label: l10n.navShop,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.qr_code),
                  label: l10n.navScan,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.help),
                  label: l10n.navHelp,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person),
                  label: l10n.navAccount,
                ),
              ],
            ),
          ),
          brightness: brightness,
          size: const Size(360, 690),
          textScale: 2,
        );
        for (final text in [
          l10n.navHome,
          l10n.navShop,
          l10n.navScan,
          l10n.navHelp,
          l10n.navAccount,
        ]) {
          final style = paragraph(tester, text).text.style!;
          expect(style.fontSize, 12);
          expect(
            ColorContrast.ratio(
              style.color!,
              theme.navigationBarTheme.backgroundColor!,
            ),
            greaterThanOrEqualTo(4.5),
          );
        }
        expectNoLayout(tester);
        await pumpThemed(
          tester,
          buildScreenForTest('shop', l10n),
          brightness: brightness,
          textScale: 2,
          size: const Size(360, 690),
        );
        await tester.pumpAndSettle();
        final price = tester
            .renderObjectList<RenderParagraph>(find.byType(RichText))
            .singleWhere(
              (r) => r.text.toPlainText() == l10n.priceInclVat('R35'),
            );
        expect(price.textScaler.scale(16), 32);
        expect(price.text.style!.fontSize, 17);
        expect(
          ColorContrast.ratio(
            price.text.style!.color!,
            theme.scaffoldBackgroundColor,
          ),
          greaterThanOrEqualTo(4.5),
        );
        final name = paragraph(
          tester,
          l10n.productCategoryHotspotPass,
          last: true,
        );
        expect(
          price.localToGlobal(Offset.zero).dy,
          greaterThanOrEqualTo(
            name.localToGlobal(Offset.zero).dy + name.size.height,
          ),
        );
        final badge = paragraph(tester, '1');
        expect(badge.text.style!.fontSize, greaterThanOrEqualTo(13));
        Color? badgeBackground;
        tester.element(find.text('1')).visitAncestorElements((element) {
          final widget = element.widget;
          if (widget is Container && widget.decoration is BoxDecoration) {
            badgeBackground = (widget.decoration! as BoxDecoration).color;
            if (badgeBackground != null) return false;
          }
          return true;
        });
        expect(
          ColorContrast.ratio(badge.text.style!.color!, badgeBackground!),
          greaterThanOrEqualTo(4.5),
        );
        await pumpThemed(
          tester,
          buildScreenForTest('account', l10n),
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(l10n.accountDeleteData), 300);
        final destructive = paragraph(
          tester,
          l10n.accountDeleteData,
        ).text.style!;
        expect(
          ColorContrast.ratio(destructive.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          ColorContrast.ratio(
            destructive.color!,
            theme.scaffoldBackgroundColor,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
    testWidgets(
      'actual body, heading and gradient text use readable colors in $brightness',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await pumpThemed(
          tester,
          buildScreenForTest('home', l10n),
          brightness: brightness,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        final body = paragraph(
          tester,
          l10n.dashboardTimeLeft(l10n.sizeGigabytes('3.8')),
        ).text.style;
        expect(body!.fontSize, greaterThanOrEqualTo(15));
        final theme = brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark();
        expect(
          ColorContrast.ratio(body.color!, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
        final heading = paragraph(
          tester,
          l10n.productCategoryHotspotPass,
        ).text.style;
        expect(heading!.fontSize, 17);
        expect(
          heading.color,
          brightness == Brightness.light ? AppColors.darkBlue : Colors.white,
        );
        final promo = paragraph(tester, l10n.homePromotionsLabel).text.style;
        expect(promo!.fontSize, greaterThanOrEqualTo(15));
        for (final stop in [AppColors.darkBlue, AppColors.gradientEnd]) {
          expect(
            ColorContrast.ratio(promo.color!, stop),
            greaterThanOrEqualTo(4.5),
          );
        }
      },
    );
    testWidgets(
      'Task2 Paste code and Read the Terms render at the shared label floor in $brightness',
      (tester) async {
        await pumpThemed(
          tester,
          buildScreenForTest(
            'login',
            lookupAppLocalizations(const Locale('en')),
          ),
          brightness: brightness,
        );
        await tester.enterText(find.byType(TextField).first, '0810000000');
        await tester.ensureVisible(find.text('Send code'));
        await tester.tap(find.text('Send code'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(paragraph(tester, 'Paste code').text.style!.fontSize, 14);
        final tenant = await firstRunTenant(
          cpe: false,
          branding: TenantBranding(
            termsUrl: Uri.parse('https://example.org/terms'),
          ),
        );
        addTearDown(tenant.close);
        await pumpThemed(
          tester,
          BlocProvider<TenantCubit>.value(
            value: tenant,
            child: const LegalReadingLinks(),
          ),
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        expect(paragraph(tester, 'Read the Terms').text.style!.fontSize, 14);
        expectNoLayout(tester);
      },
    );
  }
}
