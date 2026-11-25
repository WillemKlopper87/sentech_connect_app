import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/consent_gate.dart';

import '../helpers/pump_themed.dart';

const _mapService = "your phone's map service (Google or Apple)";

void main() {
  late LocalConsentRepository repo;
  var result = <String, bool>{};

  setUp(() {
    repo = LocalConsentRepository(InMemorySecureStore(), policyVersion: 'v1');
    result = {};
  });

  Future<void> pumpButtons(WidgetTester tester) async {
    await pumpThemed(
      tester,
      Scaffold(
        body: Builder(builder: (context) => Column(
          children: [
            // What the coverage screen asks.
            TextButton(
              onPressed: () async => result['coverage'] = await ensureConsent(context, ConsentPurpose.coverageLocation, repository: repo, mapServiceNote: false),
              child: const Text('coverage'),
            ),
            // What registration asks before it turns a position into an address.
            TextButton(
              onPressed: () async => result['registration'] = await ensureConsent(context, ConsentPurpose.locationCapture, repository: repo),
              child: const Text('registration'),
            ),
          ],
        )),
      ),
    );
  }

  testWidgets('coverage_first_then_registration_still_shows_the_map_service_sentence', (tester) async {
    await pumpButtons(tester);
    await tester.tap(find.text('coverage'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_mapService), findsNothing, reason: 'the coverage notice does not use the map service');
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(result['coverage'], isTrue);
    // Registration is a different purpose: it is asked, with the disclosure, whatever coverage was agreed.
    await tester.tap(find.text('registration'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_mapService), findsOneWidget);
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(result['registration'], isTrue);
    // And now both are on record and neither asks again.
    result.clear();
    await tester.tap(find.text('registration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('coverage'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, {'registration': true, 'coverage': true});
  });

  testWidgets('registration_first_then_coverage_asks_the_coverage_notice_without_the_map_service_sentence', (tester) async {
    await pumpButtons(tester);
    await tester.tap(find.text('registration'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_mapService), findsOneWidget);
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('coverage'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'the earlier registration consent is not the coverage consent');
    expect(find.textContaining(_mapService), findsNothing);
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(result, {'registration': true, 'coverage': true});
  });

  test('the coverage location consent is device-only, like the registration one', () {
    expect(ConsentPurpose.coverageLocation.apiName, isNull);
  });
}
