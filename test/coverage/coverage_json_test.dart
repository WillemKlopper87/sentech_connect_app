import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/coverage/data/coverage_json.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';

import '../helpers/fixtures.dart';

void main() {
  test('parses_the_contract_example_with_two_options', () {
    final check = coverageCheckFromJson(fixtureMap('coverage_check_two_options.json'));
    expect(check.status, CoverageAnswer.covered);
    expect(check.tenant, 'sentech');
    expect(check.shapeVersion, 2);
    expect(check.options, hasLength(2));
    expect(check.primaryIndex, 0);
    expect(check.primary!.technology, CoverageTechnology.fiveG);
    final fiveG = check.options[0];
    expect(fiveG.kind, OptionKind.covered);
    expect(fiveG.band!.key, 'good');
    expect(fiveG.typicalDown, const SpeedRange(40, 100));
    expect(fiveG.busyHourDown, const SpeedRange(15, 50));
    expect(fiveG.confidence, CoverageConfidence.high);
    expect(fiveG.nearBoundary, isTrue);
    expect(fiveG.notifyAvailable, isFalse);
    expect(fiveG.measureLabelKey, 'coverage.measure.downlink');
    expect(fiveG.measureDirection, MeasureDirection.downlink);
    expect(fiveG.sourceKey, 'coverage.source.network_rf_planning');
    final lte = check.options[1];
    expect(lte.technology, CoverageTechnology.lte);
    expect(lte.notifyAvailable, isTrue);
    expect(lte.band!.notify, isTrue);
    expect(check.disclaimerKeys, ['coverage.estimate', 'coverage.indoor', 'commerce.cooling_off']);
    expect(check.datasetVersion, 7);
    expect(check.releaseLabel, '2026 Q4 plan');
    expect(check.releaseDate, DateTime.utc(2026, 11, 1));
    expect(check.nearest, isNull);
  });

  test('a_placeholder_ladder_answer_has_no_band_and_no_figures', () {
    final check = coverageCheckFromJson(fixtureMap('coverage_check_placeholder.json'));
    final option = check.options.single;
    expect(option.kind, OptionKind.covered);
    expect(option.band, isNull);
    expect(option.typicalDown, isNull);
    expect(option.busyHourDown, isNull);
    expect(option.notifyAvailable, isFalse);
    expect(option.hasFigures, isFalse);
  });

  test('a planned option carries its date, the notify flag and never a figure', () {
    final check = coverageCheckFromJson(fixtureMap('coverage_check_planned.json'));
    final option = check.options.single;
    expect(option.kind, OptionKind.planned);
    expect(option.expectedDate, DateTime.utc(2027, 3, 1));
    expect(option.notifyAvailable, isTrue);
    expect(option.hasFigures, isFalse);
    // Even if a server wrongly sent a figure for a planned option, the app does not show it.
    final json = fixtureMap('coverage_check_planned.json');
    final first = Map<String, Object?>.from((json['options']! as List).first as Map);
    first['typical_down'] = {'min_mbps': 10, 'max_mbps': 20};
    first['band'] = {'key': 'good', 'rank': 3, 'notify': false};
    final odd = coverageCheckFromJson({
      ...json,
      'options': [first],
    });
    expect(odd.options.single.typicalDown, isNull);
    expect(odd.options.single.band, isNull);
  });

  test('figures_are_dropped_when_the_direction_is_not_downlink', () {
    final json = fixtureMap('coverage_check_two_options.json');
    final first = Map<String, Object?>.from((json['options']! as List).first as Map);
    first['dataset'] = {
      ...Map<String, Object?>.from(first['dataset']! as Map),
      'measure_direction': 'uplink',
      'measure_label_key': 'coverage.measure.uplink',
    };
    final check = coverageCheckFromJson({
      ...json,
      'options': [first],
    });
    expect(check.options.single.measureDirection, MeasureDirection.uplink);
    expect(check.options.single.typicalDown, isNull);
    expect(check.options.single.busyHourDown, isNull);
    expect(check.options.single.hasFigures, isFalse);
  });

  test('unknown_technology_kind_confidence_and_status_do_not_throw', () {
    final check = coverageCheckFromJson({
      'status': 'maybe',
      'tenant': 'acme',
      'shape_version': 3,
      'disclaimer_keys': ['coverage.estimate', 'coverage.something_new', 7, null],
      'waitlist_available': true,
      'brand_new_field': {'a': 1},
      'options': [
        {
          'technology': '6g',
          'kind': 'rumoured',
          'confidence': 'fantastic',
          'band': {'key': 'platinum', 'rank': 9, 'notify': false},
          'typical_down': {'min_mbps': 10, 'max_mbps': 20},
          'near_boundary': false,
          'notify_available': false,
          'surprise': true,
          'dataset': {'version': 1, 'measure_direction': 'sideways', 'measure_label_key': 'coverage.measure.sideways'},
        },
      ],
      'primary_index': 0,
    });
    expect(check.status, CoverageAnswer.unknown);
    expect(check.shapeVersion, 3);
    final option = check.options.single;
    expect(option.technology, CoverageTechnology.unknown);
    expect(option.technologyRaw, '6g');
    expect(option.kind, OptionKind.unknown);
    expect(option.confidence, CoverageConfidence.unknown);
    expect(option.measureDirection, MeasureDirection.unknown);
    expect(option.typicalDown, isNull, reason: 'an unknown direction shows no figure');
    expect(check.disclaimerKeys, ['coverage.estimate', 'coverage.something_new']);
  });

  test('missing_optional_fields_and_nulls_are_handled', () {
    final check = coverageCheckFromJson({
      'status': 'covered',
      'tenant': 'sentech',
      'options': [
        {'technology': 'lte', 'kind': 'covered'},
        'not an object',
        {
          'technology': 'lte',
          'kind': 'planned',
          'expected_date': 'not-a-date',
          'typical_down': {'min_mbps': 'x'},
          'band': 'oops',
        },
      ],
    });
    expect(check.shapeVersion, 1, reason: 'no shape_version means an older server');
    expect(check.options, hasLength(2), reason: 'a non-object option is skipped');
    expect(check.options[0].confidence, CoverageConfidence.unknown);
    expect(check.options[0].band, isNull);
    expect(check.options[0].nearBoundary, isFalse);
    expect(check.options[0].notifyAvailable, isFalse);
    expect(check.options[0].measureLabelKey, isNull);
    expect(check.options[1].expectedDate, isNull);
    expect(check.options[1].typicalDown, isNull);
    expect(check.options[1].band, isNull);
    expect(check.disclaimerKeys, isEmpty);
    expect(check.waitlistAvailable, isFalse);
    expect(check.datasetVersion, isNull);
    expect(check.releaseLabel, isNull);
  });

  test('a speed range with a maximum below its minimum, or a negative one, is dropped', () {
    expect(speedRangeFromJson({'min_mbps': 20, 'max_mbps': 10}), isNull);
    expect(speedRangeFromJson({'min_mbps': -1, 'max_mbps': 10}), isNull);
    expect(speedRangeFromJson({'min_mbps': 5, 'max_mbps': 5}), const SpeedRange(5, 5));
  });

  test('nearest_is_read_only_when_options_are_empty', () {
    final empty = coverageCheckFromJson(fixtureMap('coverage_check_nearest.json'));
    expect(empty.options, isEmpty);
    expect(empty.nearest!.technology, CoverageTechnology.lte);
    expect(empty.nearest!.distance, DistanceBand.from5To20Km);
    expect(empty.waitlistAvailable, isTrue);
    // With an option present, a stray `nearest` is ignored.
    final json = fixtureMap('coverage_check_two_options.json');
    final withBoth = coverageCheckFromJson({
      ...json,
      'nearest': {'technology': 'lte', 'distance_band': 'under 5 km'},
    });
    expect(withBoth.nearest, isNull);
    // An unfamiliar distance band reads as unknown, never as a made-up one.
    final odd = coverageCheckFromJson({
      ...fixtureMap('coverage_check_nearest.json'),
      'nearest': {'technology': 'lte', 'distance_band': '5 to 7 km'},
    });
    expect(odd.nearest!.distance, DistanceBand.unknown);
  });

  test('primary_index_out_of_range_is_ignored', () {
    for (final bad in [5, -1, 'zero', 2]) {
      final check = coverageCheckFromJson({
        ...fixtureMap('coverage_check_two_options.json'),
        'primary_index': bad,
      });
      expect(check.primaryIndex, isNull, reason: '$bad');
      // The server's order is kept; the first option leads when no primary is named.
      expect(check.primary, check.options.first);
      expect(check.options.map((o) => o.technology), [CoverageTechnology.fiveG, CoverageTechnology.lte]);
    }
  });

  test('the meta fixture decodes, and an old meta without the consent versions still decodes', () {
    final meta = coverageMetaFromJson(fixtureMap('coverage_meta.json'));
    expect(meta.datasetVersion, 7);
    expect(meta.datasetActivatedAt, DateTime.utc(2026, 11, 2, 8, 30));
    expect(meta.waitlistConsentVersion, '2026-10-01');
    expect(meta.coverageArrivedConsentVersion, '2026-11-18');
    expect(meta.attribution, 'Coverage: Sentech (estimate)');
    expect(meta.bounds, const GeoBounds(west: 16.0, south: -35.5, east: 33.5, north: -22.0));
    expect(meta.layers.map((l) => l.name), ['coverage', 'hotspots']);
    expect(meta.canOfferNotify, isTrue);
    final old = coverageMetaFromJson({'tenant': 'sentech'});
    expect(old.datasetVersion, isNull);
    expect(old.bounds, isNull);
    expect(old.waitlistConsentVersion, isNull);
    expect(old.canOfferNotify, isFalse);
    expect(old.layers, isEmpty);
  });

  test('the bounds contain a point only inside the box, and none means the server decides', () {
    const box = GeoBounds(west: 16.0, south: -35.5, east: 33.5, north: -22.0);
    expect(box.contains(lat: -26.2, lon: 28.0), isTrue);
    expect(box.contains(lat: -40.0, lon: 28.0), isFalse);
    expect(box.contains(lat: -26.2, lon: 5.0), isFalse);
  });

  test('address matches decode with their precision and never print their coordinates', () {
    final matches = geocodeMatchesFromJson(fixtureMap('coverage_address.json'));
    expect(matches.single.precision, MatchPrecision.address);
    expect(matches.single.label, '12 Lifalethu Avenue, eMbalenhle, Secunda');
    expect(matches.single.lat, -26.514);
    expect(matches.single.toString(), isNot(contains('-26.514')));
    expect(matches.single.toString(), isNot(contains('Lifalethu')));
    // A hit without usable coordinates is skipped.
    expect(
      geocodeMatchesFromJson({
        'results': [
          {'label': 'x', 'lat': 'a', 'lon': 1},
          {'label': 'ok', 'lat': -26.1, 'lon': 28.1},
          {'label': 'out of range', 'lat': 99.0, 'lon': 28.1},
        ],
      }).map((m) => m.label),
      ['ok'],
    );
  });
}
