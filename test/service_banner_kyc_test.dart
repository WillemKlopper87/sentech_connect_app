import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_banner.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/service_detail_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/services_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_banner_view.dart';

import 'helpers/pump_themed.dart';
import 'helpers/subscriber_service_fixtures.dart';
import 'subscriber_services_cubit_test.dart' show FakeSubscriberRepository;

const _checking = ServiceBanner(ServiceBannerKind.kycChecking, ServiceBannerAction.none);

class _Kyc implements KycRepository {
  KycStatus? status;
  Failure? failure;
  var calls = 0;

  @override
  Future<Either<Failure, KycRecord?>> getStatus() async {
    calls++;
    if (failure != null) return Left(failure!);
    final s = status;
    return Right(
      s == null
          ? null
          : KycRecord(
              status: s,
              idType: KycIdType.saId,
              idNumberLast4: '1234',
              consentVersion: '2026-09-29',
              consentAt: DateTime.utc(2026, 10, 1),
            ),
    );
  }

  @override
  Future<Either<Failure, KycRecord>> submit(KycSubmission submission, {required String idempotencyKey}) =>
      throw UnimplementedError();
}

void main() {
  // The pending ID-check state and the suspended-for-ID-check state, against
  // every ID check status (null: none yet, not loaded or unreadable).
  group('kyc_required x ID check status', () {
    const table = <KycStatus?, ServiceBanner>{
      null: ServiceBanner(ServiceBannerKind.kycRequired, ServiceBannerAction.startIdCheck),
      KycStatus.pending: _checking,
      KycStatus.rejected: ServiceBanner(ServiceBannerKind.kycRequired, ServiceBannerAction.startIdCheck),
      KycStatus.verified: ServiceBanner(ServiceBannerKind.activating, ServiceBannerAction.none),
    };
    for (final e in table.entries) {
      test('${e.key} -> ${e.value.kind.name}', () {
        final s = testService(status: ServiceStatus.pending, activationBlocker: ActivationBlocker.kycRequired);
        expect(serviceBannerFor(s, kyc: e.key), e.value);
      });
    }

    test('verified on fixed wireless: the provider is setting it up', () {
      final s = testService(
        status: ServiceStatus.pending,
        kind: SubscriberPlanKind.fixedWireless,
        activationBlocker: ActivationBlocker.kycRequired,
      );
      expect(serviceBannerFor(s, kyc: KycStatus.verified), const ServiceBanner(ServiceBannerKind.providerSettingUp, ServiceBannerAction.none));
    });
  });

  group('suspended for the ID check x ID check status', () {
    const table = <KycStatus?, ServiceBanner>{
      null: ServiceBanner(ServiceBannerKind.suspendedKyc, ServiceBannerAction.startIdCheck),
      KycStatus.pending: _checking,
      KycStatus.rejected: ServiceBanner(ServiceBannerKind.suspendedKyc, ServiceBannerAction.startIdCheck),
      KycStatus.verified: ServiceBanner(ServiceBannerKind.suspendedByProvider, ServiceBannerAction.none),
    };
    for (final e in table.entries) {
      test('${e.key} -> ${e.value.kind.name}', () {
        final s = testService(status: ServiceStatus.suspended, suspendReason: SuspendReason.kyc);
        expect(serviceBannerFor(s, kyc: e.key), e.value);
      });
    }
  });

  group('every other blocker and reason ignores the ID check status', () {
    final others = <SubscriberService>[
      for (final b in ActivationBlocker.values)
        if (b != ActivationBlocker.kycRequired) testService(status: ServiceStatus.pending, activationBlocker: b),
      testService(status: ServiceStatus.pending),
      testService(status: ServiceStatus.pending, kind: SubscriberPlanKind.fixedWireless),
      for (final r in SuspendReason.values)
        if (r != SuspendReason.kyc) testService(status: ServiceStatus.suspended, suspendReason: r),
      testService(status: ServiceStatus.suspended),
      testService(),
      testService(status: ServiceStatus.cancelled),
    ];
    for (final s in others) {
      for (final kyc in [null, ...KycStatus.values]) {
        test('${s.status.name} ${s.activationBlocker?.name ?? s.suspendReason?.name ?? '-'} with $kyc', () {
          expect(serviceBannerFor(s, kyc: kyc), serviceBannerFor(s));
          expect(serviceBannerUsesKyc(s), isFalse);
        });
      }
    }
  });

  test('only the two ID-check states read the ID check status', () {
    expect(serviceBannerUsesKyc(testService(status: ServiceStatus.pending, activationBlocker: ActivationBlocker.kycRequired)), isTrue);
    expect(serviceBannerUsesKyc(testService(status: ServiceStatus.suspended, suspendReason: SuspendReason.kyc)), isTrue);
    // A blocker on an active service is ignored.
    expect(serviceBannerUsesKyc(testService(activationBlocker: ActivationBlocker.kycRequired)), isFalse);
  });

  group('cubits', () {
    final waiting = testService(id: 'w', status: ServiceStatus.pending, activationBlocker: ActivationBlocker.kycRequired);
    final active = testService(id: 'a');

    test('the services list reads the ID check once when a banner needs it', () async {
      final kyc = _Kyc()..status = KycStatus.pending;
      final cubit = ServicesCubit(FakeSubscriberRepository(services: [waiting, active]), kyc: kyc);
      await cubit.stream.firstWhere((s) => s.status == ServicesStatus.loaded && s.kycStatus != null);
      expect(cubit.state.kycStatus, KycStatus.pending);
      expect(kyc.calls, 1);
      await cubit.close();
    });

    test('no banner needs it: the ID check is not read at all', () async {
      final kyc = _Kyc()..status = KycStatus.pending;
      final cubit = ServicesCubit(FakeSubscriberRepository(services: [active]), kyc: kyc);
      await cubit.stream.firstWhere((s) => s.status == ServicesStatus.loaded);
      await Future<void>.delayed(Duration.zero);
      expect(kyc.calls, 0);
      expect(cubit.state.kycStatus, isNull);
      await cubit.close();
    });

    test('an unreadable or missing ID check keeps the generic banner', () async {
      final kyc = _Kyc()..failure = const NetworkFailure();
      final cubit = ServicesCubit(FakeSubscriberRepository(services: [waiting]), kyc: kyc);
      await cubit.stream.firstWhere((s) => s.status == ServicesStatus.loaded);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.kycStatus, isNull);
      expect(serviceBannerFor(waiting, kyc: cubit.state.kycStatus)!.kind, ServiceBannerKind.kycRequired);
      kyc
        ..failure = null
        ..status = null;
      await cubit.load();
      expect(cubit.state.kycStatus, isNull);
      await cubit.close();
    });

    test('without a KYC repository the services list works as before', () async {
      final cubit = ServicesCubit(FakeSubscriberRepository(services: [waiting]));
      await cubit.stream.firstWhere((s) => s.status == ServicesStatus.loaded);
      expect(cubit.state.kycStatus, isNull);
      await cubit.close();
    });

    test('the service detail reads it for a suspended-for-ID-check service', () async {
      final kyc = _Kyc()..status = KycStatus.pending;
      final suspended = testService(id: 's', status: ServiceStatus.suspended, suspendReason: SuspendReason.kyc);
      final cubit = ServiceDetailCubit(FakeSubscriberRepository(services: [suspended]), 's', kyc: kyc);
      await cubit.stream.firstWhere((s) => s.kycStatus != null);
      expect(cubit.state.kycStatus, KycStatus.pending);
      expect(cubit.state.service!.id, 's');
      await cubit.close();
    });

    test('the service detail of an active service does not read it', () async {
      final kyc = _Kyc()..status = KycStatus.pending;
      final cubit = ServiceDetailCubit(FakeSubscriberRepository(services: [active]), 'a', kyc: kyc);
      await cubit.stream.firstWhere((s) => s.status == ServiceDetailStatus.loaded);
      await Future<void>.delayed(Duration.zero);
      expect(kyc.calls, 0);
      await cubit.close();
    });
  });

  group('ServiceBannerView', () {
    final waiting = testService(status: ServiceStatus.pending, activationBlocker: ActivationBlocker.kycRequired);

    testWidgets('pending ID check: "We are checking your ID" and no ID check button', (tester) async {
      await pumpThemed(tester, Scaffold(body: ServiceBannerView(waiting, kycStatus: KycStatus.pending)));
      expect(find.textContaining('We are checking your ID'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('no status: the generic ID check message stays', (tester) async {
      await pumpThemed(tester, Scaffold(body: ServiceBannerView(waiting)));
      expect(find.textContaining('We are checking your ID'), findsNothing);
    });
  });
}
