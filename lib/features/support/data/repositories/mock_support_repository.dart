import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/faq.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_repository.dart';

class MockSupportRepository implements SupportRepository {
  static const _faqs = [
    Faq(
      id: 'speed',
      question: 'Why is my speed slower than expected?',
      answer:
          'Speed can dip during peak hours (6–10pm) or if your router is placed near thick walls or other electronics. '
          'Try moving the router to an open, central spot. If it persists after that, report the issue below.',
    ),
    Faq(
      id: 'topup',
      question: 'How do I top up my data?',
      answer:
          'Go to the Shop tab, choose a top-up or voucher, and pay with card, Ozow, or PayShap. '
          'Top-ups apply to your account within a few minutes.',
    ),
    Faq(
      id: 'router-red',
      question: 'My router lights are red',
      answer:
          'A solid red light usually means a signal or power issue. Check the power cable is fully seated, '
          'then wait 2 minutes for the router to reconnect. If it stays red, report the issue below.',
    ),
  ];

  @override
  Future<Either<Failure, List<Faq>>> getFaqs() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const Right(_faqs);
  }
}
