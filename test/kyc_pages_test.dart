import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:image/image.dart' as img;
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_document_encoder.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_image_picker.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/kyc_form_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/kyc_form_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/kyc_status_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/kyc_status_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_entries.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';

import 'helpers/pump_themed.dart';
import 'helpers/test_setup.dart';

class _Repo implements KycRepository {
  _Repo({this.status = const Right(null)});
  Either<Failure, KycRecord?> status;
  Either<Failure, KycRecord>? submitReply;
  int submits = 0;
  int loads = 0;

  @override
  Future<Either<Failure, KycRecord?>> getStatus() async {
    loads++;
    return status;
  }

  @override
  Future<Either<Failure, KycRecord>> submit(KycSubmission submission, {required String idempotencyKey}) async {
    submits++;
    return submitReply ?? Right(_record(KycStatus.pending));
  }
}

KycRecord _record(KycStatus status, {DateTime? verifiedAt}) => KycRecord(
  status: status,
  idType: KycIdType.saId,
  idNumberLast4: '9087',
  consentVersion: '2026-09-30',
  consentAt: DateTime.utc(2026, 10, 30, 8),
  verifiedAt: verifiedAt,
);

class _Picker implements IdImagePicker {
  IdImagePickResult result = PickedIdImage(Uint8List.fromList([1]));
  @override
  Future<IdImagePickResult> pick(IdImageSource source) async => result;
}

final Uint8List _png = Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));

Future<({EncodedIdDocument? document, IdDocumentIssue? issue})> _encode(Uint8List _) async =>
    (document: EncodedIdDocument(_png), issue: null);

