import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/boot/boot_host.dart';
import 'package:sentech_connect_app/app/boot/boot_video_config.dart';
import 'package:sentech_connect_app/app/boot/boot_video_controller.dart';
import 'package:sentech_connect_app/app/boot/boot_video_screen.dart';
import 'package:sentech_connect_app/l10n/app_localizations_en.dart';

class FakeBootVideoController implements BootVideoController {
  FakeBootVideoController({this.failInit = false, this.neverInit = false});

  final bool failInit;
  final bool neverInit;
  final _listeners = <VoidCallback>[];
  final _initCompleter = Completer<void>();
  double? volume;
  bool played = false;
  bool disposed = false;
  bool _initialized = false;
  bool _error = false;
  Duration _position = Duration.zero;

  @override
  Future<void> initialize() {
    if (failInit) return Future.error(StateError('codec'));
    if (neverInit) return _initCompleter.future;
    _initialized = true;
    return Future.value();
  }

  @override
  Future<void> play() async => played = true;
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  bool get isInitialized => _initialized;
  @override
  bool get hasError => _error;
  @override
  Duration get position => _position;
  @override
  Duration get duration => const Duration(seconds: 10);
  @override
  Size get size => const Size(720, 1280);
  @override
  void addListener(VoidCallback l) => _listeners.add(l);
  @override
  void removeListener(VoidCallback l) => _listeners.remove(l);
  @override
  Future<void> dispose() async => disposed = true;
  @override
  Widget buildVideo(BuildContext context) =>
      const ColoredBox(color: Colors.white, key: Key('fake-video'));

  void finish() {
    _position = duration;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void breakIt() {
    _error = true;
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

/// One frame plus the microtask hops a completed future needs to land.
Future<void> settle(WidgetTester tester, [Duration d = Duration.zero]) async {
  await tester.pump(d);
  await tester.pump();
}

void main() {
  late FakeBootVideoController fake;
  late Completer<void> init;
  var completions = 0;

  Widget screen({
    bool reduceMotion = false,
    BootVideoControllerFactory? factory,
    bool noVideo = false,
  }) => _host(
    BootVideoScreen(
      initDone: init.future,
      onComplete: () => completions++,
      controllerFactory: noVideo ? null : (factory ?? () => fake),
    ),
    reduceMotion: reduceMotion,
  );

  // State is created inside the test body so its futures live in the test's
  // fake-async zone (a setUp-created Completer would complete outside it).
  void t(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      fake = FakeBootVideoController();
      init = Completer<void>();
      completions = 0;
      await body(tester);
    });
  }

  t('plays muted by default and shows the video', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(screen());
    await tester.pump();
    expect(bootVideoSoundEnabled, isFalse);
    expect(fake.volume, 0);
    expect(fake.played, isTrue);
    expect(find.byKey(const Key('fake-video')), findsOneWidget);
    expect(
      find.semantics.byLabel('Sentech Connect is starting'),
      findsOneWidget,
    );
    handle.dispose();
  });

