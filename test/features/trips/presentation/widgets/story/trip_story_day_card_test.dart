import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

MediaItem _media(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  takenAt: DateTime(2026, 3, 8, 10),
  createdAt: DateTime(2026, 3, 8, 10),
  updatedAt: DateTime(2026, 3, 8, 10),
);

Sighting _sighting(
  String id,
  String species, {
  int count = 1,
  String? speciesId,
}) => Sighting(
  id: id,
  diveId: 'd1',
  speciesId: speciesId ?? 'sp-$species',
  speciesName: species,
  count: count,
);

ItineraryDay _itin({String? port, String notes = ''}) => ItineraryDay(
  id: 'itin-1',
  tripId: 'trip-1',
  dayNumber: 2,
  date: DateTime(2026, 3, 8),
  dayType: DayType.diveDay,
  portName: port,
  notes: notes,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<void> pumpCard(
  WidgetTester tester,
  TripStoryDay day, {
  List<Override> extra = const [],
}) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: TripStoryDayCard(day: day, tripId: 'trip-1'),
          ),
        ),
      ),
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
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('past day with dives shows rhythm and dive rows', (tester) async {
    final dive = createTestDiveWithBottomTime(
      id: 'd1',
      diveNumber: 42,
      bottomTime: const Duration(minutes: 47),
      maxDepth: 28.0,
    );
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [dive],
    );
    await pumpCard(tester, day);

    expect(find.textContaining('Day 2'), findsOneWidget);
    expect(find.byType(DayRhythmBar), findsOneWidget);
    expect(find.byType(DiveListItem), findsOneWidget);
  });

  testWidgets('surface day renders the slim variant', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 9),
      dayNumber: 3,
      kind: TripStoryDayKind.past,
    );
    await pumpCard(tester, day);
    expect(find.textContaining('Surface day'), findsOneWidget);
    expect(find.byType(DayRhythmBar), findsNothing);
  });

  testWidgets('future day shows the planned chip', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
    );
    await pumpCard(tester, day);
    expect(find.text('Planned'), findsOneWidget);
  });

  testWidgets('past day renders photo strip with a more-indicator', (
    tester,
  ) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      itineraryDay: _itin(port: 'Kralendijk'),
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9), maxDepth: 20)],
      media: [for (var i = 0; i < 8; i++) _media('m$i')],
    );
    await pumpCard(tester, day);

    // 8 photos, max 6 shown, so a "+2" more indicator appears.
    expect(find.text('+2'), findsOneWidget);
    // Itinerary header contributes the port name to the subtitle.
    expect(find.textContaining('Kralendijk'), findsOneWidget);
  });

  testWidgets('past day merges duplicate species into one badge', (
    tester,
  ) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
      sightings: [
        _sighting('s1', 'Reef shark'),
        _sighting('s2', 'Reef shark'),
        _sighting('s3', 'Turtle'),
      ],
    );
    await pumpCard(tester, day);

    // Two "Reef shark" sightings merge into a single "x2" chip.
    expect(find.text('Reef shark x2'), findsOneWidget);
    expect(find.text('Turtle'), findsOneWidget);
  });

  testWidgets('distinct species sharing a common name are not merged', (
    tester,
  ) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
      sightings: [
        _sighting('s1', 'Goby', speciesId: 'sp-a'),
        _sighting('s2', 'Goby', speciesId: 'sp-b'),
      ],
    );
    await pumpCard(tester, day);

    // Same display name but different speciesId: two separate chips, no "x2".
    expect(find.text('Goby'), findsNWidgets(2));
    expect(find.text('Goby x2'), findsNothing);
  });

  testWidgets('planned day shows itinerary notes and site-history pills', (
    tester,
  ) async {
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
      itineraryDay: _itin(port: 'Manta Sandy', notes: 'Bring a reef hook'),
    );
    await pumpCard(
      tester,
      day,
      extra: [
        siteHistoryByNameProvider('Manta Sandy').overrideWith(
          (ref) async => (diveCount: 6, avgWaterTemp: 27.0, avgMaxDepth: 25.0),
        ),
      ],
    );

    expect(find.text('Bring a reef hook'), findsOneWidget);
    expect(find.textContaining('6 past dives here'), findsOneWidget);
  });
}
