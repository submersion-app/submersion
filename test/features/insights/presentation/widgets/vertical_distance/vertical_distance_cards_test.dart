import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_scale_layout.dart';
import 'package:submersion/features/insights/presentation/providers/vertical_distance_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_card.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_cards.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_scale.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [count] dives a day apart, [meters] each.
VerticalDistanceTimeline _dives(int count, double meters) =>
    VerticalDistanceTimeline([
      for (var i = 0; i < count; i++)
        DiveVerticalDistance(
          diveId: 'd$i',
          startMillis: DateTime.utc(2024, 1, 1 + i).millisecondsSinceEpoch,
          meters: meters,
          estimated: false,
        ),
    ]);

/// The two Total Ascent & Descent cards, side by side on a wide screen and
/// stacked on a phone, drawn on one scale (issue #4569).
void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // 5,115 m and 3,673 m. The larger total's own scale reaches Kilimanjaro.
  final profile = _dives(31, 165);
  final maxDepths = _dives(31, 118.5);

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    Future<VerticalDistanceTimeline>? profileFuture,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: VerticalDistanceCards(),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verticalDistanceTimelineProvider.overrideWith(
            (ref) => profileFuture ?? Future.value(profile),
          ),
          maxDepthTimelineProvider.overrideWith((ref) async => maxDepths),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder title(String text) => find.text(text);
  const first = 'Total Ascent & Descent';
  const second = 'Max Depths Added Up';

  List<double?> extents(WidgetTester tester) => [
    for (final s in tester.widgetList<VerticalDistanceScale>(
      find.byType(VerticalDistanceScale),
    ))
      s.extentMeters,
  ];

  test('the larger total sets the shared scale', () {
    expect(profile.totalMeters, 5115);
    expect(maxDepths.totalMeters, closeTo(3673.5, 1e-9));
    expect(verticalScaleExtent(5115), greaterThan(verticalScaleExtent(3673.5)));
  });

  testWidgets('side by side on a wide screen, on one scale', (tester) async {
    await pump(tester, width: 1000);

    expect(
      tester.getTopLeft(title(second)).dy,
      tester.getTopLeft(title(first)).dy,
    );
    expect(
      tester.getTopLeft(title(second)).dx,
      greaterThan(tester.getTopRight(title(first)).dx),
    );
    expect(extents(tester), [
      verticalScaleExtent(5115),
      verticalScaleExtent(5115),
    ]);
  });

  testWidgets('side by side, the two cards are the same height', (
    tester,
  ) async {
    await pump(tester, width: 1000);

    final heights = [
      for (final e in find.byType(VerticalDistanceCard).evaluate())
        tester.getSize(find.byWidget(e.widget)).height,
    ];
    expect(heights, hasLength(2));
    expect(heights.first, heights.last);
  });

  testWidgets('stacked on a phone, still on one scale', (tester) async {
    await pump(tester, width: 390);

    expect(
      tester.getTopLeft(title(second)).dy,
      greaterThan(tester.getTopLeft(title(first)).dy + 400),
    );
    expect(extents(tester), [
      verticalScaleExtent(5115),
      verticalScaleExtent(5115),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a level pinned before the shared scale arrives stays pinned', (
    tester,
  ) async {
    final pending = Completer<VerticalDistanceTimeline>();
    await pump(tester, width: 1000, profileFuture: pending.future);

    // Only the Max Depths card has loaded: pin a level on its descent bar.
    final scale = find.byKey(const Key('verticalScale'));
    final origin = tester.getTopLeft(scale);
    final size = tester.getSize(scale);
    await tester.tapAt(
      Offset(
        origin.dx + size.width / 2,
        origin.dy + kVerticalScaleHeight / 2 + 60,
      ),
    );
    await tester.pump();
    expect(find.text('Pinned'), findsOneWidget);
    final ownScaleHeadline = tester.getTopLeft(find.text('total ascent')).dy;

    pending.complete(profile);
    await tester.pump();
    await tester.pump();

    // The Max Depths card now sits on the larger shared scale: its bar is
    // shorter, so its ascent headline sits lower, and the level stays.
    expect(
      tester.getTopLeft(find.text('total ascent').last).dy,
      greaterThan(ownScaleHeadline),
    );
    expect(find.text('Pinned'), findsOneWidget);
  });

  testWidgets('until both have loaded, each card keeps its own scale', (
    tester,
  ) async {
    final pending = Completer<VerticalDistanceTimeline>();
    await pump(tester, width: 1000, profileFuture: pending.future);

    expect(extents(tester), [null]);

    pending.complete(profile);
    await tester.pump();
    await tester.pump();

    expect(extents(tester), [
      verticalScaleExtent(5115),
      verticalScaleExtent(5115),
    ]);
  });
}