  t('completes only when the video finished AND init is done', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump();

    fake.finish();
    await tester.pump();
    expect(completions, 0, reason: 'video finished but init not done');

    init.complete();
    await settle(tester);
    expect(completions, 1);
  });

  t('init finishing first still waits for the video', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump();
    init.complete();
    await tester.pump(const Duration(seconds: 3));
    expect(completions, 0);

    fake.finish();
    await settle(tester);
    expect(completions, 1);
  });

  t('a failing init does not hang the screen', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump();
    init.completeError(StateError('boom'));
    fake.finish();
    await settle(tester);
    expect(completions, 1);
  });

  t('skip and tap are ignored for the first 1.5 s, then work', (tester) async {
    final handle = tester.ensureSemantics();
    init.complete();
    await tester.pumpWidget(screen());
    await tester.pump();

    final skip = find.widgetWithText(TextButton, 'Skip');
    expect(skip, findsOneWidget);
    expect(tester.widget<TextButton>(skip).onPressed, isNull);

    await tester.tapAt(const Offset(100, 300));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.tapAt(const Offset(100, 300));
    await tester.pump();
    expect(completions, 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<TextButton>(skip).onPressed, isNotNull);
    expect(find.semantics.byLabel('Skip intro'), findsOneWidget);
    await tester.tapAt(const Offset(100, 300));
    await settle(tester);
    expect(completions, 1);
    handle.dispose();
  });

  t('skip button skips after the delay', (tester) async {
    init.complete();
    await tester.pumpWidget(screen());
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await settle(tester);
    expect(completions, 1);
  });

  t('skip before init is done waits for init (never delays it)', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.tapAt(const Offset(100, 300));
    await tester.pump();
    expect(completions, 0);
    init.complete();
    await settle(tester);
    expect(completions, 1);
  });

  t('reduce motion: no video, static logo for under a second', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(screen(reduceMotion: true));
    await tester.pump();
    expect(find.byKey(const Key('fake-video')), findsNothing);
    expect(fake.played, isFalse);
    expect(find.widgetWithText(TextButton, 'Skip'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.semantics.byLabel('Sentech Connect is starting'),
      findsOneWidget,
    );

    init.complete();
    await tester.pump(const Duration(milliseconds: 700));
    expect(completions, 0);
    await settle(tester, const Duration(milliseconds: 150));
    expect(completions, 1);
    expect(
      bootVideoReduceMotionHold,
      lessThanOrEqualTo(const Duration(seconds: 1)),
    );
    handle.dispose();
  });

  t('initialize failure moves on silently', (tester) async {
    init.complete();
    await tester.pumpWidget(
      screen(factory: () => FakeBootVideoController(failInit: true)),
    );
    await settle(tester);
    expect(completions, 1);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('rror'), findsNothing);
  });

  t('factory throwing moves on silently', (tester) async {
    init.complete();
    await tester.pumpWidget(
      screen(factory: () => throw StateError('no plugin')),
    );
    await settle(tester);
    expect(completions, 1);
  });

  t('playback error moves on', (tester) async {
    init.complete();
    await tester.pumpWidget(screen());
    await tester.pump();
    fake.breakIt();
    await settle(tester);
    expect(completions, 1);
  });

  t('watchdog: a video that never loads is abandoned at 12 s', (tester) async {
    init.complete();
    await tester.pumpWidget(
      screen(factory: () => FakeBootVideoController(neverInit: true)),
    );
    await tester.pump(const Duration(seconds: 11));
    expect(completions, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(completions, 1);
  });

  t('no factory (tests / unsupported): completes with init', (tester) async {
    await tester.pumpWidget(screen(noVideo: true));
    await tester.pump();
    expect(completions, 0);
    init.complete();
    await settle(tester);
    expect(completions, 1);
    expect(find.widgetWithText(TextButton, 'Skip'), findsNothing);
  });

  t('completes exactly once and disposes the controller', (tester) async {
    init.complete();
    await tester.pumpWidget(screen());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.tapAt(const Offset(100, 300));
    fake.finish();
    await settle(tester);
    expect(completions, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(fake.disposed, isTrue);
    expect(fake._listeners, isEmpty);
    // No timers left running (pending-timer check would fail the test).
  });

  t('disposing mid-video leaves no timers and disposes', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(fake.disposed, isTrue);
  });

  group('BootHost', () {
    t('app is built during the video and revealed after both', (tester) async {
      final app = Completer<Widget>();
      await tester.pumpWidget(
        BootHost(app: app.future, controllerFactory: () => fake),
      );
      await tester.pump();
      expect(find.byKey(const Key('the-app')), findsNothing);

      app.complete(const SizedBox(key: Key('the-app')));
      await settle(tester);
      // App exists underneath, the video overlay still on top and app inert.
      expect(find.byKey(const Key('the-app')), findsOneWidget);
      expect(find.byType(BootVideoScreen), findsOneWidget);

      fake.finish();
      await settle(tester);
      expect(find.byType(BootVideoScreen), findsNothing);
      expect(find.byKey(const Key('the-app')), findsOneWidget);
    });

    t('init failure reaches the startup error app', (tester) async {
      Object? reported;
      final app = Completer<Widget>();
      await tester.pumpWidget(
        BootHost(
          app: app.future,
          controllerFactory: () => fake,
          onError: (e, _) => reported = e,
        ),
      );
      app.completeError(StateError('boom'));
      await tester.pump();
      await tester.pump();
      expect(reported, isA<StateError>());
      expect(
        find.text(AppLocalizationsEn().startupErrorMessage),
        findsOneWidget,
      );
    });

    t('no factory shows the app as soon as it is ready', (tester) async {
      await tester.pumpWidget(
        BootHost(app: Future.value(const SizedBox(key: Key('the-app')))),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(BootVideoScreen), findsNothing);
      expect(find.byKey(const Key('the-app')), findsOneWidget);
    });
  });
}
