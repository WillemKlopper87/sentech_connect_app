import 'package:sentech_connect_app/l10n/app_localizations_en.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/faq.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_repository.dart';

class MockSupportRepository implements SupportRepository {
  static final _faqs = [
    Faq(
      id: 'speed',
      isDemoCopy: true,
      question: AppLocalizationsEn().demoFaq1Question,
      answer: AppLocalizationsEn().demoFaq1Answer,
    ),
    Faq(
      id: 'topup',
      isDemoCopy: true,
      question: AppLocalizationsEn().demoFaq2Question,
      answer: AppLocalizationsEn().demoFaq2Answer,
    ),
    Faq(
      id: 'router-red',
      isDemoCopy: true,
      question: AppLocalizationsEn().demoFaq3Question,
      answer: AppLocalizationsEn().demoFaq3Answer,
    ),
  ];

  @override
  Future<Either<Failure, List<Faq>>> getFaqs() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Right(_faqs);
  }
}
