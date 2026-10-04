import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/support_page.dart';

void main() {
  Widget buildPage() {
    return MaterialApp(
      home: BlocProvider(
        create: (_) => SupportCubit(MockSupportRepository()),
        child: const SupportPage(),
      ),
    );
  }

  testWidgets('search filters the FAQ list', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Why is my speed slower than expected?'), findsOneWidget);
    expect(find.text('How do I top up my data?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'top up');
    await tester.pump();

    expect(find.text('How do I top up my data?'), findsOneWidget);
    expect(find.text('Why is my speed slower than expected?'), findsNothing);
  });

  testWidgets('tapping an FAQ expands its answer', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // AnimatedCrossFade keeps both children permanently mounted (it fades
    // between them rather than removing either from the tree), so
    // collapsed/expanded is asserted via its crossFadeState, not via
    // presence/absence of the answer text.
    CrossFadeState state() =>
        tester.widgetList<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).first.crossFadeState;

    expect(state(), CrossFadeState.showFirst);
    await tester.tap(find.text('Why is my speed slower than expected?'));
    await tester.pumpAndSettle();
    expect(state(), CrossFadeState.showSecond);
    expect(find.text(lookupAppLocalizations(const Locale('en')).demoFaq1Answer), findsOneWidget);

    // Tapping again collapses it.
    await tester.tap(find.text('Why is my speed slower than expected?'));
    await tester.pumpAndSettle();
    expect(state(), CrossFadeState.showFirst);
  });

  testWidgets('ticket dialog requires a description before it can continue', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit a ticket'));
    await tester.pumpAndSettle();

    expect(find.text('Submit a ticket'), findsWidgets); // app bar action + dialog title
    expect(find.text('Category'), findsOneWidget);

    // Continue is disabled until a description is entered — dialog is
    // dismissed via Cancel rather than Continue, since Continue triggers a
    // real launchUrl() call that has no platform implementation in tests.
    final continueButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(continueButton.onPressed, isNull);

    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'My router keeps disconnecting.',
    );
    await tester.pump();

    final continueButtonAfter = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(continueButtonAfter.onPressed, isNotNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Category'), findsNothing);
  });
}
