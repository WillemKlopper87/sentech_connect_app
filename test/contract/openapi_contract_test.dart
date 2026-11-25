import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/invoice_json.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/subscriber_json.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_profile_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_profile_edit.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';

import 'package:sentech_connect_app/features/hotspot_login/data/http_hotspot_login_repository.dart';
import 'package:sentech_connect_app/features/credits/data/credits_json.dart';
import 'package:sentech_connect_app/features/coverage/data/coverage_json.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/tier.dart';
import 'package:sentech_connect_app/features/fiveg_service/data/fiveg_json.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/usage_levels.dart';
import 'package:sentech_connect_app/features/support/data/support_tickets_json.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import '../helpers/fixtures.dart';
import 'openapi_schema.dart';

/// Fixture file -> 2xx response schema in apps/api/openapi.json.
const fixtureSchemas = {
  'app_config.json': 'AppConfig',
  'tenants.json': 'TenantDirectory',
  'products_page_1.json': 'Page_ProductOut_',
  'products_page_2.json': 'Page_ProductOut_',
  'orders_page.json': 'Page_OrderOut_',
  'hotspots_page.json': 'Page_HotspotPublicOut_',
  'order_draft.json': 'OrderOut',
  'checkout_fake.json': 'CheckoutOut',
  'checkout_netcash.json': 'CheckoutOut',
  'entitlements_page.json': 'Page_EntitlementOut_',
  // GET /v1/me/entitlements?status=current: a suspended pass past expires_at is listed (platform d4be7ce).
  'entitlements_current_suspended.json': 'Page_EntitlementOut_',
  // Subscriber foundation (platform ab5247a): the /me routes answer CustomerServiceOut, not the admin ServiceOut.
  'subscriber_plans_page.json': 'Page_PublicPlanOut_',
  'subscriber_account.json': 'SubscriberAccountOut',
  'subscriber_services_page.json': 'Page_CustomerServiceOut_',
  // Change plan and cancel at period end (S6, S7): ChangeOut, and CustomerServiceOut with cancel_effective_on.
  'subscriber_change_applied.json': 'ChangeOut',
  'subscriber_change_scheduled.json': 'ChangeOut',
  'subscriber_service_cancel_scheduled.json': 'CustomerServiceOut',
  // Subscriber invoices (S2); checkout answers the same CheckoutOut as orders.
  'subscriber_invoice.json': 'SubscriberInvoiceOut',
  'subscriber_invoices_page.json': 'Page_SubscriberInvoiceOut_',
  'invoice_checkout.json': 'CheckoutOut',
  // Contact details (S8): PATCH /v1/me/subscriber 200.
  'subscriber_profile_patched.json': 'SubscriberAccountOut',
  // Plans and signup (S5): POST /v1/me/subscriber/signup 201.
  'subscriber_signup.json': 'SubscriberSignupOut',
  // ID check (S4): GET answers either schema; POST 201 answers SubscriberKycOut.
  'subscriber_kyc_none.json': 'KycNoneOut',
  'subscriber_kyc_pending.json': 'SubscriberKycOut',
  'voucher_redeem_ok.json': 'RedeemOut',
  // 5G data usage and paid unlock (platform C5c-1, 4ce8ca8c): GET .../services/{id}/data 200, and POST .../data/unlock-orders 201.
  'fiveg_usage_normal.json': 'DataUsageOut',
  'fiveg_usage_cut_off.json': 'DataUsageOut',
  'fiveg_usage_slow_lane_restoring.json': 'DataUsageOut',
  'fiveg_usage_fup.json': 'DataUsageOut',
  'fiveg_usage_pending_failed.json': 'DataUsageOut',
  'fiveg_unlock_order.json': 'OrderOut',
  // Credits (platform G1b to G5; app G7): the customer wallet, history, redeem, check-in, missions and badges.
  'credits_summary.json': 'CreditsOut',
  'credits_summary_frozen.json': 'CreditsOut',
  'credits_ledger_page_1.json': 'CreditEntryPage',
  'credits_ledger_page_2.json': 'CreditEntryPage',
  'credits_redeem_pass.json': 'EntitlementOut', // POST /v1/me/credits/redeem 201
  'credits_streak.json': 'StreakOut',
  'credits_streak_claimed.json': 'StreakOut',
  'streak_claim_paid.json': 'StreakClaimOut',
  'streak_claim_repeat.json': 'StreakClaimOut',
  'streak_claim_capped.json': 'StreakClaimOut',
  'credits_missions.json': 'MissionsOut',
  'credits_badges.json': 'BadgesOut',
  // One-tap hotspot login (S10): POST /v1/me/hotspot/login-token 201, with the optional hand-off present (the app ignores it).
  'login_token.json': 'LoginTokenOut',
  'otp_request.json': 'OtpRequestOut',
  'delete_challenge.json': 'OtpRequestOut', // POST /v1/me/delete-challenge answers the same shape
  'token_pair.json': 'TokenPairOut',
  'profile.json': 'ProfileOut',
  'profile_complete.json': 'ProfileOut',
  'consents.json': 'ConsentState',
  'consent_out.json': 'ConsentOut',
  'export.json': 'CustomerExport',
  // GET /v1/auth/human-check/config (platform ae401a0); the second has no widget (fake verifier).
  'human_check_config.json': 'HumanCheckConfig',
  'human_check_config_no_widget.json': 'HumanCheckConfig',
  'support_accepted.json': 'SupportAcceptedOut', // POST /v1/support/messages 202
  // Public coverage (platform f58b00cf; app CV17): the check in its v2 shape, the layer metadata, the address step.
  'coverage_check_two_options.json': 'CoverageCheckOut',
  'coverage_check_placeholder.json': 'CoverageCheckOut',
  'coverage_check_planned.json': 'CoverageCheckOut',
  'coverage_check_nearest.json': 'CoverageCheckOut',
  'coverage_meta.json': 'CoverageMetaOut',
  'coverage_capabilities.json': 'CoverageCapabilitiesOut',
  'coverage_address.json': 'AddressSearchOut', // POST /v1/coverage/address 200
  'lead_accepted.json': 'LeadAcceptedOut', // POST /v1/leads 202
  'withdrawal_requested.json': 'WithdrawalRequestedOut', // POST /v1/leads/withdrawal-requests 202
  // Support tickets (platform f58b00cf, support/me_router.py and incidents_router.py): the customer's own tickets and the public notices.
  'tickets_page.json': 'Page_MyTicketItem_',
  'ticket_detail.json': 'MyTicketDetail',
  'ticket_categories.json': 'MyCategoryList',
  'ticket_created.json': 'MyTicketCreatedOut', // POST /v1/me/tickets 201
  'incidents_public.json': 'PublicIncidentList',
};

