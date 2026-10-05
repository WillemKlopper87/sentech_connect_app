import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/pass_summary.dart';
import 'package:sentech_connect_app/l10n/app_localizations_en.dart';

final t0 = DateTime.utc(2026, 10, 3, 11, 21);
final en = AppLocalizationsEn();

Pass pass({
  int? dataMb,
  int usedBytes = 0,
  Duration expiresIn = const Duration(hours: 22),
  PassStatus status = PassStatus.active,
}) => Pass(
  id: 'pass-1',
  productName: 'Day Pass',
  status: status,
  startsAt: t0.subtract(const Duration(hours: 1)),
  expiresAt: t0.add(expiresIn),
  durationMinutes: 1440,
  dataMb: dataMb,
  maxDevices: 1,
  usedBytes: usedBytes,
);

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  test('uncapped pass headlines time left and has no fraction', () {
    final s = PassSummary.of(
      pass(expiresIn: const Duration(hours: 21, minutes: 59)),
      en,
      now: t0,
      localeTag: 'en',
    );
    expect(s.headline, '21h 59m left');
    expect(s.fractionLeft, isNull);
  });
  test('over-used capped pass clamps at zero and is critical', () {
    final s = PassSummary.of(
      pass(dataMb: 1024, usedBytes: 2 << 30),
      en,
      now: t0,
      localeTag: 'en',
    );
    expect(s.headline, '0 MB left');
    expect(s.tier, UsageTier.critical);
    expect(s.fractionLeft, 0);
  });
  test('zero cap does not divide by zero', () {
    expect(
      () => PassSummary.of(pass(dataMb: 0), en, now: t0, localeTag: 'en'),
      returnsNormally,
    );
  });
  test(
    'authoritative ended and scheduled statuses override clock and usage',
    () {
      expect(
        PassSummary.of(
          pass(status: PassStatus.revoked),
          en,
          now: t0,
          localeTag: 'en',
        ).tier,
        UsageTier.ended,
      );
      expect(
        PassSummary.of(
          pass(status: PassStatus.scheduled),
          en,
          now: t0,
          localeTag: 'en',
        ).tier,
        UsageTier.plenty,
      );
    },
  );
  test(
    'snapshot status expires at the exact boundary without losing ended reasons',
    () {
      for (final status in [PassStatus.active, PassStatus.scheduled]) {
        final s = PassSummary.of(
          pass(status: status, expiresIn: Duration.zero),
          en,
          now: t0,
          localeTag: 'en',
        );
        expect(s.effectiveStatus, PassStatus.expired);
        expect(s.tier, UsageTier.ended);
      }
      expect(
        PassSummary.of(
          pass(status: PassStatus.revoked),
          en,
          now: t0,
          localeTag: 'en',
        ).effectiveStatus,
        PassStatus.revoked,
      );
      expect(
        PassSummary.of(
          pass(status: PassStatus.exhausted),
          en,
          now: t0,
          localeTag: 'en',
        ).effectiveStatus,
        PassStatus.exhausted,
      );
    },
  );
}
