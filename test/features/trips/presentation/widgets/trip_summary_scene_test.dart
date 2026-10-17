import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_scene.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/scenes/chart_marks_painter.dart';
import 'package:submersion/shared/widgets/scenes/chart_painter.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';

import '../../../../helpers/mock_providers.dart';
import 'trip_summary_scene_facts_test.dart' show sceneTrip;

/// The scene only reads the trip list; every mutation is out of scope.
class _StubTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _StubTripListNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late GoRouter router;
  final now = DateTime.now();
  DateTime day(int n) => DateTime(now.year, now.month, now.day + n);

  final bali = sceneTrip('bali', 'Bali', day(-150), days: 10, dives: 20);
  final komodo = sceneTrip('komodo', 'Komodo', day(23), days: 12, dives: 0);
  final redSea = sceneTrip(
    'red',
    'Red Sea',
    day(-400),
    days: 8,
    dives: 18,
    type: TripType.liveaboard,
  );

  Future<void> pumpScene(
    WidgetTester tester, {
    AsyncValue<List<TripWithStats>>? trips,
    AppSettings settings = const AppSettings(),
    Locale locale = const Locale('en'),
    ThemeData? theme,
    Size size = const Size(900, 700),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    router = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (_, _) => const Scaffold(body: TripSummaryScene()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          tripListNotifierProvider.overrideWith(
            (ref) => _StubTripListNotifier(
              trips ?? AsyncValue.data([bali, komodo, redSea]),
            ),
          ),
        ].cast(),
        child: MaterialApp.router(
          theme: theme,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    // The scene clock keeps ticking, so settle with a bounded pump.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String month(DateTime d, [AppSettings s = const AppSettings()]) =>
      UnitFormatter(s).formatMonthYear(d);

  ChartMarksPainter marksPainter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is ChartMarksPainter,
                ),
              )
              .painter!
          as ChartMarksPainter;

  testWidgets('shows the trip count and days, and names the next and last '
      'trips', (tester) async {
    await pumpScene(tester);

    expect(find.text('TRIPS'), findsOneWidget);
    expect(find.text('3 trips, 30 days diving'), findsOneWidget);
    expect(
      find.text(
        'Next: Komodo. In 23 days. Last: Bali, ${month(bali.trip.startDate)}.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a trip starting tomorrow counts down one day', (tester) async {
    await pumpScene(
      tester,
      trips: AsyncValue.data([sceneTrip('t', 'Gozo', day(1))]),
    );

    expect(find.text('Next: Gozo. In 1 day.'), findsOneWidget);
  });

  testWidgets('draws home, last and next with the course', (tester) async {
    await pumpScene(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Bali · ${month(bali.trip.startDate)}'), findsOneWidget);
    expect(find.text('Komodo · In 23 days'), findsOneWidget);
    final painter = marksPainter(tester);
    expect(painter.course, isTrue);
    expect(painter.spots, hasLength(3));
    expect(painter.spots.first.halo, isFalse);
  });

  testWidgets('only upcoming trips run the course from home to the next', (
    tester,
  ) async {
    await pumpScene(tester, trips: AsyncValue.data([komodo]));

    expect(find.text('Next: Komodo. In 23 days.'), findsOneWidget);
    expect(marksPainter(tester).spots, hasLength(2));
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('only past trips run the course from home to the last', (
    tester,
  ) async {
    await pumpScene(tester, trips: AsyncValue.data([bali]));

    expect(
      find.text('Last: Bali, ${month(bali.trip.startDate)}.'),
      findsOneWidget,
    );
    expect(marksPainter(tester).spots, hasLength(2));
  });

  testWidgets('a trip mark opens the trip in place', (tester) async {
    await pumpScene(tester);

    await tester.tap(find.text('Komodo · In 23 days'));
    await tester.pump();

    expect(
      router
          .routerDelegate
          .currentConfiguration
          .uri
          .queryParameters['selected'],
      'komodo',
    );
  });

  testWidgets('the footer counts liveaboards and dives', (tester) async {
    await pumpScene(tester);

    expect(find.text('1 liveaboard · 38 dives away'), findsOneWidget);
  });

  testWidgets('the footer leaves out zeros', (tester) async {
    await pumpScene(tester, trips: AsyncValue.data([komodo]));

    expect(find.textContaining('liveaboard'), findsNothing);
    expect(find.textContaining('dives away'), findsNothing);
    expect(find.byType(SceneFooter), findsNothing);
  });

  testWidgets('an empty list flipped to the scene shows the count alone', (
    tester,
  ) async {
    await pumpScene(tester, trips: const AsyncValue.data([]));

    expect(tester.takeException(), isNull);
    expect(find.text('0 trips, 0 days diving'), findsOneWidget);
    expect(find.byType(SceneSentence), findsNothing);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('while loading only the eyebrow shows', (tester) async {
    await pumpScene(tester, trips: const AsyncValue.loading());

    expect(find.text('TRIPS'), findsOneWidget);
    expect(find.textContaining('trips,'), findsNothing);
  });

  testWidgets('an error shows the eyebrow only', (tester) async {
    await pumpScene(
      tester,
      trips: AsyncValue.error(StateError('db'), StackTrace.empty),
    );

    expect(find.text('TRIPS'), findsOneWidget);
    expect(find.textContaining('trips,'), findsNothing);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('dates follow the diver date format', (tester) async {
    const iso = AppSettings(dateFormat: DateFormatPreference.yyyymmdd);
    await pumpScene(tester, settings: iso);

    final expected = month(bali.trip.startDate, iso);
    expect(expected, matches(RegExp(r'^\d{4}-\d{2}$')));
    expect(find.text('Bali · $expected'), findsOneWidget);
  });

  testWidgets('a narrow pane shortens mark labels to the trip name', (
    tester,
  ) async {
    await pumpScene(tester, size: const Size(400, 400));

    expect(find.text('Komodo'), findsOneWidget);
    expect(find.text('Komodo · In 23 days'), findsNothing);
  });

  testWidgets('lays out without overflow at the three sizes', (tester) async {
    final long = AsyncValue.data([
      sceneTrip(
        'l',
        'Raja Ampat and the Banda Sea, a liveaboard crossing',
        day(40),
      ),
      sceneTrip(
        'p',
        'The Great Barrier Reef, Ribbon Reefs and Osprey',
        day(-9),
      ),
    ]);
    for (final size in const [
      Size(400, 400),
      Size(900, 700),
      Size(1600, 1000),
    ]) {
      await pumpScene(tester, size: size, trips: long);
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('in Arabic the headline aligns right and the marks do not '
      'move', (tester) async {
    await pumpScene(tester);
    final english = tester.getRect(find.byKey(const ValueKey('chart-mark-2')));

    await pumpScene(tester, locale: const Locale('ar'));

    final eyebrow = tester.getRect(find.byType(SceneEyebrow));
    expect(eyebrow.left, greaterThan(900 * 0.5));
    final arabic = tester.getRect(find.byKey(const ValueKey('chart-mark-2')));
    expect(arabic.left, english.left);
    expect(arabic.right, english.right);
  });

  testWidgets('renders under every theme preset in both brightnesses', (
    tester,
  ) async {
    for (final preset in AppThemeRegistry.presets) {
      for (final theme in [preset.lightTheme, preset.darkTheme]) {
        await pumpScene(tester, theme: theme);
        expect(tester.takeException(), isNull, reason: preset.id);
        final paint = tester.widget<CustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ChartPainter,
          ),
        );
        expect(
          (paint.painter! as ChartPainter).brightness,
          theme.brightness,
          reason: preset.id,
        );
      }
    }
  });
}