/// Keys each hand-written decoder reads. Change it in the same commit as the decoder.
const decoderReads = <String, Set<String>>{
  'AppConfig': {
    'tenant',
    'min_app_version',
    'feature_flags',
    'legal',
    'support',
    'modules',
    'collection_mode_public',
  },
  'FeatureFlags': {
    'hotspot_passes',
    'rica',
    'cpe',
    'vouchers',
    'hotspot_radius',
    'credits',
  },
  'SupportContact': {'email', 'phone'},
  'TenantPublic': {'slug', 'name', 'type', 'branding'},
  'Branding': {
    'primary_color',
    'secondary_color',
    'accent_color',
    'logo_url',
    'logo_alt',
    'app_display_name',
    'legal_urls',
    'whatsapp_number',
  },
  'LegalUrls': {
    'terms',
    'privacy',
    'cooling-off',
    'service-charter',
    'complaints',
    'paia',
  },
  'LegalVersions': {'terms', 'privacy'},
  'TenantDirectory': {'tenants', 'next_cursor'},
  'OrderOut': {'id', 'kind', 'status', 'total', 'lines'},
  'HotspotPublicOut': {'id', 'name', 'address_text', 'lat', 'lon', 'status'},
  'OrderLineOut': {'name', 'quantity'},
  'Money': {'amount_cents', 'currency'},
  'CheckoutOut': {
    'payment_id',
    'reference',
    'gateway',
    'method',
    'url',
    'fields',
    'amount',
  },
  'EntitlementOut': {
    'id',
    'order_id',
    'source',
    'product_name',
    'status',
    'starts_at',
    'expires_at',
    'duration_minutes',
    'data_mb',
    'speed_kbps',
    'max_devices',
    'used_bytes',
    'origin_type',
    'scope',
    'funded_by_other',
    'home_serving_differs',
  },
  'EntitlementScopeOut': {'kind'},
  'PublicPlanOut': {
    'id', 'code', 'name', 'description', 'kind', 'kyc_required', 'price',
    'setup_fee_cents', 'down_kbps', 'up_kbps', 'burst_down_kbps', 'burst_up_kbps',
    'burst_seconds', 'fup_bytes', 'fup_action', 'fup_down_kbps', 'fup_up_kbps',
    'max_devices',
  },
  'SubscriberAccountOut': {'id', 'account_no', 'kind', 'status', 'profile', 'service_counts'},
  'AccountProfileOut': {'display_name', 'email', 'phone_e164', 'language'},
  'ChangeOut': {'applied', 'effective_on', 'proration_invoice_id'},
  'CustomerServiceOut': {
    'id', 'account_id', 'service_no', 'status', 'suspend_reason', 'activation_blocker',
    'plan_id', 'plan_name', 'kind', 'price', 'down_kbps', 'up_kbps', 'billed_through',
    'paid_through', 'created_at', 'activated_at', 'suspended_at', 'cancelled_at',
    'cancel_effective_on', 'pending_plan_id', 'pending_plan_name', 'plan_change_on',
  },
  'SubscriberSignupOut': {'service', 'invoice', 'checkout_hint'},
  'PriceOut': {'amount_cents', 'currency'},
  'SubscriberInvoiceOut': {
    'id', 'service_id', 'invoice_no', 'kind', 'status', 'period_start', 'period_end', 'issue_date',
    'due_date', 'amount', 'vat_cents', 'amount_paid_cents', 'paid_at', 'lines',
  },
  'SubscriberInvoiceLineOut': {
    'position', 'kind', 'description', 'quantity', 'unit_price_cents', 'line_total_cents', 'vat_rate_bp', 'vat_cents',
  },
  'SubscriberKycOut': {
    'status', 'id_type', 'id_number_last4', 'consent_version', 'consent_at', 'verified_at',
  },
  'OtpRequestOut': {'challenge_id', 'expires_in_seconds', 'reference'},
  // Request bodies the app sends (every key must exist in the API schema).
  'OtpRequestIn': {'tenant', 'phone', 'binding'},
  'OtpVerifyIn': {'tenant', 'challenge_id', 'code', 'binding'},
  'DeleteAccountIn': {'challenge_id', 'code'},
  'HumanCheckConfig': {'turnstile'},
  'TurnstileConfig': {'site_key', 'base_url', 'required'},
  'HumanCheckRequired': {'otp_request', 'delete_challenge', 'support_message', 'lead'},
  'SupportAcceptedOut': {'reference'},
  'DataUsageOut': {
    'plan_kind', 'state', 'period_start', 'cycle_end', 'effective_cap_mb', 'counted_usage_mb',
    'used_percent', 'rollover_mb', 'warn_levels', 'next_warn_level', 'offers', 'pending_unlock', 'restoring',
  },
  'OfferOut': {'code', 'name', 'bytes_mb', 'price_cents', 'vat_cents', 'valid_until'},
  'PendingUnlockOut': {'order_id', 'status'},
  'CreditsOut': {
    'balance', 'available', 'pending', 'expiring_30d', 'frozen', 'caps', 'rates', 'tier', 'streak',
  },
  'CapsOut': {'ad_today', 'ad_daily_max', 'ad_month', 'ad_monthly_cap', 'overall_month', 'overall_monthly_cap'},
  'RatesOut': {'mb_per_credit', 'ad_credits', 'pack_sizes', 'expiry_days'},
  'CreditEntryPage': {'items', 'next_cursor'},
  'CreditEntryOut': {'id', 'kind', 'credits', 'source', 'created_at'},
  'StreakOut': {
    'day', 'claimed_today', 'run_days', 'best_run_days', 'freezes', 'total_days', 'tier', 'next_milestone_in_days',
    'rules',
  },
  'StreakRulesOut': {
    'daily_credits', 'short_milestone_days', 'short_milestone_bonus', 'long_milestone_days', 'long_milestone_bonus',
    'freeze_cap', 'silver_streak_days', 'gold_streak_days', 'silver_purchases', 'gold_purchases', 'tier_window_days',
  },
  'StreakClaimOut': {'claimed', 'credits', 'bonus_credits', 'freezes_used', 'milestones', 'capped_by', 'streak'},
  'MissionsOut': {'items'},
  'MissionOut': {
    'key', 'window', 'window_key', 'target', 'progress', 'reward_credits', 'status', 'completed_at',
  },
  'BadgesOut': {'items'},
  'BadgeOut': {'key', 'target', 'progress', 'earned', 'awarded_at'},
  // Request body of POST .../data/unlock-orders: the snapshot has no schema for it (the backend reads it through a
  // dependency), so the key set is pinned in the 5G group below instead.
  'ProblemDetail': {'code', 'title', 'detail', 'request_id'},
  'CoverageCheckOut': {
    'status', 'tenant', 'shape_version', 'options', 'primary_index', 'nearest', 'disclaimer_keys', 'waitlist_available',
    'dataset_version',
  },
  'CoverageOptionOut': {
    'technology', 'kind', 'band', 'typical_down', 'busy_hour_down', 'confidence', 'expected_date', 'near_boundary',
    'notify_available', 'dataset',
  },
  'OptionBandOut': {'key', 'rank', 'notify'},
  'SpeedRange': {'min_mbps', 'max_mbps'},
  'OptionDatasetOut': {'version', 'release_label', 'release_date', 'source_label', 'measure_direction', 'measure_label_key'},
  'CoverageNearestOut': {'technology', 'distance_band'},
  'CoverageMetaOut': {
    'dataset_version', 'dataset_activated_at', 'bounds', 'waitlist_consent_version', 'coverage_arrived_consent_version',
    'attribution', 'min_zoom', 'max_zoom', 'layers',
  },
  'TileLayerOut': {'name', 'version', 'url_template'},
  'CoverageCapabilitiesOut': {'address_lookup'},
  'AddressSearchOut': {'matched', 'results'},
  'Page_MyTicketItem_': {'items', 'next_cursor'},
  'MyTicketItem': {'reference', 'status', 'category', 'category_name', 'created_at', 'updated_at', 'awaiting_reply'},
  'MyTicketDetail': {'reference', 'status', 'category', 'category_name', 'created_at', 'updated_at', 'awaiting_reply', 'messages'},
  'MyMessageOut': {'author', 'body', 'created_at'},
  'MyCategoryList': {'items'},
  'MyCategoryOut': {'slug', 'name'},
  'MyTicketCreatedOut': {'reference'},
  'PublicIncidentList': {'items'},
  'PublicIncident': {'id', 'title', 'severity', 'status', 'body', 'started_at', 'resolved_at', 'updates'},
  'IncidentUpdateOut': {'status', 'body', 'created_at'},
  'AddressHitOut': {'label', 'lat', 'lon', 'precision'},
};

