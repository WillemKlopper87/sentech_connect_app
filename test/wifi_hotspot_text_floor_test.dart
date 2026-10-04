import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';
import 'package:sentech_connect_app/app/theme/color_contrast.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/wifi_hotspots_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/wifi_hotspots_page.dart';

import 'helpers/pump_themed.dart';

class _PendingHotspots implements WifiHotspotsRepository {
  @override
  Future<Either<Failure, List<WifiHotspot>>> getHotspots() =>
      Completer<Either<Failure, List<WifiHotspot>>>().future;
}

void main() {
  const spot = WifiHotspot(
    id: '1',
    name: 'Town Hall',
    latitude: -26.2,
    longitude: 28.0,
  );

  for (final hasLocation in [true, false]) {
    testWidgets(
      'hotspot ${hasLocation ? 'nearest badge' : 'location guidance'} uses readable text at 2x',
      (tester) async {
        final cubit = WifiHotspotsCubit(_PendingHotspots());
        addTearDown(cubit.close);
        cubit.emit(
          WifiHotspotsState(
            status: WifiHotspotsStatus.loaded,
            hotspots: [
              HotspotDistance(
                hotspot: spot,
                distanceMeters: hasLocation ? 250 : null,
              ),
            ],
            userLatitude: hasLocation ? -26.2 : null,
            userLongitude: hasLocation ? 28.0 : null,
          ),
        );
        await pumpThemed(
          tester,
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider(create: (_) => DataSaverCubit(initial: true)),
            ],
            child: const WifiHotspotsPage(),
          ),
          size: const Size(360, 690),
          textScale: 2,
        );
        await tester.pumpAndSettle();
        final label = hasLocation
            ? find.text('CLOSEST')
            : find.text(
                'Enable location to see which hotspot is closest to you.',
              );
        final paragraph = tester.widget<RichText>(
          find.descendant(of: label, matching: find.byType(RichText)),
        );
        expect(
          paragraph.text.style!.fontSize,
          greaterThanOrEqualTo(hasLocation ? 13 : 15),
        );
        final theme = Theme.of(tester.element(label));
        expect(
          ColorContrast.ratio(
            paragraph.text.style!.color!,
            hasLocation
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.getRect(label).right, lessThanOrEqualTo(360));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
