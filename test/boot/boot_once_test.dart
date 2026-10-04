import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/app/boot/boot_host.dart';
import 'package:sentech_connect_app/app/boot/boot_video_config.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';
import 'boot_video_screen_test.dart' show FakeBootVideoController, settle;

void main() {
  testWidgets(
    'failed seen marker reports nonfatally and remains eligible to retry',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final video = FakeBootVideoController();
      Object? reported;
      await tester.pumpWidget(
        BootHost(
          app: Future.value(const SizedBox()),
          controllerFactory: () => video,
          markBootVideoSeen: () async => throw StateError('storage'),
          onPreferenceError: (error, _) => reported = error,
        ),
      );
      await settle(tester);
      expect(video.played, isTrue);
      expect(reported, isA<StateError>());
      expect(await AppPreferences.loadBootVideoSeen(), isFalse);
      video.finish();
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unreadable startup preference shows static logo without player',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var created = 0;
      final seen = Completer<bool>();
      await tester.pumpWidget(
        BootHost(
          app: Future.value(const SizedBox()),
          bootVideoSeen: seen.future,
          controllerFactory: () {
            created++;
            return FakeBootVideoController();
          },
        ),
      );
      seen.completeError(StateError('unreadable'));
      await settle(tester);
      expect(created, 0);
      expect(find.byKey(const Key('boot-logo')), findsOneWidget);
      await settle(tester, bootVideoReduceMotionHold);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('startup waits for preference before mounting app or video', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final seen = Completer<bool>();
    var created = 0;
    await tester.pumpWidget(
      BootHost(
        app: Future.value(const SizedBox(key: Key('prepared-app'))),
        bootVideoSeen: seen.future,
        controllerFactory: () {
          created++;
          return FakeBootVideoController();
        },
      ),
    );
    await settle(tester);
    expect(created, 0);
    expect(find.byKey(const Key('prepared-app')), findsNothing);
    seen.complete(true);
    await settle(tester);
    expect(created, 0);
    expect(find.byKey(const Key('boot-logo')), findsOneWidget);
    await settle(tester, bootVideoReduceMotionHold);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('persisted seen prevents controller creation on cold start', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'pref_boot_video_seen': true});
    var created = 0;
    final app = Completer<Widget>();
    await tester.pumpWidget(
      BootHost(
        app: app.future,
        controllerFactory: () {
          created++;
          return FakeBootVideoController();
        },
      ),
    );
    await settle(tester);
    expect(created, 0);
    expect(find.byKey(const Key('boot-logo')), findsOneWidget);
    app.complete(const SizedBox());
    await settle(tester, bootVideoReduceMotionHold);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('first successful play is seen; next launch uses static logo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final first = FakeBootVideoController();
    await tester.pumpWidget(
      BootHost(
        app: Future.value(const SizedBox()),
        controllerFactory: () => first,
      ),
    );
    await settle(tester);
    expect(first.played, isTrue);
    expect(await AppPreferences.loadBootVideoSeen(), isTrue);
    expect(find.byKey(const Key('boot-video')), findsOneWidget);
    first.finish();
    await settle(tester);
    await tester.pumpWidget(const SizedBox());

    var created = 0;
    await tester.pumpWidget(
      BootHost(
        app: Future.value(const SizedBox()),
        controllerFactory: () {
          created++;
          return FakeBootVideoController();
        },
      ),
    );
    await settle(tester);
    expect(created, 0);
    expect(find.byKey(const Key('boot-logo')), findsOneWidget);
    await settle(tester, bootVideoReduceMotionHold);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed initialization stays unseen and retries next launch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      BootHost(
        app: Future.value(const SizedBox()),
        controllerFactory: () => FakeBootVideoController(failInit: true),
      ),
    );
    await settle(tester);
    expect(await AppPreferences.loadBootVideoSeen(), isFalse);
    await tester.pumpWidget(const SizedBox());
    final retry = FakeBootVideoController();
    await tester.pumpWidget(
      BootHost(
        app: Future.value(const SizedBox()),
        controllerFactory: () => retry,
      ),
    );
    await settle(tester);
    expect(retry.played, isTrue);
    retry.finish();
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Skip chip has a 48 dp target', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final video = FakeBootVideoController();
    await tester.pumpWidget(
      BootHost(
        app: Future.value(const SizedBox()),
        controllerFactory: () => video,
      ),
    );
    await settle(tester, bootVideoSkipDelay);
    expect(
      tester.getSize(find.byKey(const Key('boot-skip'))).height,
      greaterThanOrEqualTo(48),
    );
    video.finish();
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
  });
}