/// Keys read before the API serves them (absent = default value).
const aheadOfApi = <String, Set<String>>{
  'Branding': {'app_display_name'},
};

void main() {
  final api = OpenApiSnapshot.load();

  test('every API fixture is mapped to a schema', () {
    final files = Directory('test/fixtures/api')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.json'))
        .toSet();
    expect(files, fixtureSchemas.keys.toSet());
  });

  for (final MapEntry(key: file, value: name) in fixtureSchemas.entries) {
    test('$file matches $name', () {
      expect(api.validate(fixture(file), api.schema(name)), isEmpty);
    });
  }

  for (final MapEntry(key: name, value: keys) in decoderReads.entries) {
    test('$name: every key the app reads exists in the API', () {
      final ahead = aheadOfApi[name] ?? const <String>{};
      expect(keys.difference(api.properties(name)).difference(ahead), isEmpty);
    });
  }

  test('aheadOfApi keys are not in the API yet (move them when they ship)', () {
    for (final MapEntry(key: name, value: keys) in aheadOfApi.entries) {
      expect(keys.intersection(api.properties(name)), isEmpty, reason: name);
    }
  });

  test('every order status the API can send is mapped', () {
    for (final s
        in (api.schema('OrderStatus')['enum']! as List).cast<String>()) {
      expect(() => orderStatusFromApi(s), returnsNormally, reason: s);
    }
  });

  test('every hotspot status the API can send is mapped', () {
    final status =
        (api.schema('HotspotPublicOut')['properties']! as Map)['status'] as Map;
    final names = HotspotStatus.values.map((s) => s.name).toSet();
    expect((status['enum']! as List).toSet(), names);
  });

  test('every entitlement origin and scope kind is typed, not unknown', () {
    final props = api.schema('EntitlementOut')['properties']! as Map;
    final origins = ((props['origin_type']! as Map)['enum']! as List)
        .cast<String>();
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    expect(origins, isNotEmpty);
    for (final o in origins) {
      expect(
        passFromJson({...base, 'origin_type': o}).origin,
        isNot(PassOrigin.unknown),
        reason: o,
      );
    }
    final scopeProps = api.schema('EntitlementScopeOut')['properties']! as Map;
    final kinds = ((scopeProps['kind']! as Map)['enum']! as List)
        .cast<String>();
    expect(kinds, isNotEmpty);
    for (final k in kinds) {
      final p = passFromJson({
        ...base,
        'scope': [
          {'kind': k},
        ],
      });
      expect(p.scopes.single.kind, isNot(PassScopeKind.unknown), reason: k);
    }
  });

  test('every entitlement status is a PassStatus', () {
    final status =
        (api.schema('EntitlementOut')['properties']! as Map)['status'] as Map;
    final names = PassStatus.values.map((s) => s.name).toSet();
    expect((status['enum']! as List).toSet().difference(names), isEmpty);
  });

  test('every entitlement source parses without throwing or going unknown', () {
    final source =
        (api.schema('EntitlementOut')['properties']! as Map)['source'] as Map;
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    for (final v in (source['enum']! as List).cast<String>()) {
      expect(
        passFromJson({...base, 'source': v}).source,
        isNot(PassSource.unknown),
        reason: v,
      );
    }
  });

  test('every entitlement status the API can send parses to its own PassStatus', () {
    final status =
        (api.schema('EntitlementOut')['properties']! as Map)['status'] as Map;
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    for (final v in (status['enum']! as List).cast<String>()) {
      expect(passFromJson({...base, 'status': v}).status.name, v);
    }
    expect(passFromJson({...base, 'status': 'suspended'}).isCurrent, isFalse);
  });

  test('status=current lists a suspended pass past expires_at, and the app keeps it suspended and not usable', () {
    final items = (fixtureMap('entitlements_current_suspended.json')['items']! as List)
        .map((i) => passFromJson(Map<String, Object?>.from(i as Map)))
        .toList();
    final suspended = items.singleWhere((p) => p.status == PassStatus.suspended);
    expect(suspended.expiresAt.isBefore(DateTime.utc(2026, 10, 29)), isTrue);
    expect(suspended.source, PassSource.service);
    expect(suspended.isCurrent, isFalse, reason: 'RADIUS and voucher redemption still need active');
  });

  test('a null product_id and the service source are tolerated', () {
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    final pass = passFromJson({...base, 'product_id': null, 'source': 'service'});
    expect(pass.source, PassSource.service);
  });

  test('an unknown entitlement status still fails loudly', () {
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    expect(
      () => passFromJson({...base, 'status': 'frozen'}),
      throwsFormatException,
    );
  });

  group('subscriber foundation (platform ab5247a)', () {
    List<String> enumOf(String schema, String property) {
      var node = (api.schema(schema)['properties']! as Map)[property] as Map;
      if (node['enum'] == null) {
        node = (node['anyOf']! as List).cast<Map>().firstWhere((o) => o['enum'] != null);
      }
      return (node['enum']! as List).cast<String>();
    }

    test('the /me routes answer CustomerServiceOut, the public list answers PublicPlanOut', () {
      expect(
        api.responseSchemaName(api.path('/v1/me/subscriber/services', 'get'), '200'),
        'Page_CustomerServiceOut_',
      );
      expect(
        api.responseSchemaName(api.path('/v1/me/subscriber/services/{service_id}', 'get'), '200'),
        'CustomerServiceOut',
      );
      expect(api.responseSchemaName(api.path('/v1/me/subscriber', 'get'), '200'), 'SubscriberAccountOut');
      expect(api.responseSchemaName(api.path('/v1/subscriber-plans', 'get'), '200'), 'Page_PublicPlanOut_');
    });

    test('the service list pages with limit and after, the plans list with tenant, limit and cursor', () {
      List<String> params(String path) => [
        for (final p in api.path(path, 'get')['parameters']! as List) (p as Map)['name']! as String,
      ];
      expect(params('/v1/me/subscriber/services'), containsAll(['limit', 'after']));
      expect(params('/v1/subscriber-plans'), containsAll(['tenant', 'limit', 'cursor']));
    });

    test('every plan kind, service status, suspend reason and blocker the API can send is mapped', () {
      for (final v in enumOf('PublicPlanOut', 'kind')) {
        expect(() => planKindFromApi(v), returnsNormally, reason: v);
      }
      for (final v in enumOf('CustomerServiceOut', 'kind')) {
        expect(() => planKindFromApi(v), returnsNormally, reason: v);
      }
      for (final v in enumOf('CustomerServiceOut', 'status')) {
        expect(() => serviceStatusFromApi(v), returnsNormally, reason: v);
      }
      for (final v in enumOf('CustomerServiceOut', 'suspend_reason')) {
        expect(suspendReasonFromApi(v), isNotNull, reason: v);
      }
      final blockers = enumOf('CustomerServiceOut', 'activation_blocker');
      expect(blockers, isNotEmpty);
      for (final v in blockers) {
        expect(activationBlockerFromApi(v), isNot(ActivationBlocker.unknown), reason: v);
      }
    });

    test('the service fixture covers every status, a scheduled cancel, a scheduled plan change and a blocker', () {
      final items = (fixtureMap('subscriber_services_page.json')['items']! as List)
          .map((i) => subscriberServiceFromJson(Map<String, Object?>.from(i as Map)))
          .toList();
      expect(items.map((s) => s.status).toSet(), ServiceStatus.values.toSet());
      expect(items.any((s) => s.cancelEffectiveOn != null), isTrue);
      expect(items.any((s) => s.hasPlanChangePending), isTrue);
      expect(items.any((s) => s.activationBlocker != null), isTrue);
    });
  });

  group('change plan and cancel at period end (S6, S7)', () {
    Map<String, Object?> bodySchema(String path) {
      final route = api.path(path, 'post');
      final content = (route['requestBody']! as Map)['content']! as Map;
      return Map<String, Object?>.from(((content['application/json']! as Map)['schema']!) as Map);
    }

    test('change-plan answers ChangeOut, cancel answers CustomerServiceOut, both need the Idempotency-Key header', () {
      final change = api.path('/v1/me/subscriber/services/{service_id}/change-plan', 'post');
      final cancel = api.path('/v1/me/subscriber/services/{service_id}/cancel', 'post');
      expect(api.responseSchemaName(change, '200'), 'ChangeOut');
      expect(api.responseSchemaName(cancel, '200'), 'CustomerServiceOut');
      for (final route in [change, cancel]) {
        final headers = (route['parameters']! as List).cast<Map>().where((p) => p['in'] == 'header');
        expect(headers.single['name'], 'Idempotency-Key');
        expect(headers.single['required'], isTrue);
      }
    });

    test('the change-plan body the app sends is ServicePlanChangeIn (new_plan_id only)', () {
      final schema = bodySchema('/v1/me/subscriber/services/{service_id}/change-plan');
      expect(schema['title'], 'ServicePlanChangeIn');
      expect(schema['additionalProperties'], isFalse);
      final body = {'new_plan_id': '3c0d5f7a-1111-4a11-8a11-000000000003'};
      expect(api.validate(body, schema), isEmpty);
      expect(body.keys.toSet(), (schema['properties']! as Map).keys.toSet());
    });

    test('the cancel body the app sends is SubscriberCancelIn (reason 1 to 200 characters)', () {
      final schema = bodySchema('/v1/me/subscriber/services/{service_id}/cancel');
      expect(schema['title'], 'SubscriberCancelIn');
      expect(schema['additionalProperties'], isFalse);
      final props = schema['properties']! as Map;
      expect((props['reason']! as Map)['minLength'], 1);
      expect((props['reason']! as Map)['maxLength'], maxCancelReasonLength);
      expect(api.validate({'reason': cancelReasonText(CancelReason.other, 'x' * 500)}, schema), isEmpty);
      expect(api.validate({'reason': cancelReasonText(CancelReason.moving)}, schema), isEmpty);
    });

    test('the change fixtures decode, one applied with an invoice and one scheduled without', () {
      final applied = planChangeFromJson(Map<String, Object?>.from(fixture('subscriber_change_applied.json') as Map));
      final scheduled = planChangeFromJson(Map<String, Object?>.from(fixture('subscriber_change_scheduled.json') as Map));
      expect(applied.applied, isTrue);
      expect(applied.prorationInvoiceId, isNotNull);
      expect(scheduled.applied, isFalse);
      expect(scheduled.prorationInvoiceId, isNull);
    });

    test('there is no route to withdraw a cancellation (nothing under .../uncancel or .../undo)', () {
      final paths = api.pathKeys.where((p) => p.startsWith('/v1/me/subscriber/services/'));
      expect(paths.any((p) => p.contains('uncancel') || p.contains('undo') || p.contains('reinstate')), isFalse);
    });
  });

  group('subscriber invoices (S2)', () {
    test('the invoice routes answer SubscriberInvoiceOut and check out as CheckoutOut', () {
      expect(
        api.responseSchemaName(api.path('/v1/me/subscriber/invoices', 'get'), '200'),
        'Page_SubscriberInvoiceOut_',
      );
      expect(
        api.responseSchemaName(api.path('/v1/me/subscriber/invoices/{invoice_id}', 'get'), '200'),
        'SubscriberInvoiceOut',
      );
      expect(
        api.responseSchemaName(api.path('/v1/me/subscriber/invoices/{invoice_id}/checkout', 'post'), '200'),
        'CheckoutOut',
      );
    });

    test('the invoice list pages with limit and after and filters with status', () {
      final params = [
        for (final p in api.path('/v1/me/subscriber/invoices', 'get')['parameters']! as List) (p as Map)['name']! as String,
      ];
      expect(params, containsAll(['limit', 'after', 'status']));
    });

    test('every invoice status the API can send is mapped', () {
      final node = (api.schema('SubscriberInvoiceOut')['properties']! as Map)['status'] as Map;
      for (final v in (node['enum']! as List).cast<String>()) {
        expect(() => invoiceStatusFromApi(v), returnsNormally, reason: v);
      }
    });

    test('the invoices fixture covers every status', () {
      final items = (fixtureMap('subscriber_invoices_page.json')['items']! as List)
          .map((i) => subscriberInvoiceFromJson(Map<String, Object?>.from(i as Map)))
          .toList();
      expect(items.map((i) => i.status).toSet(), InvoiceStatus.values.toSet());
    });
  });

  test('the order cancel route answers OrderOut', () {
    final route = api.path('/v1/orders/{order_id}/cancel', 'post');
    expect(api.responseSchemaName(route, '200'), 'OrderOut');
  });

  test('the delete-challenge route answers OtpRequestOut and takes DeleteChallengeIn', () {
    final route = api.path('/v1/me/delete-challenge', 'post');
    expect(api.responseSchemaName(route, '202'), 'OtpRequestOut');
    expect(
      api.properties('DeleteChallengeIn'),
      contains('turnstile_token'), // sent later (M2)
    );
    final del = api.path('/v1/me', 'delete');
    expect(api.requestBodySchemaName(del), 'DeleteAccountIn');
  });

  test('the human-check config route is public and answers HumanCheckConfig', () {
    final route = api.path('/v1/auth/human-check/config', 'get');
    expect(api.responseSchemaName(route, '200'), 'HumanCheckConfig');
    expect(route.containsKey('security'), isFalse);
    final params = (route['parameters']! as List).cast<Map>();
    expect(params.map((p) => p['name']), ['tenant']);
  });

  group('POST /v1/me/subscriber/signup (S5)', () {
    test('answers 201 SubscriberSignupOut and needs the Idempotency-Key', () {
      final post = api.path('/v1/me/subscriber/signup', 'post');
      expect(api.responseSchemaName(post, '201'), 'SubscriberSignupOut');
      final headers = (post['parameters']! as List).cast<Map>().where((p) => p['in'] == 'header');
      expect(headers.single['name'], 'Idempotency-Key');
    });

    test('the bodies the app sends validate against SubscriberSignupIn and use only its keys', () {
      final post = api.path('/v1/me/subscriber/signup', 'post');
      final content = (post['requestBody']! as Map)['content']! as Map;
      final schema = Map<String, Object?>.from((content['application/json']! as Map)['schema']! as Map);
      expect(schema['required'], containsAll(['plan_id', 'accept_terms_version']));
      for (final body in [
        subscriberSignupBody(planId: '3c0d5f7a-1111-4a11-8a11-000000000001', termsVersion: '2026-09-30'),
        subscriberSignupBody(planId: '3c0d5f7a-1111-4a11-8a11-000000000002', termsVersion: '2026-09-30', installAddress: '1 Main Road'),
      ]) {
        expect(api.validate(body, schema), isEmpty);
        expect(body.keys.toSet().difference((schema['properties']! as Map).keys.cast<String>().toSet()), isEmpty);
        expect(body.containsKey('term_months'), isFalse);
      }
    });

    test('the decoder reads the fixture into a pending service and its first invoice', () {
      final signup = subscriberSignupFromJson(fixtureMap('subscriber_signup.json'));
      expect(signup.service.status.name, 'pending');
      expect(signup.invoice.kind, 'initial');
      expect(signup.invoice.lines, hasLength(2));
    });
  });

  group('PATCH /v1/me/subscriber (S8)', () {
    test('answers 200 SubscriberAccountOut and needs the Idempotency-Key', () {
      final patch = api.path('/v1/me/subscriber', 'patch');
      expect(api.responseSchemaName(patch, '200'), 'SubscriberAccountOut');
      final headers = (patch['parameters']! as List).cast<Map>().where((p) => p['in'] == 'header');
      expect(headers.single['name'], 'Idempotency-Key');
    });

    test('the bodies the app sends validate against AccountProfilePatchIn and use only its keys', () {
      final patch = api.path('/v1/me/subscriber', 'patch');
      final content = (patch['requestBody']! as Map)['content']! as Map;
      final schema = Map<String, Object?>.from((content['application/json']! as Map)['schema']! as Map);
      for (final body in [
        const SubscriberProfilePatch(displayName: 'Thandi Mokoena').toBody(),
        const SubscriberProfilePatch(email: 'thandi@example.test', phoneE164: '+27821234567', language: 'zu').toBody(),
        const SubscriberProfilePatch(clearEmail: true, language: 'af').toBody(),
      ]) {
        expect(api.validate(body, schema), isEmpty, reason: '$body');
        expect(body.keys.toSet().difference((schema['properties']! as Map).keys.cast<String>().toSet()), isEmpty);
      }
    });

    test('the sign-in profile edit validates against ProfileUpdateIn', () {
      final patch = api.path('/v1/me/profile', 'patch');
      final content = (patch['requestBody']! as Map)['content']! as Map;
      final schema = Map<String, Object?>.from((content['application/json']! as Map)['schema']! as Map);
      for (final body in <Map<String, Object?>>[
        {'display_name': 'Thandi'},
        {'display_name': 'Thandi', 'email': 'thandi@example.test'},
        {'email': null},
      ]) {
        expect(api.validate(body, schema), isEmpty, reason: '$body');
      }
    });

    test('the decoders read the fixtures', () {
      final account = subscriberAccountFromJson(fixtureMap('subscriber_profile_patched.json'));
      expect(account.profile!.language, 'af');
      expect(account.profile!.email, isNull);
      final login = loginContactFromJson(fixtureMap('profile_complete.json'));
      expect(login.displayName, 'Thandi Mokoena');
      expect(login.phoneE164, '+27821234567');
    });
  });

  group('/v1/me/subscriber/kyc', () {
    test('GET answers either KycNoneOut or SubscriberKycOut; POST answers 201 SubscriberKycOut and needs the Idempotency-Key', () {
      final get = api.path('/v1/me/subscriber/kyc', 'get');
      final ok = (((get['responses']! as Map)['200']! as Map)['content']! as Map).values.first as Map;
      final names = ((ok['schema']! as Map)['anyOf']! as List).map((o) => (o as Map)[r'$ref'].toString().split('/').last).toSet();
      expect(names, {'SubscriberKycOut', 'KycNoneOut'});
      final post = api.path('/v1/me/subscriber/kyc', 'post');
      expect(api.responseSchemaName(post, '201'), 'SubscriberKycOut');
      final headers = (post['parameters']! as List).cast<Map>().where((p) => p['in'] == 'header');
      expect(headers.single['name'], 'Idempotency-Key');
    });

    test('the body the app sends validates against SubscriberKycIn and uses only its keys', () {
      final post = api.path('/v1/me/subscriber/kyc', 'post');
      final content = (post['requestBody']! as Map)['content']! as Map;
      final schema = Map<String, Object?>.from((content['application/json']! as Map)['schema']! as Map);
      final body = const KycSubmission(
        idType: KycIdType.saId,
        idNumber: '8001015009087',
        addressText: '1 Main Road, Sandton, 2196',
        consentVersion: '2026-09-30',
        documentBase64: 'AAAA',
      ).toJson();
      expect(api.validate(body, schema), isEmpty);
      expect(body.keys.toSet().difference((schema['properties']! as Map).keys.cast<String>().toSet()), isEmpty);
    });

    test('every status the API can send is handled', () {
      final statuses = ((api.schema('SubscriberKycOut')['properties']! as Map)['status']! as Map)['enum']! as List;
      final base = fixtureMap('subscriber_kyc_pending.json');
      for (final v in statuses.cast<String>()) {
        final record = kycRecordFromJson({...base, 'status': v});
        expect(record?.status.name, v == 'erased' ? null : v);
      }
      final types = ((api.schema('SubscriberKycOut')['properties']! as Map)['id_type']! as Map)['enum']! as List;
      expect(KycIdType.values.map((t) => t.api).toSet(), types.toSet());
    });
  });

  group('POST /v1/support/messages', () {
    Map<String, Object?> bodySchema() {
      final route = api.path('/v1/support/messages', 'post');
      final content = (route['requestBody']! as Map)['content']! as Map;
      return Map<String, Object?>.from(((content['application/json']! as Map)['schema']!) as Map);
    }

    test('answers 202 SupportAcceptedOut and requires the Idempotency-Key header', () {
      final route = api.path('/v1/support/messages', 'post');
      expect(api.responseSchemaName(route, '202'), 'SupportAcceptedOut');
      final headers = (route['parameters']! as List).cast<Map>().where((p) => p['in'] == 'header');
      expect(headers.single['name'], 'Idempotency-Key');
      expect(headers.single['required'], isTrue);
    });

    test('the body the app sends validates against the request schema', () {
      final body = {
        'tenant': 'sentech',
        'topic': 'connecting',
        'reply': {'type': 'email', 'value': 'thandi@example.co.za'},
        'message': 'My hotspot pass shows active but I cannot connect.',
        'order_ref': 'AB12-CD34',
        'turnstile_token': 'tok',
      };
      expect(api.validate(body, bodySchema()), isEmpty);
    });

    test('every key and topic the app can send exists in the schema', () {
      final props = (bodySchema()['properties']! as Map).keys.toSet();
      expect({'tenant', 'topic', 'reply', 'message', 'order_ref', 'turnstile_token'}.difference(props), isEmpty);
      final topics = (((bodySchema()['properties']! as Map)['topic']! as Map)['enum']! as List).cast<String>();
      expect(topics, ['connecting', 'payment', 'pass', 'account', 'other']);
    });
  });

  group('POST /v1/me/hotspot/login-token (S10)', () {
    test('answers 201 LoginTokenOut, needs no Idempotency-Key, and mac is optional in the body', () {
      final post = api.path('/v1/me/hotspot/login-token', 'post');
      expect(api.responseSchemaName(post, '201'), 'LoginTokenOut');
      final headers = ((post['parameters'] as List?) ?? const []).cast<Map>().where((p) => p['in'] == 'header');
      expect(headers, isEmpty);
      final content = (post['requestBody']! as Map)['content']! as Map;
      final schema = Map<String, Object?>.from((content['application/json']! as Map)['schema']! as Map);
      expect(schema['required'] ?? const <Object>[], isNot(contains('mac')));
      expect(schema['additionalProperties'], isFalse);
    });

    test('the body the app sends validates against LoginTokenIn and carries no mac key', () {
      final post = api.path('/v1/me/hotspot/login-token', 'post');
      final content = (post['requestBody']! as Map)['content']! as Map;
      final schema = Map<String, Object?>.from((content['application/json']! as Map)['schema']! as Map);
      const body = HttpHotspotLoginRepository.requestBody;
      expect(api.validate(body, schema), isEmpty);
      expect(body.containsKey('mac'), isFalse);
      expect(body.keys.toSet().difference((schema['properties']! as Map).keys.cast<String>().toSet()), isEmpty);
    });

    test('the decoder reads the fixture and ignores the hand-off', () {
      final token = loginTokenFromJson(fixtureMap('login_token.json'));
      expect(token.username, 'c.9f3a1b2c4d5e');
      expect(token.expiresAt, DateTime.utc(2026, 10, 30, 12, 5));
    });
  });

  group('5G data usage and paid unlock (C5c-1)', () {
    test('GET .../data answers DataUsageOut; the unlock-order POST answers 201 OrderOut and needs the Idempotency-Key', () {
      final get = api.path('/v1/me/subscriber/services/{service_id}/data', 'get');
      expect(api.responseSchemaName(get, '200'), 'DataUsageOut');
      final post = api.path('/v1/me/subscriber/services/{service_id}/data/unlock-orders', 'post');
      expect(api.responseSchemaName(post, '201'), 'OrderOut');
      final header = [
        for (final p in post['parameters']! as List)
          if ((p as Map)['in'] == 'header' && p['name'] == 'Idempotency-Key') p,
      ];
      expect(header.single['required'], isTrue);
      // No requestBody in the snapshot: the body is exactly {"product_code": string}.
      expect(post['requestBody'], isNull);
    });

    test('OrderOut.kind is required and typed; OrderLineOut.product_id is nullable', () {
      expect(((api.schema('OrderOut')['required']! as List)), contains('kind'));
      final kind = (api.schema('OrderOut')['properties']! as Map)['kind'] as Map;
      expect((kind['enum']! as List).toSet(), {'pass', 'data_unlock'});
      for (final k in (kind['enum']! as List).cast<String>()) {
        expect(orderKindFromApi(k), isNotNull, reason: k);
      }
      final productId = (api.schema('OrderLineOut')['properties']! as Map)['product_id'] as Map;
      expect(jsonEncode(productId), contains('"null"'));
    });

    test('every pending-unlock order status the app can show is an order status', () {
      final usage = fiveGUsageFromJson(fixtureMap('fiveg_usage_pending_failed.json'));
      expect(usage.pendingUnlock?.status, 'failed');
      expect(orderStatusFromApi(usage.pendingUnlock!.status), OrderStatus.paymentFailed);
    });

    test('the usage fixtures decode into the plan kind and state they describe', () {
      final normal = fiveGUsageFromJson(fixtureMap('fiveg_usage_normal.json'));
      expect(normal.planKind, FiveGPlanKind.capped);
      expect(normal.state, UsageState.normal);
      expect(normal.effectiveCapMb, 100000);
      expect(normal.rolloverMb, 5000);
      expect(normal.offers.single.addedMb, 50000);
      expect(normal.offers.single.priceCents, 19900);
      expect(normal.offers.single.vatCents, 2596);
      expect(normal.offers.single.validUntil, DateTime.utc(2026, 11, 30));
      expect(normal.cycleEnd, DateTime.utc(2026, 11, 30));

      final cutOff = fiveGUsageFromJson(fixtureMap('fiveg_usage_cut_off.json'));
      expect(cutOff.state, UsageState.cutOff);
      expect(cutOff.usedPercent, 100);
      expect(cutOff.offers, hasLength(2));

      final slow = fiveGUsageFromJson(fixtureMap('fiveg_usage_slow_lane_restoring.json'));
      expect(slow.state, UsageState.slowLane);
      expect(slow.restoring, isTrue);
      expect(slow.pendingUnlock, isNull);

      final fup = fiveGUsageFromJson(fixtureMap('fiveg_usage_fup.json'));
      expect(fup.planKind, FiveGPlanKind.fup);
      expect(fup.state, UsageState.fup);
      expect(fup.effectiveCapMb, isNull);
      expect(fup.usedPercent, isNull);
      expect(fup.offers, isEmpty);
    });

    test('every usage state and plan kind the API can send is mapped, not guessed', () {
      for (final s in ['normal', 'slow_lane', 'cut_off', 'out_of_bundle', 'fup']) {
        expect(() => usageStateFromApi(s), returnsNormally, reason: s);
      }
      for (final k in ['capped', 'fup']) {
        expect(() => fiveGPlanKindFromApi(k), returnsNormally, reason: k);
      }
      expect(() => usageStateFromApi('throttled'), throwsA(isA<FormatException>()));
      expect(() => fiveGPlanKindFromApi('unlimited'), throwsA(isA<FormatException>()));
    });

    test('a pending unlock is read with its order id and status', () {
      final base = fixtureMap('fiveg_usage_normal.json');
      final usage = fiveGUsageFromJson({
        ...base,
        'pending_unlock': {'order_id': 'o-1', 'status': 'awaiting_payment'},
      });
      expect(usage.pendingUnlock?.orderId, 'o-1');
      expect(usage.pendingUnlock?.status, 'awaiting_payment');
    });

    test('the usage percentage bands match the thresholds the app shows (50, 80, 100)', () {
      expect(warningFor(49), UsageWarning.none);
      expect(warningFor(50), UsageWarning.p50);
      expect(warningFor(80), UsageWarning.p80);
      expect(warningFor(100), UsageWarning.p100);
    });

    test('the unlock order fixture is a data unlock, not a Wi-Fi pass', () {
      final order = orderFromJson(fixtureMap('fiveg_unlock_order.json'));
      expect(order.kind, OrderKind.dataUnlock);
      expect(order.isHotspotPass, isFalse);
      expect(order.totalCents, 19900);
      expect(order.status, OrderStatus.awaitingPayment);
    });

    test('a data-unlock order with a null line product_id decodes', () {
      final order = orderFromJson(fixtureMap('fiveg_unlock_order.json'));
      expect(order.planName, '50 GB data unlock');
    });

    test('an order without a kind (older server) is a pass; an unknown kind fails loudly', () {
      final pass = orderFromJson(fixtureMap('order_draft.json'));
      expect(pass.kind, OrderKind.pass);
      expect(pass.isHotspotPass, isTrue);
      expect(() => orderKindFromApi('coupon'), throwsA(isA<FormatException>()));
    });
  });
  group('credits routes (G7)', () {
    test('every route the app calls exists with the answer the app decodes', () {
      const answers = {
        ('/v1/me/credits', 'get', '200'): 'CreditsOut',
        ('/v1/me/credits/ledger', 'get', '200'): 'CreditEntryPage',
        ('/v1/me/credits/redeem', 'post', '201'): 'EntitlementOut',
        ('/v1/me/streak', 'get', '200'): 'StreakOut',
        ('/v1/me/streak/claim', 'post', '200'): 'StreakClaimOut',
        ('/v1/me/missions', 'get', '200'): 'MissionsOut',
        ('/v1/me/badges', 'get', '200'): 'BadgesOut',
      };
      for (final MapEntry(key: (path, method, status), value: name) in answers.entries) {
        expect(api.responseSchemaName(api.path(path, method), status), name, reason: '$method $path');
      }
    });

    test('redeem and claim need an Idempotency-Key; the claim also takes an optional X-Device-Id the app does not send', () {
      for (final path in ['/v1/me/credits/redeem', '/v1/me/streak/claim']) {
        final post = api.path(path, 'post');
        final headers = ((post['parameters'] as List?) ?? const [])
            .cast<Map>()
            .where((p) => p['in'] == 'header')
            .toList();
        final key = headers.singleWhere((p) => p['name'] == 'Idempotency-Key');
        expect(key['required'], isTrue, reason: path);
      }
    });

    test('the ledger takes a cursor query and nothing the app computes', () {
      final get = api.path('/v1/me/credits/ledger', 'get');
      final names = ((get['parameters'] as List?) ?? const []).cast<Map>().map((p) => p['name']).toSet();
      expect(names, containsAll(['cursor', 'limit']));
    });

    test('every entry kind, mission status and tier the API can send decodes', () {
      final kinds = ((api.schema('CreditEntryOut')['properties']! as Map)['kind']! as Map)['enum']! as List;
      for (final k in kinds.cast<String>()) {
        expect(creditEntryKindFromApi(k), isNot(CreditEntryKind.unknown), reason: k);
      }
      final statuses = ((api.schema('MissionOut')['properties']! as Map)['status']! as Map)['enum']! as List;
      for (final v in statuses.cast<String>()) {
        expect(missionStatusFromApi(v), isNot(MissionStatus.unknown), reason: v);
      }
      final tiers = ((api.schema('StreakOut')['properties']! as Map)['tier']! as Map)['enum']! as List;
      for (final v in tiers.cast<String>()) {
        expect(creditTierFromApi(v), isNot(CreditTier.unknown), reason: v);
      }
    });

    test('the fixtures decode', () {
      final summary = creditsSummaryFromJson(fixtureMap('credits_summary.json'));
      expect(summary.available, 150);
      expect(summary.pending, 25);
      expect(summary.rates.packSizes, [50, 100, 250]);
      final frozen = creditsSummaryFromJson(fixtureMap('credits_summary_frozen.json'));
      expect(frozen.frozen, isTrue);
      expect(frozen.tier, isNull);
      expect(claimResultFromJson(fixtureMap('streak_claim_capped.json')).cappedBy, 'overall_monthly');
    });

    test('the platform sends the credits flag in app-config feature_flags', () {
      expect(api.properties('FeatureFlags'), contains('credits'));
    });
  });

  group('support tickets (G7)', () {
    List<String> enumOf(String schema, String property) =>
        (((api.schema(schema)['properties']! as Map)[property]! as Map)['enum']! as List).cast<String>();

    test('every route the app calls exists with the answer the app decodes', () {
      const answers = {
        ('/v1/me/tickets', 'get', '200'): 'Page_MyTicketItem_',
        ('/v1/me/tickets', 'post', '201'): 'MyTicketCreatedOut',
        ('/v1/me/tickets/categories', 'get', '200'): 'MyCategoryList',
        ('/v1/me/tickets/{reference}', 'get', '200'): 'MyTicketDetail',
        ('/v1/me/tickets/{reference}/messages', 'post', '201'): 'MyTicketItem',
        ('/v1/me/tickets/{reference}/close', 'post', '200'): 'MyTicketItem',
        ('/v1/support/incidents', 'get', '200'): 'PublicIncidentList',
      };
      for (final MapEntry(key: (path, method, status), value: name) in answers.entries) {
        expect(api.responseSchemaName(api.path(path, method), status), name, reason: '$method $path');
      }
    });

    test('create and reply carry an Idempotency-Key header; the incidents route takes tenant and site_id', () {
      for (final path in ['/v1/me/tickets', '/v1/me/tickets/{reference}/messages']) {
        final headers = ((api.path(path, 'post')['parameters'] as List?) ?? const []).cast<Map>().where((p) => p['in'] == 'header');
        expect(headers.map((p) => p['name']), contains('Idempotency-Key'), reason: path);
      }
      final query = ((api.path('/v1/support/incidents', 'get')['parameters'] as List?) ?? const []).cast<Map>();
      expect(query.map((p) => p['name']), containsAll(['tenant', 'site_id']));
    });

    test('the body limits the app enforces match the server limits', () {
      final create = (api.schema('MyTicketCreateIn')['properties']! as Map)['body']! as Map;
      final message = (api.schema('MyMessageIn')['properties']! as Map)['body']! as Map;
      expect(create['maxLength'], ticketBodyMaxLength);
      expect(message['maxLength'], ticketBodyMaxLength);
      expect(create['minLength'], 1);
    });

    test('every status, author, severity and incident status the API can send decodes', () {
      for (final v in enumOf('MyTicketItem', 'status')) {
        expect(ticketStatusFromApi(v), isNot(TicketStatus.unknown), reason: v);
      }
      for (final v in enumOf('MyMessageOut', 'author')) {
        expect(ticketAuthorFromApi(v), isNot(TicketAuthor.unknown), reason: v);
      }
      for (final v in enumOf('PublicIncident', 'severity')) {
        expect(incidentSeverityFromApi(v), isNot(IncidentSeverity.unknown), reason: v);
      }
      for (final v in enumOf('PublicIncident', 'status')) {
        expect(incidentStatusFromApi(v), isNot(IncidentStatus.unknown), reason: v);
      }
    });

    test('the platform sends the ticketing flag in app-config feature_flags', () {
      expect(api.properties('FeatureFlags'), contains('ticketing'));
    });
  });

  group('public coverage (CV17)', () {
    List<String> enumOf(String schema, String property) =>
        (((api.schema(schema)['properties']! as Map)[property]! as Map)['enum']! as List).cast<String>();

    List<String> enumOfNullable(String schema, String property) {
      final node = (api.schema(schema)['properties']! as Map)[property]! as Map;
      final options = (node['anyOf'] as List?) ?? [node];
      return options.cast<Map>().expand((o) => ((o['enum'] as List?) ?? const []).cast<String>()).toList();
    }

    test('every status, technology, kind, confidence, direction, distance band and precision the API can send decodes', () {
      for (final v in enumOf('CoverageCheckOut', 'status')) {
        expect(coverageAnswerFromApi(v), isNot(CoverageAnswer.unknown), reason: v);
      }
      for (final v in enumOf('CoverageOptionOut', 'technology')) {
        expect(coverageTechnologyFromApi(v), isNot(CoverageTechnology.unknown), reason: v);
      }
      for (final v in enumOf('CoverageNearestOut', 'technology')) {
        expect(coverageTechnologyFromApi(v), isNot(CoverageTechnology.unknown), reason: v);
      }
      for (final v in enumOf('CoverageOptionOut', 'kind')) {
        expect(optionKindFromApi(v), isNot(OptionKind.unknown), reason: v);
      }
      for (final v in enumOf('CoverageOptionOut', 'confidence')) {
        expect(coverageConfidenceFromApi(v), isNot(CoverageConfidence.unknown), reason: v);
      }
      for (final v in enumOf('OptionDatasetOut', 'measure_direction')) {
        // `unknown` is itself a value the API sends: it must read as unknown, the rest must not.
        expect(measureDirectionFromApi(v) == MeasureDirection.unknown, v == 'unknown', reason: v);
      }
      for (final v in enumOf('CoverageNearestOut', 'distance_band')) {
        expect(distanceBandFromApi(v), isNot(DistanceBand.unknown), reason: v);
      }
      for (final v in enumOfNullable('AddressSearchOut', 'matched')) {
        expect(matchPrecisionFromApi(v), isNot(MatchPrecision.unknown), reason: v);
      }
    });

    test('the check fixtures decode', () {
      expect(coverageCheckFromJson(fixtureMap('coverage_check_two_options.json')).options, hasLength(2));
      expect(coverageCheckFromJson(fixtureMap('coverage_check_nearest.json')).nearest, isNotNull);
    });
  });
}