void main() {
  setUpAppTests();

  Future<void> pumpStatus(WidgetTester tester, _Repo repo, {Future<void> Function()? onOpenForm}) async {
    await pumpThemed(
      tester,
      BlocProvider(
        create: (_) => KycStatusCubit(repo),
        child: KycStatusPage(onOpenForm: onOpenForm ?? () async {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('status page', () {
    testWidgets('none explains what is needed and offers Start', (tester) async {
      await pumpStatus(tester, _Repo());
      expect(find.text('We need to check your ID'), findsOneWidget);
      expect(find.byKey(const Key('kyc-start')), findsOneWidget);
      expect(find.byType(SecureScreen), findsOneWidget);
    });

    testWidgets('pending shows the type and last four, no action and no promised time', (tester) async {
      await pumpStatus(tester, _Repo(status: Right(_record(KycStatus.pending))));
      expect(find.text('We are checking your ID'), findsOneWidget);
      expect(find.text('South African ID number ending in 9087'), findsOneWidget);
      expect(find.byKey(const Key('kyc-start')), findsNothing);
      expect(find.textContaining('hours'), findsNothing);
    });

    testWidgets('verified shows the verification date', (tester) async {
      await pumpStatus(tester, _Repo(status: Right(_record(KycStatus.verified, verifiedAt: DateTime.utc(2026, 10, 31, 10)))));
      expect(find.text('Your ID is verified'), findsOneWidget);
      expect(find.textContaining('Verified on'), findsOneWidget);
      expect(find.byKey(const Key('kyc-start')), findsNothing);
    });

    testWidgets('rejected offers Send again, without an invented reason', (tester) async {
      await pumpStatus(tester, _Repo(status: Right(_record(KycStatus.rejected))));
      expect(find.text('We could not accept your ID check'), findsOneWidget);
      expect(find.text('Send again'), findsOneWidget);
    });

    testWidgets('Start opens the form and the status is read again afterwards', (tester) async {
      final repo = _Repo();
      var opened = 0;
      await pumpStatus(tester, repo, onOpenForm: () async => opened++);
      await tester.tap(find.byKey(const Key('kyc-start')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(repo.loads, 2);
    });

    testWidgets('no account explains instead of failing', (tester) async {
      await pumpStatus(tester, _Repo(status: const Left(SubscriberNotFoundFailure())));
      expect(find.byKey(const Key('kyc-no-account')), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('offline shows the offline message and Retry loads again', (tester) async {
      final repo = _Repo(status: const Left(NetworkFailure()));
      await pumpStatus(tester, repo);
      expect(find.textContaining('offline'), findsOneWidget);
      repo.status = Right(_record(KycStatus.pending));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('We are checking your ID'), findsOneWidget);
    });
  });

  group('form page', () {
    late _Repo repo;
    late _Picker picker;
    var done = 0;
    var settings = 0;

    Future<KycFormCubit> pumpForm(WidgetTester tester, {String? consent = '2026-09-30'}) async {
      late KycFormCubit cubit;
      await pumpThemed(
        tester,
        BlocProvider(
          create: (_) => cubit = KycFormCubit(
            repo,
            picker,
            consentVersion: consent,
            now: () => DateTime.utc(2026, 10, 30, 8),
            newKey: () => 'app-key-1',
            encode: _encode,
          ),
          child: KycFormPage(onDone: () => done++, openSettings: () async => settings++, openPrivacy: (_) async {}),
        ),
        size: const Size(390, 1600),
      );
      await tester.pumpAndSettle();
      return cubit;
    }

    setUp(() {
      repo = _Repo();
      picker = _Picker();
      done = 0;
      settings = 0;
    });

    Future<void> fillValid(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('kyc-id-number')), '8001015009087');
      await tester.enterText(find.byKey(const Key('kyc-address')), '1 Main Road, Sandton');
      await tester.tap(find.byKey(const Key('kyc-choose-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kyc-consent')));
      await tester.pumpAndSettle();
    }

    testWidgets('is capture-protected and starts clean', (tester) async {
      await pumpForm(tester);
      expect(find.byType(SecureScreen), findsOneWidget);
      expect(find.text('Photo of your ID document'), findsOneWidget);
      expect(find.text('Check your ID number.'), findsNothing);
    });

    testWidgets('submitting an empty form shows every problem and sends nothing', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.byKey(const Key('kyc-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Check your ID number.'), findsOneWidget);
      expect(find.text('Check your address.'), findsOneWidget);
      expect(find.text('Add a photo of your ID document.'), findsOneWidget);
      expect(find.text('Please agree to continue.'), findsOneWidget);
      expect(repo.submits, 0);
    });

    testWidgets('the SA ID field accepts only digits, 13 at most', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.byKey(const Key('kyc-id-number')), '80a01 01-5009087999');
      expect(tester.widget<TextField>(find.byKey(const Key('kyc-id-number'))).controller!.text, '8001015009087');
    });

    testWidgets('a valid form sends once and shows the success screen; Done closes', (tester) async {
      await pumpForm(tester);
      await fillValid(tester);
      expect(find.byKey(const Key('kyc-photo-preview')), findsOneWidget);
      await tester.tap(find.byKey(const Key('kyc-submit')));
      await tester.pumpAndSettle();
      expect(repo.submits, 1);
      expect(find.byKey(const Key('kyc-success')), findsOneWidget);
      await tester.tap(find.byKey(const Key('kyc-success-done')));
      expect(done, 1);
    });

    testWidgets('an offline failure keeps the form and the photo, and Retry sends again', (tester) async {
      repo.submitReply = const Left(NetworkFailure());
      await pumpForm(tester);
      await fillValid(tester);
      await tester.tap(find.byKey(const Key('kyc-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kyc-failure')), findsOneWidget);
      expect(find.byKey(const Key('kyc-photo-preview')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('kyc-id-number'))).controller!.text, '8001015009087');
      repo.submitReply = null;
      await tester.tap(find.descendant(of: find.byKey(const Key('kyc-failure')), matching: find.text('Retry')));
      await tester.pumpAndSettle();
      expect(repo.submits, 2);
      expect(find.byKey(const Key('kyc-success')), findsOneWidget);
    });

    testWidgets('a 422 from the platform is shown as customer copy', (tester) async {
      repo.submitReply = const Left(KycInvalidIdFailure());
      await pumpForm(tester);
      await fillValid(tester);
      await tester.tap(find.byKey(const Key('kyc-submit')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('kyc-failure')), matching: find.text('Check your ID number.')), findsOneWidget);
    });

    testWidgets('a denied camera explains, keeps the gallery usable and links to Settings', (tester) async {
      picker.result = const IdImagePickDenied(IdImageSource.camera);
      await pumpForm(tester);
      await tester.tap(find.byKey(const Key('kyc-take-photo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kyc-photo-issue')), findsOneWidget);
      await tester.tap(find.byKey(const Key('kyc-open-settings')));
      expect(settings, 1);
      picker.result = PickedIdImage(Uint8List.fromList([1]));
      await tester.tap(find.byKey(const Key('kyc-choose-photo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kyc-photo-preview')), findsOneWidget);
      expect(find.byKey(const Key('kyc-photo-issue')), findsNothing);
    });

    testWidgets('Replace and Remove work on a chosen photo', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.byKey(const Key('kyc-choose-photo')));
      await tester.pumpAndSettle();
      expect(find.text('Replace photo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('kyc-remove-photo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kyc-photo-preview')), findsNothing);
      expect(find.text('Take a photo'), findsOneWidget);
    });
  });

  group('entry', () {
    test('the ID check row is registered, so the banner button and the Account row appear together', () {
      expect(subscriberEntryRegistered(AppRoutes.kyc), isTrue);
      expect(subscriberAccountEntries().map((e) => e.route), contains(AppRoutes.kyc));
    });
  });
}
