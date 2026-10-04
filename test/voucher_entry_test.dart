import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_scanner_page.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_result_sheet.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/widgets/pass_ready_view.dart';

import 'helpers/pump_themed.dart';
import 'helpers/test_setup.dart';

class _FakeVoucherRepository extends VoucherRepository {
  _FakeVoucherRepository(this.reply);

  VoucherRedemption reply;
  final calls = <VoucherCode>[];
  Future<Either<Failure, VoucherRedemption>> Function()? respond;

  @override
  Future<Either<Failure, VoucherRedemption>> redeem(VoucherCode code) async {
    calls.add(code);
    return respond == null ? Right(reply) : await respond!();
  }
}

/// Counts camera starts; never touches a real camera.
class _CountingController extends MobileScannerController {
  _CountingController() : super(autoStart: false);

  int starts = 0;
  int stops = 0;

  @override
  Future<void> start({
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
  }) async {
    starts++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

/// Holds the first stop so a newer entry can overtake a camera result.
class _DelayedStopController extends _CountingController {
  final firstStop = Completer<void>();

  @override
  Future<void> stop() async {
    await super.stop();
    if (stops == 1) await firstStop.future;
  }
}

void main() {
  setUpAppTests();

  test('camera start errors meaning "already starting/started" are benign', () {
    MobileScannerException error(MobileScannerErrorCode code) =>
        MobileScannerException(errorCode: code);
    expect(
      isBenignCameraStartError(
        error(MobileScannerErrorCode.controllerInitializing),
      ),
      isTrue,
    );
    expect(
      isBenignCameraStartError(
        error(MobileScannerErrorCode.controllerAlreadyInitialized),
      ),
      isTrue,
    );
    expect(
      isBenignCameraStartError(error(MobileScannerErrorCode.permissionDenied)),
      isFalse,
    );
    expect(
      isBenignCameraStartError(error(MobileScannerErrorCode.genericError)),
      isFalse,
    );
  });

  late _FakeVoucherRepository repo;

  Future<void> open(WidgetTester tester, VoucherRedemption reply) async {
    repo = _FakeVoucherRepository(reply);
    locator.registerLazySingleton<VoucherRepository>(() => repo);
    await pumpThemed(tester, const VoucherScannerPage());
    await tester.pump();
  }

  Future<void> typeAndSubmit(WidgetTester tester, String text) async {
    await tester.tap(find.text('Type the code instead'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), text);
    // The keyboard's Enter/Done key submits: no extra tap needed.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a real server code typed loosely is sent normalised', (
    tester,
  ) async {
    await open(
      tester,
      const VoucherRedemption(
        VoucherOutcome.redeemed,
        productName: 'Day Pass',
        dataMb: 5120,
      ),
    );
    await typeAndSubmit(tester, 'sen abcd 2345 efgq');
    expect(repo.calls.single.value, 'ABCD2345EFGQ');
    expect(find.text('Day Pass is ready'), findsOneWidget);
    expect(find.byType(PassReadyView), findsOneWidget);
    expect(find.text('Connect to WiFi'), findsOneWidget);
  });

  testWidgets(
    'a refused code shows what was typed, with Check the code and Done',
    (tester) async {
      await open(tester, const VoucherRedemption(VoucherOutcome.invalid));
      await typeAndSubmit(tester, 'abcd2345efgq');

      expect(repo.calls, hasLength(1));
      expect(find.text("That code didn't work"), findsOneWidget);
      expect(find.text('ABCD-2345-EFGQ'), findsOneWidget);
      expect(find.textContaining('••'), findsNothing);
      expect(find.text('Check the code'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Check the code'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      // The entry field is back with the code still in it, ready to fix.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'ABCD-2345-EFGQ');
    },
  );

  testWidgets('manual entry is a bottom sheet and pauses the camera', (
    tester,
  ) async {
    repo = _FakeVoucherRepository(
      const VoucherRedemption(VoucherOutcome.invalid),
    );
    locator.registerLazySingleton<VoucherRepository>(() => repo);
    final camera = _CountingController();
    addTearDown(camera.dispose);
    await pumpThemed(tester, VoucherScannerPage(controller: camera));
    await tester.pump();
    final stops = camera.stops;
    await tester.tap(find.text('Type the code instead'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(camera.stops, stops + 1);
    final starts = camera.starts;
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(camera.starts, starts + 1);
  });

  testWidgets('delayed camera stop cannot show an obsolete result over entry', (
    tester,
  ) async {
    repo = _FakeVoucherRepository(
      const VoucherRedemption(VoucherOutcome.invalid),
    );
    locator.registerLazySingleton<VoucherRepository>(() => repo);
    final camera = _DelayedStopController();
    addTearDown(camera.dispose);
    await pumpThemed(tester, VoucherScannerPage(controller: camera));
    await tester.pump();
    final starts = camera.starts;
    tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
      BarcodeCapture(barcodes: [const Barcode(rawValue: 'not a voucher')]),
    );
    await tester.pump();
    expect(camera.stops, 1);
    expect(repo.calls, isEmpty);

    await tester.tap(find.text('Type the code instead'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    camera.firstStop.complete();
    await tester.pumpAndSettle();
    expect(find.byType(VoucherResultSheet), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(camera.starts, starts);

    // The current entry remains usable after the obsolete result is dropped.
    await tester.enterText(find.byType(TextField), 'abcd2345efgq');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.calls.single.value, 'ABCD2345EFGQ');
    expect(find.text("That code didn't work"), findsOneWidget);
    expect(camera.starts, starts);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(camera.starts, starts + 1);
    expect(camera.stops, 1);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(VoucherResultSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clipboard is read only by the visible Paste button', (
    tester,
  ) async {
    var reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            reads++;
            return {'text': 'abcd2345efgq'};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await open(tester, const VoucherRedemption(VoucherOutcome.invalid));
    await tester.tap(find.text('Type the code instead'));
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.text('Paste'), findsOneWidget);
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ABCD-2345-EFGQ',
    );
    expect(repo.calls, isEmpty);
  });

  testWidgets('scanner and manual entry fit 360x690 at 200 percent', (
    tester,
  ) async {
    repo = _FakeVoucherRepository(
      const VoucherRedemption(VoucherOutcome.invalid),
    );
    locator.registerLazySingleton<VoucherRepository>(() => repo);
    await pumpThemed(
      tester,
      const VoucherScannerPage(),
      size: const Size(360, 690),
      textScale: 2,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Type the code instead'));
    await tester.tap(find.text('Type the code instead'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a typo caught by the check symbol sends nothing and says so', (
    tester,
  ) async {
    await open(tester, const VoucherRedemption(VoucherOutcome.redeemed));
    await typeAndSubmit(tester, 'ABCD2345EFGA');

    expect(repo.calls, isEmpty);
    expect(find.text('One character looks wrong'), findsOneWidget);
    expect(find.text('ABCD-2345-EFGA'), findsOneWidget);
  });

  testWidgets('characters codes never use are pointed out', (tester) async {
    await open(tester, const VoucherRedemption(VoucherOutcome.redeemed));
    await typeAndSubmit(tester, 'ABCD2345EFG0');

    expect(repo.calls, isEmpty);
    expect(find.textContaining('never use 0, 1, I, L, O or U'), findsOneWidget);
  });

  testWidgets('closing the result restarts the camera exactly once', (
    tester,
  ) async {
    repo = _FakeVoucherRepository(
      const VoucherRedemption(VoucherOutcome.invalid),
    );
    locator.registerLazySingleton<VoucherRepository>(() => repo);
    final camera = _CountingController();
    addTearDown(camera.dispose);
    await pumpThemed(tester, VoucherScannerPage(controller: camera));
    await tester.pump();
    await typeAndSubmit(tester, 'abcd2345efgq');
    final before = camera.starts;

    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(camera.starts - before, 1);
  });

  testWidgets('Done closes the result and the page is ready again', (
    tester,
  ) async {
    await open(tester, const VoucherRedemption(VoucherOutcome.invalid));
    await typeAndSubmit(tester, 'abcd2345efgq');
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("That code didn't work"), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Type the code instead'), findsOneWidget);
  });

  testWidgets(
    'Redeem and queued Done submit once; camera cannot submit during entry',
    (tester) async {
      await open(tester, const VoucherRedemption(VoucherOutcome.invalid));
      final pending = Completer<Either<Failure, VoucherRedemption>>();
      repo.respond = () => pending.future;
      await tester.tap(find.text('Type the code instead'));
      await tester.pumpAndSettle();
      tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
        BarcodeCapture(barcodes: [const Barcode(rawValue: '23456789ABC7')]),
      );
      expect(repo.calls, isEmpty);
      await tester.enterText(find.byType(TextField), 'abcd2345efgq');
      final submitted = tester
          .widget<TextField>(find.byType(TextField))
          .onSubmitted!;
      await tester.tap(find.text('Redeem'));
      submitted('ABCD-2345-EFGQ');
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(1));
      pending.complete(const Right(VoucherRedemption(VoucherOutcome.invalid)));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(1));
      expect(find.text("That code didn't work"), findsOneWidget);
    },
  );

  testWidgets(
    'fast uncertain retry keeps the result open and the camera paused',
    (tester) async {
      repo = _FakeVoucherRepository(
        const VoucherRedemption(
          VoucherOutcome.redeemed,
          productName: 'Day Pass',
        ),
      );
      locator.registerLazySingleton<VoucherRepository>(() => repo);
      final camera = _CountingController();
      addTearDown(camera.dispose);
      await pumpThemed(tester, VoucherScannerPage(controller: camera));
      await tester.pump();
      final starts = camera.starts;
      repo.respond = () async => const Left(NetworkFailure());
      await typeAndSubmit(tester, 'abcd2345efgq');
      expect(find.text("You're offline"), findsOneWidget);
      repo.respond = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(2));
      expect(find.byType(PassReadyView), findsOneWidget);
      expect(find.text('Day Pass is ready'), findsOneWidget);
      expect(camera.starts, starts);
    },
  );

  testWidgets('terminal Done erases the held code before a fresh entry', (
    tester,
  ) async {
    await open(tester, const VoucherRedemption(VoucherOutcome.invalid));
    await typeAndSubmit(tester, 'abcd2345efgq');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Type the code instead'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('late clipboard delivery cannot fill a cancelled entry', (
    tester,
  ) async {
    final clipboard = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? clipboard.future : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await open(tester, const VoucherRedemption(VoucherOutcome.invalid));
    await tester.tap(find.text('Type the code instead'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    clipboard.complete({'text': 'abcd2345efgq'});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Type the code instead'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(repo.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
