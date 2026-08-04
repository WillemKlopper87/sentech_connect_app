import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/faq.dart';

/// Real implementation queries Sentech's CRM/knowledge-base API
/// (see docs/reconciled-spec.md Module G). WhatsApp and email-ticket
/// actions are device-level intents (url_launcher), handled directly in
/// the presentation layer rather than through this repository — there's
/// no backend call to make, just handing off to an installed app.
abstract class SupportRepository {
  Future<Either<Failure, List<Faq>>> getFaqs();
}
