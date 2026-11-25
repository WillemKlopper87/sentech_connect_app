import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/features/coverage/data/coverage_json.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_result.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

/// The public coverage routes of the customer's provider. None of them takes a
/// session (no token is sent), all carry `tenant`:
///
///  * `GET /v1/coverage/check?lat&lon&tenant`: 60 per minute per client address;
///    422 `outside_service_area` or `coordinates_swapped`; 429 `rate_limited`
///    with `Retry-After`; `public, max-age=60`. A provider with no active
///    dataset still answers 200 (`not_covered`, `dataset_version` null).
///  * `GET /v1/coverage/meta`, `GET /v1/coverage/capabilities`.
///  * `POST /v1/coverage/address` (body `{q}`, 3 to 200 characters; 30 per
///    minute per client, one hit per ladder step): 503 `address_lookup_unavailable`
///    when the deployment has no provider. When `address_lookup` is false the
///    older `GET /v1/geocode/search?q&limit&tenant` is used (the address is then
///    in the query string; the platform drops it from its logs).
///  * `POST /v1/leads` (Idempotency-Key required, human-check token required,
///    10 per hour per client): 202 `{status: received}` for new and repeat
///    sign-ups alike. 422 `consent_required`, `consent_version_outdated`,
///    `invalid_contact`, `outside_service_area`, `idempotency_key_reused`.
///  * `POST /v1/leads/withdrawal-requests` (human-check token): always 202.
///    `POST /v1/leads/withdrawals` is never called by the app (only the link's page does).
///
/// A server older than the routes answers 404 (with or without a problem body):
/// that is [CoverageUnavailableFailure], never a crash.
class HttpCoverageRepository implements CoverageRepository {
  HttpCoverageRepository(
    this._api, {
    required this._tenant,
    required this._humanCheck,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ApiClient _api;
  final TenantContext _tenant;
  final HumanCheckProvider _humanCheck;
  final DateTime Function() _now;

  static const checkPath = '/v1/coverage/check';
  static const metaPath = '/v1/coverage/meta';
  static const capabilitiesPath = '/v1/coverage/capabilities';
  static const addressPath = '/v1/coverage/address';
  static const geocodePath = '/v1/geocode/search';
  static const leadsPath = '/v1/leads';
  static const withdrawalRequestsPath = '/v1/leads/withdrawal-requests';

  /// Legacy single-answer check, removed with the old screen in the same slice.
  @override
  Future<Either<Failure, CoverageResult>> checkAddress(String address) async => const Left(CoverageUnavailableFailure());

  /// How long a read meta is trusted: the consent text versions can change.
  static const metaLifetime = Duration(minutes: 10);

  /// A check or search is abandoned after this long (the answer is a rendering of a
  /// short database read; the server's own limit is 2 seconds).
  static const _readTimeout = Duration(seconds: 15);
  static const _writeTimeout = Duration(seconds: 30);

  ({String tenant, CoverageMeta meta, DateTime at})? _metaCache;
  final _addressLookup = <String, bool>{};

  Failure _unavailable(Failure failure) => switch (failure) {
    NotFoundFailure() || ModuleDisabledFailure() || FeatureDisabledFailure() => const CoverageUnavailableFailure(),
    _ => failure,
  };

  static Map<String, Object?> _object(Object? data) => Map<String, Object?>.from(data! as Map);

  /// The server quantises to 5 decimals (about 1 m) before it looks anything up:
  /// no more precision than that leaves the device.
  static double _round5(double value) => (value * 100000).roundToDouble() / 100000;

  @override
  Future<Either<Failure, CoverageCheck>> check({required double lat, required double lon}) async {
    final result = await _api.get<CoverageCheck>(
      checkPath,
      query: {'lat': _round5(lat), 'lon': _round5(lon), 'tenant': _tenant.slug},
      authenticated: false,
      timeout: _readTimeout,
      decode: (data) => coverageCheckFromJson(_object(data)),
    );
    return result.map((check) {
      // An answer from another dataset version means the meta read earlier is stale.
      final cached = _metaCache;
      if (cached != null && cached.meta.datasetVersion != check.datasetVersion) _metaCache = null;
      return check;
    }).mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, CoverageMeta>> meta({bool refresh = false}) async {
    final slug = _tenant.slug;
    final cached = _metaCache;
    if (!refresh && cached != null && cached.tenant == slug && _now().difference(cached.at) < metaLifetime) {
      return Right(cached.meta);
    }
    final result = await _api.get<CoverageMeta>(
      metaPath,
      query: {'tenant': slug},
      authenticated: false,
      timeout: _readTimeout,
      decode: (data) => coverageMetaFromJson(_object(data)),
    );
    return result.map((meta) {
      _metaCache = (tenant: slug, meta: meta, at: _now());
      return meta;
    }).mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, bool>> addressLookupAvailable() async {
    final slug = _tenant.slug;
    final known = _addressLookup[slug];
    if (known != null) return Right(known);
    final result = await _api.get<bool>(
      capabilitiesPath,
      authenticated: false,
      timeout: _readTimeout,
      decode: (data) => _object(data)['address_lookup'] == true,
    );
    return result.match(
      // An older server has no capabilities route: the older search is used.
      (failure) => failure is NotFoundFailure ? _remember(slug, false) : Left(failure),
      (available) => _remember(slug, available),
    );
  }

  Either<Failure, bool> _remember(String slug, bool available) {
    _addressLookup[slug] = available;
    return Right(available);
  }

  @override
  Future<Either<Failure, AddressSearchResult>> search(String query) async {
    final available = await addressLookupAvailable();
    final lookup = available.match((_) => null, (v) => v);
    if (lookup == null) return Left(available.match((f) => f, (_) => const CoverageUnavailableFailure()));
    final slug = _tenant.slug;
    final result = lookup
        // The address is in the body only: never in a URL.
        ? await _api.post<AddressSearchResult>(
            addressPath,
            body: {'q': query},
            authenticated: false,
            timeout: _readTimeout,
            decode: (data) => addressSearchResultFromJson(_object(data)),
            query: {'tenant': slug},
          )
        : await _api.get<AddressSearchResult>(
            geocodePath,
            query: {'q': query, 'limit': 5, 'tenant': slug},
            authenticated: false,
            timeout: _readTimeout,
            decode: (data) => AddressSearchResult(matches: geocodeMatchesFromJson(_object(data))),
          );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, Unit>> submitLead(NotifyRequest request, {required String idempotencyKey}) async {
    final token = await _humanToken();
    final value = token.match((_) => null, (t) => t);
    if (value == null) return Left(token.match((f) => f, (_) => const CoverageUnavailableFailure()));
    final result = await _api.post<Unit>(
      leadsPath,
      authenticated: false,
      idempotencyKey: idempotencyKey,
      timeout: _writeTimeout,
      body: {
        'tenant': _tenant.slug,
        'contact': {'type': request.contactType.name, 'value': request.contactValue},
        'address_text': request.addressText,
        'lat': request.lat,
        'lon': request.lon,
        'technology_interest': switch (request.technologyInterest) {
          TechnologyInterest.any => 'any',
          TechnologyInterest.fiveG => '5g',
          TechnologyInterest.lte => 'lte',
        },
        'consent': {'granted': true, 'version': request.waitlistConsentVersion},
        'arrival_consent': {'granted': request.arrivalConsentGranted, 'version': request.arrivalConsentVersion},
        'source': 'app',
        'turnstile_token': value,
      },
      decode: (_) => unit,
    );
    return result.mapLeft(_unavailable);
  }

  @override
  Future<Either<Failure, Unit>> requestWithdrawal(WithdrawalRequest request) async {
    final token = await _humanToken();
    final value = token.match((_) => null, (t) => t);
    if (value == null) return Left(token.match((f) => f, (_) => const CoverageUnavailableFailure()));
    final result = await _api.post<Unit>(
      withdrawalRequestsPath,
      authenticated: false,
      timeout: _writeTimeout,
      body: {
        'tenant': _tenant.slug,
        'contact': {'type': request.contactType.name, 'value': request.contactValue},
        'turnstile_token': value,
      },
      decode: (_) => unit,
    );
    return result.mapLeft(_unavailable);
  }

  /// A fresh human-check token for ONE request; with no widget on the
  /// deployment (dev stacks) the public dev pass, as the support message does.
  Future<Either<Failure, String>> _humanToken() async {
    final check = await acquireHumanCheck(_humanCheck);
    return check.map((token) => token ?? devTurnstilePass);
  }
}
