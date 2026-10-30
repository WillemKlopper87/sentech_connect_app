import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/faq.dart';

/// The FAQ list. There is no FAQ API on the platform, so this stays a mock in
/// both flavors (`stillMockInProd`) and the prod Help tab does not show it.
/// Sending a message is a different, real repository:
/// `SupportMessageRepository` (`POST /v1/support/messages`).
abstract class SupportRepository {
  Future<Either<Failure, List<Faq>>> getFaqs();
}
