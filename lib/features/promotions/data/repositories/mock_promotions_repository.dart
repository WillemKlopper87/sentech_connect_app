import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';

class MockPromotionsRepository implements PromotionsRepository {
  static const _promotions = [
    Promotion(
      id: 'promo_upgrade',
      title: 'Upgrade and save',
      description: 'Move to Home 100 this month and get your first month at 20% off.',
      badge: '20% OFF',
      expiresOn: '31 Aug',
    ),
    Promotion(
      id: 'promo_referral',
      title: 'Refer a friend',
      description: 'Give a friend a free installation — you both get 10GB bonus data.',
      badge: 'REFERRAL',
      expiresOn: 'Ongoing',
    ),
    Promotion(
      id: 'promo_loyalty',
      title: 'Loyalty reward',
      description: "You've earned enough points for a free Wi-Fi voucher — redeem it in Vouchers.",
      badge: 'LOYALTY',
      expiresOn: '15 Sep',
    ),
  ];

  @override
  Future<Either<Failure, List<Promotion>>> getActivePromotions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const Right(_promotions);
  }

  @override
  Future<Either<Failure, int>> getLoyaltyPoints() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const Right(1240);
  }
}
