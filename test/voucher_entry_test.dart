import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_scanner_page.dart';

import 'helpers/pump_themed.dart';
import 'helpers/test_setup.dart';

class _FakeVoucherRepository implements VoucherRepository {
  _FakeVoucherRepository(this.reply);

  VoucherRedemption reply;
  final calls = <VoucherCode>[];

  @override
  Future<Either<Failure, VoucherRedemption>> redeem(VoucherCode code) async {
    calls.add(code);
    return Right(reply);
  }
}

/// Counts camera starts; never touches a real camera.
class _CountingController extends MobileScannerController {
  _CountingController() : super(autoStart: false);

  int starts = 0;

  @override
  Future<void> start({
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
  }) async {
    starts++;
  }

  @override
  Future<void> stop() async {}
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
  });

  testWidgets(
    'a refused code shows what was typed, unmasked, with Try again and Done',
    (tester) async {
      await open(tester, const VoucherRedemption(VoucherOutcome.invalid));
      await typeAndSubmit(tester, 'abcd2345efgq');

      expect(repo.calls, hasLength(1));
      expect(find.text("That code didn't work"), findsOneWidget);
      expect(find.text('ABCD-2345-EFGQ'), findsOneWidget);
      expect(find.textContaining('••'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      // The entry field is back with the code still in it, ready to fix.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'ABCD-2345-EFGQ');
    },
  );

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
}
