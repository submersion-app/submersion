import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_overview_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _trip = Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: DateTime(2026, 3, 25),
  endDate: DateTime(2026, 3, 26),
  tripType: TripType.resort,
  notes: '',
  createdAt: DateTime(2026, 3, 20),
  updatedAt: DateTime(2026, 3, 20),
);

final _stats = TripWithStats(
  trip: _trip,
  diveCount: 2,
  totalBottomTime: 75 * 60,
  maxDepth: 30.0,
);

Future<void> pumpTab(
  WidgetTester tester, {
  required List<Override> extra,
}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: TripOverviewTab(tripWithStats: _stats)),
      ),
      GoRoute(path: '/dives/:id', builder: (_, _) => const Scaffold()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides, ...extra].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  // Issue #166: every trip (not only liveaboards) gets a day-by-day breakdown.
  testWidgets('renders one day chapter per trip day with dives', (
    tester,
  ) async {
    final story = buildTripStory(
      trip: _trip,
      dives: [
        Dive(id: 'd1', dateTime: DateTime(2026, 3, 25, 9), maxDepth: 25),
        Dive(id: 'd2', dateTime: DateTime(2026, 3, 26, 10), maxDepth: 20),
      ],
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [],
      today: DateTime(2026, 6, 1),
    );
    await pumpTab(
      tester,
      extra: [tripStoryProvider('trip-1').overrideWith((ref) async => story)],
    );

    expect(find.byType(TripStoryDayCard), findsNWidgets(2));
    expect(find.textContaining('Day 1'), findsWidgets);
    expect(find.textContaining('Day 2'), findsWidgets);
    expect(find.byType(DiveListItem), findsNWidgets(2));
  });

  testWidgets('tapping a dive row navigates to the dive detail', (
    tester,
  ) async {
    final story = buildTripStory(
      trip: _trip,
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 25, 9), maxDepth: 25)],
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [],
      today: DateTime(2026, 6, 1),
    );
    await pumpTab(
      tester,
      extra: [tripStoryProvider('trip-1').overrideWith((ref) async => story)],
    );

    await tester.tap(find.byType(DiveListItem).first);
    await tester.pumpAndSettle();
    // Navigation succeeded if the dive route (empty Scaffold) replaced the tab.
    expect(find.byType(TripStoryDayCard), findsNothing);
  });

  testWidgets('shows an error message when the story fails to load', (
    tester,
  ) async {
    await pumpTab(
      tester,
      extra: [
        tripStoryProvider(
          'trip-1',
        ).overrideWith((ref) async => throw Exception('boom')),
      ],
    );

    expect(find.textContaining('Error'), findsOneWidget);
  });
}
