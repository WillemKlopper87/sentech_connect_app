import 'package:sentech_connect_app/l10n/app_localizations_en.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';

class MockPromotionsRepository implements PromotionsRepository {
  static final _promotions = [
    Promotion(
      id: 'promo_upgrade',
      isDemoCopy: true,
      title: AppLocalizationsEn().demoPromotion1Title,
      description: AppLocalizationsEn().demoPromotion1Description,
      badge: AppLocalizationsEn().demoPromotion1Badge,
      expiresOn: AppLocalizationsEn().demoPromotion1Expiry,
    ),
    Promotion(
      id: 'promo_referral',
      isDemoCopy: true,
      title: AppLocalizationsEn().demoPromotion2Title,
      description: AppLocalizationsEn().demoPromotion2Description,
      badge: AppLocalizationsEn().demoPromotion2Badge,
      expiresOn: AppLocalizationsEn().demoPromotion2Expiry,
    ),
    Promotion(
      id: 'promo_loyalty',
      isDemoCopy: true,
      title: AppLocalizationsEn().demoPromotion3Title,
      description: AppLocalizationsEn().demoPromotion3Description,
      badge: AppLocalizationsEn().demoPromotion3Badge,
      expiresOn: AppLocalizationsEn().demoPromotion3Expiry,
    ),
  ];

  @override
  Future<Either<Failure, List<Promotion>>> getActivePromotions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Right(_promotions);
  }

  @override
  Future<Either<Failure, int>> getLoyaltyPoints() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const Right(1240);
  }
}
