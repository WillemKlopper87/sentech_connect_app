import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/api_operation_scope.dart';
import 'package:sentech_connect_app/core/time/api_date.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

/// Decoders for the subscriber API models. Enums that the API declares closed
/// (`status`, `kind`, ...) fail loudly with [FormatException] on an unknown
/// value (the client turns that into a `ServerFailure`) instead of showing a
/// guess; the contract test lists every value so a platform addition is
/// caught in CI first. The one deliberate exception is `activation_blocker`,
/// which only picks a hint line (see [ActivationBlocker.unknown]).

SubscriberPlanKind planKindFromApi(Object? value) => switch (value) {
  'recurring_hotspot' => SubscriberPlanKind.recurringHotspot,
  'fixed_wireless' => SubscriberPlanKind.fixedWireless,
  final other => throw FormatException('Unknown plan kind $other'),
};

ServiceStatus serviceStatusFromApi(Object? value) => switch (value) {
  'pending' => ServiceStatus.pending,
  'active' => ServiceStatus.active,
  'suspended' => ServiceStatus.suspended,
  'cancelled' => ServiceStatus.cancelled,
  final other => throw FormatException('Unknown service status $other'),
};

SuspendReason? suspendReasonFromApi(Object? value) => switch (value) {
  null => null,
  'non_payment' => SuspendReason.nonPayment,
  'customer_request' => SuspendReason.customerRequest,
  'admin' => SuspendReason.admin,
  'kyc' => SuspendReason.kyc,
  final other => throw FormatException('Unknown suspend reason $other'),
};

ActivationBlocker? activationBlockerFromApi(Object? value) => switch (value) {
  null => null,
  'first_invoice_unpaid' => ActivationBlocker.firstInvoiceUnpaid,
  'customer_link_required' => ActivationBlocker.customerLinkRequired,
  'service_contract_required' => ActivationBlocker.serviceContractRequired,
  'kyc_required' => ActivationBlocker.kycRequired,
  'awaiting_installation' => ActivationBlocker.awaitingInstallation,
  _ => ActivationBlocker.unknown,
};

int _priceCents(Object? price) {
  final map = price! as Map;
  if (map['currency'] != 'ZAR') throw FormatException('Unsupported currency ${map['currency']}');
  return map['amount_cents']! as int;
}

DateTime _instant(Object? value) => DateTime.parse(value! as String).toUtc();

DateTime? _instantOrNull(Object? value) => value == null ? null : _instant(value);

/// `PublicPlanOut` -> [SubscriberPlan].
SubscriberPlan subscriberPlanFromJson(Map<String, Object?> json) => SubscriberPlan(
  id: json['id']! as String,
  code: json['code']! as String,
  name: json['name']! as String,
  description: json['description']! as String,
  kind: planKindFromApi(json['kind']),
  kycRequired: json['kyc_required']! as bool,
  priceCents: _priceCents(json['price']),
  setupFeeCents: json['setup_fee_cents']! as int,
  downKbps: json['down_kbps']! as int,
  upKbps: json['up_kbps']! as int,
  maxDevices: json['max_devices']! as int,
  fupAction: json['fup_action']! as String,
  burstDownKbps: json['burst_down_kbps'] as int?,
  burstUpKbps: json['burst_up_kbps'] as int?,
  burstSeconds: json['burst_seconds'] as int?,
  fupBytes: json['fup_bytes'] as int?,
  fupDownKbps: json['fup_down_kbps'] as int?,
  fupUpKbps: json['fup_up_kbps'] as int?,
);

