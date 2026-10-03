import 'package:sentech_connect_app/features/support/domain/entities/faq.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

// Only explicitly marked owned demo content is localized. External copy is data.
Faq localizeDemoFaq(Faq faq, AppLocalizations l10n) {
  if (!faq.isDemoCopy) return faq;
  return switch (faq.id) {
    'speed' => Faq(
      id: faq.id,
      question: l10n.demoFaq1Question,
      answer: l10n.demoFaq1Answer,
      isDemoCopy: true,
    ),
    'topup' => Faq(
      id: faq.id,
      question: l10n.demoFaq2Question,
      answer: l10n.demoFaq2Answer,
      isDemoCopy: true,
    ),
    'router-red' => Faq(
      id: faq.id,
      question: l10n.demoFaq3Question,
      answer: l10n.demoFaq3Answer,
      isDemoCopy: true,
    ),
    _ => faq,
  };
}

Promotion localizeDemoPromotion(Promotion promo, AppLocalizations l10n) {
  if (!promo.isDemoCopy) return promo;
  return switch (promo.id) {
    'promo_upgrade' => Promotion(
      id: promo.id,
      title: l10n.demoPromotion1Title,
      description: l10n.demoPromotion1Description,
      badge: l10n.demoPromotion1Badge,
      expiresOn: l10n.demoPromotion1Expiry,
      isDemoCopy: true,
    ),
    'promo_referral' => Promotion(
      id: promo.id,
      title: l10n.demoPromotion2Title,
      description: l10n.demoPromotion2Description,
      badge: l10n.demoPromotion2Badge,
      expiresOn: l10n.demoPromotion2Expiry,
      isDemoCopy: true,
    ),
    'promo_loyalty' => Promotion(
      id: promo.id,
      title: l10n.demoPromotion3Title,
      description: l10n.demoPromotion3Description,
      badge: l10n.demoPromotion3Badge,
      expiresOn: l10n.demoPromotion3Expiry,
      isDemoCopy: true,
    ),
    _ => promo,
  };
}
