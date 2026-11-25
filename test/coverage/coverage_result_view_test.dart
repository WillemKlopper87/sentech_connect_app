import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/coverage/data/coverage_json.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/presentation/widgets/coverage_result_view.dart';
import 'package:sentech_connect_app/l10n/app_localizations_af.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_themed.dart';
import 'fake_coverage_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  CoverageCheck check, {
  void Function(TechnologyInterest)? onNotify,
  VoidCallback? onRetry,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
}) async {
  await pumpThemed(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: CoverageResultView(check: check, meta: metaFixture(), onNotify: onNotify, onRetry: onRetry),
      ),
    ),
    textScale: textScale,
    locale: locale,
    size: size,
  );
}

CoverageCheck _withOption(Map<String, Object?> Function(Map<String, Object?> option) change, [String file = 'coverage_check_two_options.json']) {
  final json = fixtureMap(file);
  final options = [for (final o in json['options']! as List) change(Map<String, Object?>.from(o as Map))];
  return coverageCheckFromJson({...json, 'options': options});
}

void main() {
  testWidgets('shows_no_speed_when_the_server_withholds_the_band', (tester) async {
    await _pump(tester, checkFixture('coverage_check_placeholder.json'));
    expect(find.text('5G: predicted coverage'), findsOneWidget);
    expect(find.text('Coverage is predicted here'), findsOneWidget);
    expect(find.textContaining('We do not show a figure'), findsOneWidget);
    expect(find.textContaining('Mbps'), findsNothing);
    expect(find.textContaining('Typical'), findsNothing);
    expect(find.textContaining('Strong service'), findsNothing);
    expect(find.textContaining('Good service'), findsNothing);
    // A figure that arrives with no band is not shown either: a band is what lets the server stand behind a figure.
    final odd = _withOption((o) => {...o, 'band': null}, 'coverage_check_two_options.json');
    await _pump(tester, odd);
    expect(find.textContaining('Mbps'), findsNothing);
  });

  testWidgets('shows_primary_option_first_and_all_options', (tester) async {
    await _pump(tester, checkFixture());
    final fiveG = tester.getTopLeft(find.text('5G: predicted coverage')).dy;
    final lte = tester.getTopLeft(find.text('LTE (4G): predicted coverage')).dy;
    expect(fiveG, lessThan(lte));
    expect(find.text('Good service is predicted'), findsOneWidget);
    expect(find.text('Basic service is predicted'), findsOneWidget);
    expect(find.text('Typical download speed: 40–100 Mbps'), findsOneWidget);
    expect(find.text('Busy-hour download speed: 15–50 Mbps'), findsOneWidget);
    expect(find.text('Typical download speed: 5–20 Mbps'), findsOneWidget);
    expect(find.text('Prediction confidence: high'), findsOneWidget);
    expect(find.text('Prediction confidence: medium'), findsOneWidget);
    expect(find.textContaining('close to the edge'), findsOneWidget, reason: 'only the 5G option is near its boundary');
    // The server's primary is shown first even when it is not first in the list.
    final json = fixtureMap('coverage_check_two_options.json');
    final swapped = coverageCheckFromJson({...json, 'primary_index': 1});
    await _pump(tester, swapped);
    expect(
      tester.getTopLeft(find.text('LTE (4G): predicted coverage')).dy,
      lessThan(tester.getTopLeft(find.text('5G: predicted coverage')).dy),
    );
  });

  testWidgets('planned_shows_the_expected_date_and_notify', (tester) async {
    final asked = <TechnologyInterest>[];
    await _pump(tester, checkFixture('coverage_check_planned.json'), onNotify: asked.add);
    expect(find.text('5G: planned'), findsOneWidget);
    expect(find.textContaining('Expected around March 2027'), findsOneWidget);
    expect(find.textContaining('estimates and can change'), findsWidgets);
    expect(find.textContaining('Mbps'), findsNothing);
    await tester.tap(find.text('Notify me'));
    expect(asked, [TechnologyInterest.fiveG]);
    // Without a date the card says so.
    final undated = _withOption((o) => {...o, 'expected_date': null}, 'coverage_check_planned.json');
    await _pump(tester, undated);
    expect(find.textContaining('We do not have a date yet'), findsOneWidget);
  });

  testWidgets('the notify action follows notify_available per option and needs a handler', (tester) async {
    final asked = <TechnologyInterest>[];
    await _pump(tester, checkFixture(), onNotify: asked.add);
    // Only the LTE option (basic band) allows it.
    expect(find.text('Notify me'), findsOneWidget);
    await tester.ensureVisible(find.text('Notify me'));
    await tester.tap(find.text('Notify me'));
    expect(asked, [TechnologyInterest.lte]);
    await _pump(tester, checkFixture('coverage_check_placeholder.json'), onNotify: asked.add);
    expect(find.text('Notify me'), findsNothing, reason: 'the server did not allow it');
    await _pump(tester, checkFixture('coverage_check_planned.json'));
    expect(find.text('Notify me'), findsNothing, reason: 'no handler: the provider cannot take sign-ups (older server)');
  });

  testWidgets('empty_options_with_nearest_uses_distance_band_words', (tester) async {
    final asked = <TechnologyInterest>[];
    await _pump(tester, checkFixture('coverage_check_nearest.json'), onNotify: asked.add);
    expect(find.text('We do not cover this place yet.'), findsOneWidget);
    expect(find.textContaining('closest predicted LTE (4G) coverage is about 5 to 20 km'), findsOneWidget);
    expect(find.textContaining('Mbps'), findsNothing);
    await tester.tap(find.text('Notify me'));
    expect(asked, [TechnologyInterest.any]);
    // Every distance band has its words, and an unknown one has none (never a made-up distance).
    for (final (band, text) in [
      ('under 5 km', 'less than 5 km'),
      ('20 to 50 km', 'about 20 to 50 km'),
      ('over 50 km', 'more than 50 km'),
    ]) {
      await _pump(
        tester,
        coverageCheckFromJson({
          ...fixtureMap('coverage_check_nearest.json'),
          'nearest': {'technology': 'lte', 'distance_band': band},
        }),
      );
      expect(find.textContaining(text), findsOneWidget, reason: band);
    }
    await _pump(
      tester,
      coverageCheckFromJson({
        ...fixtureMap('coverage_check_nearest.json'),
        'nearest': {'technology': 'lte', 'distance_band': 'around the corner'},
      }),
    );
    expect(find.textContaining('closest predicted'), findsNothing);
    expect(find.text('We do not cover this place yet.'), findsOneWidget);
    // No nearest and no notify permission: just the plain words, no button.
    await _pump(
      tester,
      coverageCheckFromJson({...fixtureMap('coverage_check_nearest.json'), 'nearest': null, 'waitlist_available': false}),
      onNotify: asked.add,
    );
    expect(find.text('Notify me'), findsNothing);
  });

  testWidgets('unknown_disclaimer_key_falls_back_to_the_generic_text', (tester) async {
    final check = coverageCheckFromJson({
      ...fixtureMap('coverage_check_nearest.json'),
      'disclaimer_keys': ['coverage.estimate', 'coverage.from_the_future'],
    });
    await _pump(tester, check);
    expect(find.textContaining('Coverage is an estimate from our network plan'), findsOneWidget);
    expect(find.text('Coverage and speeds are predictions, not guarantees.'), findsOneWidget, reason: 'the unknown key shows the generic text, never the raw key');
    expect(find.textContaining('from_the_future'), findsNothing);
    // Two unknown keys show the generic text once.
    final two = coverageCheckFromJson({
      ...fixtureMap('coverage_check_nearest.json'),
      'disclaimer_keys': ['a.b', 'c.d'],
    });
    await _pump(tester, two);
    expect(find.text('Coverage and speeds are predictions, not guarantees.'), findsOneWidget);
  });

  testWidgets('a covered answer always carries the estimate, indoor and cooling-off notices', (tester) async {
    final bare = coverageCheckFromJson({...fixtureMap('coverage_check_placeholder.json'), 'disclaimer_keys': <String>[]});
    await _pump(tester, bare);
    expect(find.textContaining('Coverage is an estimate'), findsOneWidget);
    expect(find.textContaining('predicted for outdoor use'), findsOneWidget);
    expect(find.textContaining('Refund requests are reviewed by your provider'), findsOneWidget);
    // A planned or empty answer shows only what the server named.
    await _pump(tester, checkFixture('coverage_check_planned.json'));
    expect(find.textContaining('Refund requests'), findsNothing);
    expect(find.textContaining('predicted for outdoor use'), findsNothing);
  });

  testWidgets('figures_are_never_shown_without_the_predicted_wording', (tester) async {
    for (final file in [
      'coverage_check_two_options.json',
      'coverage_check_placeholder.json',
      'coverage_check_planned.json',
      'coverage_check_nearest.json',
    ]) {
      await _pump(tester, checkFixture(file));
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText() ?? '').toList();
      final hasFigure = texts.any((t) => t.contains('Mbps'));
      if (hasFigure) {
        expect(texts.any((t) => t.contains('predicted download speeds')), isTrue, reason: '$file names what the speeds are');
        expect(texts.any((t) => t.contains('predictions, not guarantees')), isTrue, reason: '$file says it is not a promise');
        expect(texts.any((t) => t.toLowerCase().contains('guaranteed') && !t.contains('not guarantee')), isFalse);
      }
    }
  });

  testWidgets('the_direction_line_is_shown_with_the_figures_it_describes_and_nowhere_else', (tester) async {
    await _pump(tester, checkFixture());
    expect(find.text('The speeds shown are predicted download speeds, measured outdoors.'), findsNWidgets(2), reason: 'one per card with figures');
    // No band, so no figure and no line about what a figure measures.
    await _pump(tester, checkFixture('coverage_check_placeholder.json'));
    expect(find.textContaining('speeds shown'), findsNothing);
    expect(find.textContaining('upload'), findsNothing);
    // An uplink or unknown basis carries no figure, so the card says nothing is measured at all.
    for (final direction in ['uplink', 'unknown']) {
      final check = _withOption(
        (o) => {
          ...o,
          'dataset': {...Map<String, Object?>.from(o['dataset']! as Map), 'measure_direction': direction, 'measure_label_key': 'coverage.measure.$direction'},
        },
      );
      await _pump(tester, check);
      expect(find.textContaining('Mbps'), findsNothing, reason: direction);
      expect(find.textContaining('predicted download speeds'), findsNothing, reason: direction);
      expect(find.textContaining('measures'), findsNothing, reason: direction);
      expect(find.textContaining('upload, not download'), findsNothing, reason: direction);
    }
    // A planned card, even on a non-download basis, never says anything is measured.
    final planned = _withOption(
      (o) => {...o, 'dataset': {...Map<String, Object?>.from(o['dataset']! as Map), 'measure_direction': 'uplink', 'measure_label_key': 'coverage.measure.uplink'}},
      'coverage_check_planned.json',
    );
    await _pump(tester, planned);
    expect(find.textContaining('upload'), findsNothing);
    expect(find.textContaining('measure'), findsNothing);
  });

  testWidgets('an unknown technology, band, confidence and status render neutral labels and never throw', (tester) async {
    final check = coverageCheckFromJson({
      'status': 'maybe',
      'tenant': 'x',
      'shape_version': 3,
      'disclaimer_keys': <String>[],
      'waitlist_available': false,
      'options': [
        {
          'technology': '6g',
          'kind': 'rumoured',
          'confidence': 'fantastic',
          'band': {'key': 'platinum', 'rank': 9, 'notify': false},
          'near_boundary': false,
          'notify_available': false,
          'dataset': {'version': 3, 'measure_direction': 'downlink', 'measure_label_key': 'coverage.measure.downlink'},
        },
      ],
      'primary_index': 0,
    });
    await _pump(tester, check);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('6g'), findsNothing, reason: 'the server string is never shown');
    expect(find.textContaining('Network'), findsWidgets);
    expect(find.textContaining('confidence'), findsNothing);
    expect(find.textContaining('Mbps'), findsNothing);
    expect(find.textContaining('platinum'), findsNothing);
  });

  testWidgets('an answer with no options is read from its status in plain words, an unreadable one asks to try again', (tester) async {
    var retried = 0;
    final covered = coverageCheckFromJson({'status': 'covered', 'tenant': 'x', 'dataset_version': 4, 'disclaimer_keys': <String>[]});
    await _pump(tester, covered);
    expect(find.text('Coverage is predicted here'), findsOneWidget);
    expect(find.textContaining('Mbps'), findsNothing);
    final planned = coverageCheckFromJson({'status': 'planned', 'tenant': 'x', 'dataset_version': 4});
    await _pump(tester, planned);
    expect(find.text('Coverage is planned for this place.'), findsOneWidget);
    final unreadable = coverageCheckFromJson({'status': 'later', 'tenant': 'x', 'dataset_version': 4});
    await _pump(tester, unreadable, onRetry: () => retried++);
    expect(find.textContaining('could not read'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('the footer names the release of the answer shown, the source, the attribution and that these are predictions', (tester) async {
    await _pump(tester, checkFixture());
    expect(find.text('Network data: 2026 Q4 plan, released Nov 1, 2026.'), findsOneWidget);
    expect(find.text('Source: our network planning team.'), findsOneWidget);
    expect(find.text('Coverage: Sentech (estimate)'), findsOneWidget);
    expect(find.text('These are predictions, not guarantees.'), findsOneWidget);
    // Label only, date only and version only.
    final labelOnly = _withOption((o) => {...o, 'dataset': {...Map<String, Object?>.from(o['dataset']! as Map), 'release_date': null}});
    await _pump(tester, labelOnly);
    expect(find.text('Network data: 2026 Q4 plan.'), findsOneWidget);
    final dateOnly = _withOption((o) => {...o, 'dataset': {...Map<String, Object?>.from(o['dataset']! as Map), 'release_label': null}});
    await _pump(tester, dateOnly);
    expect(find.text('Network data released Nov 1, 2026.'), findsOneWidget);
    final versionOnly = _withOption(
      (o) => {...o, 'dataset': {...Map<String, Object?>.from(o['dataset']! as Map), 'release_label': null, 'release_date': null, 'source_label': 'coverage.source.new'}},
    );
    await _pump(tester, versionOnly);
    expect(find.text('Network data version 7.'), findsOneWidget);
    expect(find.textContaining('coverage.source'), findsNothing, reason: 'an unknown source key is not shown raw');
    // An empty answer still says which data it came from.
    await _pump(tester, checkFixture('coverage_check_nearest.json'));
    expect(find.text('Network data version 7.'), findsOneWidget);
  });

  testWidgets('an_unknown_kind_gets_a_neutral_card_with_no_band_and_no_predicted_wording', (tester) async {
    final check = _withOption((o) => {...o, 'kind': 'rumoured'}, 'coverage_check_two_options.json');
    await _pump(tester, check);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('predicted coverage'), findsNothing);
    expect(find.textContaining('Good service'), findsNothing);
    expect(find.textContaining('Basic service'), findsNothing);
    expect(find.textContaining('Mbps'), findsNothing);
    expect(find.text('Coverage is predicted at this place'), findsNothing, reason: 'nothing is covered, so no covered title');
    expect(find.text('Coverage is planned for this place.'), findsNothing, reason: 'nothing is planned either');
    expect(find.text('Coverage options at this place'), findsOneWidget);
    expect(find.text('5G'), findsOneWidget);
    expect(find.text('LTE (4G)'), findsOneWidget);
    expect(find.textContaining('could not read the details'), findsWidgets);
  });

  testWidgets('large_text_does_not_overflow', (tester) async {
    for (final file in ['coverage_check_two_options.json', 'coverage_check_planned.json', 'coverage_check_nearest.json']) {
      await _pump(tester, checkFixture(file), onNotify: (_) {}, textScale: 2.0, size: const Size(320, 640));
      expect(tester.takeException(), isNull, reason: file);
    }
  });

  testWidgets('an option is one screen-reader group that says its technology and status', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, checkFixture());
    expect(tester.getSemantics(find.text('5G: predicted coverage')).label, contains('5G: predicted coverage'));
    handle.dispose();
  });

  testWidgets('the planned month follows the language', (tester) async {
    await _pump(tester, checkFixture('coverage_check_planned.json'), locale: const Locale('af'));
    // The platform's planned wording stays English (a claim), but the month is the language's own.
    expect(find.textContaining('Maart 2027'), findsOneWidget);
    expect(AppLocalizationsAf().coverageOptionPlannedText('x'), contains('Expected around'));
  });
}
