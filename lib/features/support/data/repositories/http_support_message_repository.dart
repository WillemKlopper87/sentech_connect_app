import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/features/support/domain/entities/support_message.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_message_repository.dart';

/// `POST /v1/support/messages` (202). Public route: no session is sent. The
/// body needs a `turnstile_token`; with no widget on the deployment (dev
/// stacks) the app sends [devTurnstilePass].
class HttpSupportMessageRepository implements SupportMessageRepository {
  HttpSupportMessageRepository(
    this._api, {
    required this._tenant,
    required this._humanCheck,
  });

  final ApiClient _api;
  final TenantContext _tenant;
  final HumanCheckProvider _humanCheck;

  @override
  Future<Either<Failure, SupportReceipt>> send(
    SupportMessageDraft draft, {
    required String idempotencyKey,
  }) async {
    final contact = draft.contactValue;
    if (contact == null) return const Left(InvalidContactFailure());
    if (draft.issue != null) return const Left(InvalidMessageFailure());
    final check = await acquireHumanCheck(_humanCheck);
    final checkFailure = check.match((f) => f, (_) => null);
    if (checkFailure != null) return Left(checkFailure);
    final token = check.match((_) => null, (t) => t);
    return _api.post<SupportReceipt>(
      '/v1/support/messages',
      authenticated: false,
      idempotencyKey: idempotencyKey,
      timeout: const Duration(seconds: 30),
      body: {
        'tenant': _tenant.slug,
        'topic': draft.topic.name,
        'reply': {'type': draft.contactKind.name, 'value': contact},
        'message': draft.trimmedMessage,
        'order_ref': ?draft.orderRefValue,
        'turnstile_token': token ?? devTurnstilePass,
      },
      decode: (data) => SupportReceipt((data! as Map)['reference']! as String),
    );
  }
}
