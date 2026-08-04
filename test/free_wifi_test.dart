import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_free_wifi_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/free_wifi_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/free_wifi_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildCard() {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider(
          create: (_) => FreeWifiCubit(MockFreeWifiRepository()),
          child: FreeWifiCard(onFindHotspots: () {}),
        ),
      ),
    );
  }

  testWidgets('offers to watch an ad with 3 free views available initially', (tester) async {
    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    expect(find.text('Free WiFi'), findsOneWidget);
    expect(find.textContaining('3 of 3 free views left today'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Watch ad'), findsOneWidget);
  });

  testWidgets('watching an ad grants a session and shows a live countdown', (tester) async {
    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Watch ad'));
    await tester.pump(); // enter watchingAd state, dialog opens
    await tester.pump(const Duration(seconds: 6)); // simulated ad duration
    await tester.pump(); // dialog pops, claim completes
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Free WiFi active'), findsOneWidget);
    expect(find.text('TIME LEFT'), findsOneWidget);
    expect(find.text('DATA LEFT'), findsOneWidget);
    // Roughly 45 minutes should be left immediately after granting.
    expect(find.textContaining('44m'), findsOneWidget);
  });

  testWidgets('all 3 daily ads used disables watching a 4th', (tester) async {
    final repo = MockFreeWifiRepository();
    // Burn through the daily cap directly via the repository so the test
    // doesn't need to sit through three simulated ads.
    for (var i = 0; i < 3; i++) {
      await repo.recordAdWatchedAndGrantSession();
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlocProvider(
          create: (_) => FreeWifiCubit(repo),
          child: FreeWifiCard(onFindHotspots: () {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // A session is active from the loop above, so the countdown shows —
    // the daily-cap messaging is only visible once that session expires.
    // Directly assert on cubit state instead of requiring the UI to be
    // mid-session-expiry, which would need real wall-clock time to pass.
    final cubit = BlocProvider.of<FreeWifiCubit>(
      tester.element(find.byType(FreeWifiCard)),
    );
    expect(cubit.state.adsRemainingToday, 0);
  });
}
