import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/wifi_hotspots_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/wifi_hotspots_page.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/pump_themed.dart';

class _Scripted implements WifiHotspotsRepository {
  _Scripted(this.results);
  final List<Either<Failure, List<WifiHotspot>>> results;
  int calls = 0;

  @override
  Future<Either<Failure, List<WifiHotspot>>> getHotspots() async {
    final i = calls < results.length ? calls : results.length - 1;
    calls++;
    return results[i];
  }
}

const _live = WifiHotspot(
  id: '1',
  name: 'Town Hall',
  latitude: -26.2,
  longitude: 28.0,
  address: '1 Main Road',
);
const _down = WifiHotspot(
  id: '2',
  name: 'Library',
  latitude: -26.3,
  longitude: 28.1,
  status: HotspotStatus.maintenance,
);

Future<void> _pump(WidgetTester tester, _Scripted repo) async {
  final cubit = WifiHotspotsCubit(repo, locate: () async => null);
  addTearDown(cubit.close);
  await pumpThemed(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cubit),
        BlocProvider(create: (_) => DataSaverCubit(initial: true)),
      ],
      child: const WifiHotspotsPage(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('a maintenance hotspot shows a chip; a live one does not', (tester) async {
    await _pump(tester, _Scripted([const Right([_live, _down])]));
    expect(find.text('Town Hall'), findsOneWidget);
    expect(find.text('1 Main Road'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.byKey(const ValueKey('hotspot-maintenance-chip')), findsOneWidget);
    expect(find.text(l10n.hotspotsStatusMaintenance), findsOneWidget);
  });

  testWidgets('no hotspots shows the empty message', (tester) async {
    await _pump(tester, _Scripted([const Right(<WifiHotspot>[])]));
    expect(find.text(l10n.hotspotsEmpty), findsOneWidget);
  });

  testWidgets('offline shows the offline message and Retry reloads', (tester) async {
    final repo = _Scripted([const Left(NetworkFailure()), const Right([_live])]);
    await _pump(tester, repo);
    expect(find.text(l10n.failureYouReOfflineCheckYourConnection), findsOneWidget);
    expect(find.text('Town Hall'), findsNothing);

    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('Town Hall'), findsOneWidget);
  });

  testWidgets('a server error shows a retryable failure, not an empty list', (tester) async {
    await _pump(tester, _Scripted([const Left(ServerFailure())]));
    expect(find.text(l10n.hotspotsEmpty), findsNothing);
    expect(find.text(l10n.commonRetry), findsOneWidget);
  });
}
