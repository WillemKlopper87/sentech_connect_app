import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/support/data/support_tickets_json.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_tickets_repository.dart';

/// The customer's ticket routes (`/v1/me/tickets*`, customer token) and the
/// public incidents route. Every ticket route answers 409 `feature_disabled`
/// when the `ticketing` flag is off and 403 `module_not_enabled` when the
/// `tickets` module is off; a server older than the routes answers 404. All
/// three map to [TicketsNotAvailableFailure], so the screens hide the feature
/// instead of crashing or showing an empty page.
///
/// Limits (server): a ticket or message body is 1 to 4000 characters, 5 new
/// tickets and 30 messages per customer per hour (429 with `Retry-After`).
/// `Idempotency-Key` is required on create and reply. Nothing the customer
/// wrote is logged here: the request log carries the method and path only, and
/// the scrubber masks a ticket reference in that path.
class HttpSupportTicketsRepository implements SupportTicketsRepository {
  HttpSupportTicketsRepository(this._api, {required this._tenant, this._onModuleRefused});

  final ApiClient _api;
  final TenantContext _tenant;

  /// Told `tickets` when the provider has the flag off (409 `feature_disabled`), so the
  /// entry is hidden at once, as the `ApiClient` already does for 403 `module_not_enabled`.
  final void Function(String module)? _onModuleRefused;

  static const ticketsPath = '/v1/me/tickets';
  static const categoriesPath = '/v1/me/tickets/categories';
  static const incidentsPath = '/v1/support/incidents';

  /// The server's own pattern for a reference (`^[A-Z]{3}-[A-Z0-9]{8}$`).
  static final _reference = RegExp(r'^[A-Z]{3}-[A-Z0-9]{8}$');

  Failure _unavailable(Failure failure) {
    if (failure is FeatureDisabledFailure) _onModuleRefused?.call('tickets');
    return switch (failure) {
      // A typed "no such ticket" is the customer's own answer; any other 404 is a server without the routes.
      TicketNotFoundFailure() => failure,
      OrderNotFoundFailure() => failure,
      NotFoundFailure() || FeatureDisabledFailure() || ModuleDisabledFailure() => const TicketsNotAvailableFailure(),
      _ => failure,
    };
  }

  static Map<String, Object?> _object(Object? data) => Map<String, Object?>.from(data! as Map);

  static String _path(String reference, [String suffix = '']) => '$ticketsPath/$reference$suffix';

  @override
  Future<Either<Failure, List<TicketCategory>>> categories() async {
    final result = await _api.get<List<TicketCategory>>(
      categoriesPath,
      scope: await _api.captureScope(),
      decode: (data) => ticketCategoriesFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, TicketPage>> list({String? cursor}) async {
    final result = await _api.get<TicketPage>(
      ticketsPath,
      query: {'cursor': ?cursor},
      scope: await _api.captureScope(),
      decode: (data) => ticketPageFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, TicketThread>> get(String reference) async {
    if (!_reference.hasMatch(reference)) return const Left(TicketNotFoundFailure());
    final result = await _api.get<TicketThread>(
      _path(reference),
      scope: await _api.captureScope(),
      decode: (data) => ticketThreadFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, String>> create({
    required String categoryKey,
    required String body,
    String? orderId,
    required String idempotencyKey,
  }) async {
    final result = await _api.post<String>(
      ticketsPath,
      scope: await _api.captureScope(),
      idempotencyKey: idempotencyKey,
      body: {'category': categoryKey, 'body': body, 'order_id': ?orderId},
      decode: (data) {
        final reference = _object(data)['reference'];
        if (reference is! String || reference.isEmpty) throw const FormatException('No reference');
        return reference;
      },
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, Ticket>> reply(String reference, {required String body, required String idempotencyKey}) async {
    if (!_reference.hasMatch(reference)) return const Left(TicketNotFoundFailure());
    final result = await _api.post<Ticket>(
      _path(reference, '/messages'),
      scope: await _api.captureScope(),
      idempotencyKey: idempotencyKey,
      body: {'body': body},
      decode: (data) => ticketFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, Ticket>> close(String reference) async {
    if (!_reference.hasMatch(reference)) return const Left(TicketNotFoundFailure());
    final result = await _api.post<Ticket>(
      _path(reference, '/close'),
      scope: await _api.captureScope(),
      decode: (data) => ticketFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, List<Incident>>> incidents({String? siteId}) async {
    final result = await _api.get<List<Incident>>(
      incidentsPath,
      authenticated: false,
      query: {'tenant': _tenant.slug, 'site_id': ?siteId},
      decode: (data) => incidentsFromJson(_object(data)),
    );
    return result.mapLeft(_unavailable);
  }
}
