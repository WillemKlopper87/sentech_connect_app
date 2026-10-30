import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/invoice_json.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/subscriber_json.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';

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
  // ID check (S4): GET answers either schema; POST 201 answers SubscriberKycOut.
  'subscriber_kyc_none.json': 'KycNoneOut',
  'subscriber_kyc_pending.json': 'SubscriberKycOut',
  'voucher_redeem_ok.json': 'RedeemOut',
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
  'OrderOut': {'id', 'status', 'total', 'lines'},
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
  'ProblemDetail': {'code', 'title', 'detail', 'request_id'},
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
}
