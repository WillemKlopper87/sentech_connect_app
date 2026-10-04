import 'package:sentech_connect_app/l10n/app_localizations_en.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';

class MockPromotionsRepository implements PromotionsRepository {
  MockPromotionsRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, List<Promotion>>> getActivePromotions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = _now();
    final copy = AppLocalizationsEn();
    return Right([
      Promotion(
        id: 'promo_upgrade',
        isDemoCopy: true,
        title: copy.demoPromotion1Title,
        description: copy.demoPromotion1Description,
        badge: copy.demoPromotion1Badge,
        expiresAt: now.add(const Duration(days: 30)),
        appliesTo: ProductCategory.home5g,
      ),
      Promotion(
        id: 'promo_referral',
        isDemoCopy: true,
        title: copy.demoPromotion2Title,
        description: copy.demoPromotion2Description,
        badge: copy.demoPromotion2Badge,
        appliesTo: ProductCategory.home5g,
      ),
      // Credits are not implemented. Never fabricate a loyalty reward.
    ]);
  }

  @override
  Future<Either<Failure, int>> getLoyaltyPoints() async => const Right(0);
}