/// `SubscriberAccountOut` -> [SubscriberAccount].
SubscriberAccount subscriberAccountFromJson(Map<String, Object?> json) {
  final counts = Map<String, Object?>.from(json['service_counts']! as Map);
  final profile = json['profile'];
  return SubscriberAccount(
    id: json['id']! as String,
    accountNo: json['account_no']! as String,
    kind: switch (json['kind']) {
      'individual' => SubscriberAccountKind.individual,
      'business' => SubscriberAccountKind.business,
      final other => throw FormatException('Unknown account kind $other'),
    },
    status: switch (json['status']) {
      'active' => SubscriberAccountStatus.active,
      'closed' => SubscriberAccountStatus.closed,
      final other => throw FormatException('Unknown account status $other'),
    },
    serviceCounts: ServiceCounts(
      pending: counts['pending'] as int? ?? 0,
      active: counts['active'] as int? ?? 0,
      suspended: counts['suspended'] as int? ?? 0,
      cancelled: counts['cancelled'] as int? ?? 0,
    ),
    profile: profile == null ? null : _profileFromJson(Map<String, Object?>.from(profile as Map)),
  );
}

SubscriberProfile _profileFromJson(Map<String, Object?> json) {
  final language = json['language']! as String;
  if (!const {'en', 'zu', 'af'}.contains(language)) throw FormatException('Unknown language $language');
  return SubscriberProfile(
    displayName: json['display_name']! as String,
    email: json['email'] as String?,
    phoneE164: json['phone_e164'] as String?,
    language: language,
  );
}

/// `CustomerServiceOut` -> [SubscriberService]. The deprecated
/// `pending_plan_version_id` is not read.
SubscriberService subscriberServiceFromJson(Map<String, Object?> json) => SubscriberService(
  id: json['id']! as String,
  accountId: json['account_id']! as String,
  serviceNo: json['service_no']! as String,
  status: serviceStatusFromApi(json['status']),
  suspendReason: suspendReasonFromApi(json['suspend_reason']),
  activationBlocker: activationBlockerFromApi(json['activation_blocker']),
  planId: json['plan_id']! as String,
  planName: json['plan_name']! as String,
  kind: planKindFromApi(json['kind']),
  priceCents: _priceCents(json['price']),
  downKbps: json['down_kbps']! as int,
  upKbps: json['up_kbps']! as int,
  billedThrough: parseApiDateOrNull(json['billed_through']),
  paidThrough: parseApiDateOrNull(json['paid_through']),
  createdAt: _instant(json['created_at']),
  activatedAt: _instantOrNull(json['activated_at']),
  suspendedAt: _instantOrNull(json['suspended_at']),
  cancelledAt: _instantOrNull(json['cancelled_at']),
  cancelEffectiveOn: parseApiDateOrNull(json['cancel_effective_on']),
  pendingPlanId: json['pending_plan_id'] as String?,
  pendingPlanName: json['pending_plan_name'] as String?,
  planChangeOn: parseApiDateOrNull(json['plan_change_on']),
);

/// Reads every page of a cursor list, up to [maxPages], stopping with a
/// [ServerFailure] when the API repeats a cursor (never loops).
Future<Either<Failure, List<T>>> fetchAllPages<T>(
  ApiClient api, {
  required String path,
  required String cursorParam,
  required T Function(Map<String, Object?>) item,
  required ApiOperationScope scope,
  required bool authenticated,
  Map<String, Object?> query = const {},
  int pageSize = 50,
  int maxPages = 10,
}) async {
  const incomplete = ServerFailure('We could not load everything. Please try again.');
  final all = <T>[];
  final seen = <String>{};
  String? cursor;
  for (var page = 0; page < maxPages; page++) {
    final result = await api.get<(List<T>, String?)>(
      path,
      scope: scope,
      authenticated: authenticated,
      timeout: const Duration(seconds: 15),
      query: {...query, 'limit': pageSize, cursorParam: ?cursor},
      decode: (data) {
        final map = data! as Map;
        return (
          [for (final raw in map['items']! as List) item(Map<String, Object?>.from(raw as Map))],
          map['next_cursor'] as String?,
        );
      },
    );
    switch (result) {
      case Left(value: final failure):
        return Left(failure);
      case Right(value: (final items, final next)):
        all.addAll(items);
        cursor = next;
    }
    if (cursor == null) return Right(all);
    if (!seen.add(cursor)) return const Left(incomplete);
  }
  return const Left(incomplete);
}
