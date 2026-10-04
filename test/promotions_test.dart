import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';
import 'package:sentech_connect_app/features/promotions/data/repositories/mock_promotions_repository.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';
import 'package:sentech_connect_app/features/promotions/presentation/bloc/promotions_cubit.dart';
import 'package:sentech_connect_app/features/promotions/presentation/pages/promotions_page.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/l10n/demo_copy.dart';
import 'helpers/pump_themed.dart';

Promotion offer(String id, {DateTime? expiry, ProductCategory? category}) =>
    Promotion(
      id: id,
      title: id,
      description: 'Offer details',
      badge: 'OFFER',
      expiresAt: expiry,
      appliesTo: category,
    );

class _Offers implements PromotionsRepository {
  _Offers(this.offers, {this.failed = false});
  final List<Promotion> offers;
  final bool failed;
  int pointsCalls = 0;
  @override
  Future<Either<Failure, List<Promotion>>> getActivePromotions() async =>
      failed ? const Left(NetworkFailure()) : Right(offers);
  @override
  Future<Either<Failure, int>> getLoyaltyPoints() async {
    pointsCalls++;
    return const Right(1240);
  }
}

class _Catalog implements CatalogRepository {
  _Catalog(this.result);
  final Either<Failure, List<Plan>> result;
  @override
  Future<Either<Failure, List<Plan>>> getProducts() async => result;
}

const pass = Plan(
  id: 'pass',
  name: 'WiFi pass',
  priceCents: 3500,
  speedMbps: 0,
  dataDescription: '1 GB',
  category: ProductCategory.hotspotPass,
);

void main() {
  final now = DateTime.utc(2026, 10, 4, 10);
  test(
    'expired and unsold-category offers are hidden without mutating input',
    () {
      final expired = offer(
        'expired',
        expiry: now.subtract(const Duration(microseconds: 1)),
      );
      final upgrade = offer('upgrade', category: ProductCategory.home5g);
      final voucher = offer('voucher', category: ProductCategory.voucher);
      final all = [expired, upgrade, voucher];
      expect(
        visiblePromotions(
          all,
          now: now,
          sold: {ProductCategory.hotspotPass, ProductCategory.voucher},
        ),
        [voucher],
      );
      expect(all, [expired, upgrade, voucher]);
    },
  );
  test(
    'exact instant boundary, future, ongoing and null category stay visible',
    () {
      final boundary = offer('boundary', expiry: now.toLocal());
      final future = offer(
        'future',
        expiry: now.add(const Duration(microseconds: 1)),
      );
      final ongoing = offer('ongoing');
      expect(
        visiblePromotions([boundary, future, ongoing], now: now, sold: {}),
        [boundary, future, ongoing],
      );
      expect(
        visiblePromotions(
          [offer('category', category: ProductCategory.voucher)],
          now: now,
          sold: {},
        ),
        isEmpty,
      );
    },
  );
  test(
    'cubit filters against actual catalogue and injected clock, without loading points',
    () async {
      final repo = _Offers([
        offer('sold', category: ProductCategory.hotspotPass),
        offer('unsold', category: ProductCategory.home5g),
        offer('expired', expiry: now.subtract(const Duration(seconds: 1))),
      ]);
      final cubit = PromotionsCubit(
        repo,
        catalog: _Catalog(const Right([pass])),
        now: () => now,
      );
      addTearDown(cubit.close);
      await cubit.stream.firstWhere(
        (s) => s.status != PromotionsStatus.loading,
      );
      expect(cubit.state.promotions.map((p) => p.id), ['sold']);
      expect(repo.pointsCalls, 0);
    },
  );
  test(
    'failed or missing catalogue remains unknown, without guessing unsold categories',
    () async {
      for (final catalog in <CatalogRepository?>[
        null,
        _Catalog(const Left(NetworkFailure())),
      ]) {
        final cubit = PromotionsCubit(
          _Offers([
            offer('category', category: ProductCategory.home5g),
            offer('expired', expiry: now.subtract(const Duration(seconds: 1))),
          ]),
          catalog: catalog,
          now: () => now,
        );
        await cubit.stream.firstWhere(
          (s) => s.status != PromotionsStatus.loading,
        );
        expect(cubit.state.promotions.map((p) => p.id), ['category']);
        await cubit.close();
      }
    },
  );
  test(
    'mock dates follow supplied current clock, and fixtures invent no credits',
    () async {
      final result = await MockPromotionsRepository(
        now: () => now,
      ).getActivePromotions();
      final promos = result.getOrElse((_) => []);
      expect(promos.first.expiresAt, now.add(const Duration(days: 30)));
      expect(promos.last.expiresAt, isNull);
      expect(
        promos.every((p) => p.appliesTo == ProductCategory.home5g),
        isTrue,
      );
      expect(promos.any((p) => p.id == 'promo_loyalty'), isFalse);
      final localized = localizeDemoPromotion(
        promos.first,
        lookupAppLocalizations(const Locale('af')),
      );
      expect(localized.expiresAt, promos.first.expiresAt);
      expect(localized.appliesTo, promos.first.appliesTo);
    },
  );
  testWidgets('loyalty points stay hidden until credits exist', (tester) async {
    final repo = _Offers([offer('current')]);
    final cubit = PromotionsCubit(repo);
    addTearDown(cubit.close);
    await pumpThemed(
      tester,
      BlocProvider.value(value: cubit, child: const PromotionsPage()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1240'), findsNothing);
    expect(find.textContaining('loyalty balance'), findsNothing);
    expect(find.text('Offers'), findsOneWidget);
    expect(repo.pointsCalls, 0);
  });
  for (final lang in ['en', 'zu', 'af']) {
    testWidgets(
      'expiry uses locale $lang and ongoing has no fake date at 200%',
      (tester) async {
        final expiry = DateTime.utc(2026, 11, 9, 10);
        final cubit = PromotionsCubit(
          _Offers([offer('current', expiry: expiry), offer('ongoing')]),
          now: () => now,
        );
        addTearDown(cubit.close);
        await pumpThemed(
          tester,
          BlocProvider.value(value: cubit, child: const PromotionsPage()),
          locale: Locale(lang),
          textScale: 2,
          size: const Size(360, 690),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(Locale(lang));
        expect(
          find.text(
            l10n.promotionsExpires(
              DateFormat.MMMd(lang).format(expiry.toLocal()),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.promotionsOngoing), findsOneWidget);
        expect(tester.takeException(), isNull);
        final badge = tester.widget<Text>(find.text('OFFER').first);
        expect(badge.style!.fontSize, greaterThanOrEqualTo(13));
      },
    );
  }
  testWidgets(
    'empty state has plain icon and failed offers do not claim empty inventory',
    (tester) async {
      for (final failed in [false, true]) {
        final cubit = PromotionsCubit(_Offers([], failed: failed));
        await pumpThemed(
          tester,
          BlocProvider.value(value: cubit, child: const PromotionsPage()),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            failed
                ? 'Offers are unavailable. Try again later.'
                : 'No offers right now',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.local_offer_outlined), findsOneWidget);
        await cubit.close();
      }
    },
  );
}
