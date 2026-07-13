import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_map_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

Trip _trip() => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: DateTime(2026, 3, 7),
  endDate: DateTime(2026, 3, 10),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<void> pumpHeader(
  WidgetTester tester,
  TripStoryMapGeometry geometry,
  TripWithStats stats,
) async {
  final overrides = await getBaseOverrides();
  final controller = MapController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: TripStoryMapHeaderDelegate(
                  geometry: geometry,
                  stats: stats,
                  activeDayIndex: 0,
                  mapController: controller,
                  onDaySelected: (_) {},
                  maxExtentValue: 260,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders a FlutterMap when geometry has points', (tester) async {
    const geometry = TripStoryMapGeometry(
      points: [
        TripStoryMapPoint(
          latitude: 12.1,
          longitude: -68.2,
          dayIndex: 0,
          label: 'A',
        ),
        TripStoryMapPoint(
          latitude: 12.2,
          longitude: -68.3,
          dayIndex: 1,
          label: 'B',
        ),
      ],
    );
    final stats = TripWithStats(trip: _trip(), diveCount: 8);
    await pumpHeader(tester, geometry, stats);

    expect(find.byType(FlutterMap), findsWidgets);
    expect(find.byType(TripStatStrip), findsOneWidget);
  });

  testWidgets('renders fallback (no map) when geometry is empty', (
    tester,
  ) async {
    const geometry = TripStoryMapGeometry(points: []);
    final stats = TripWithStats(trip: _trip(), diveCount: 3);
    await pumpHeader(tester, geometry, stats);

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byType(TripStatStrip), findsOneWidget);
  });

  testWidgets('stat strip shows the dive count', (tester) async {
    const geometry = TripStoryMapGeometry(points: []);
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    await pumpHeader(tester, geometry, stats);

    expect(find.text('14'), findsOneWidget);
  });
}
