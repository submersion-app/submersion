import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/panels/conditional_panels.dart';
import 'package:submersion/features/dashboard/presentation/panels/first_dive_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/latest_profile_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/latest_vs_average_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/recent_dives_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/species_seen_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import 'panel_harness.dart';

Dive _dive(String id, String site, int day, double depth, int minutes) => Dive(
  id: id,
  dateTime: DateTime.utc(2026, 11, day, 10),
  entryTime: DateTime.utc(2026, 11, day, 10),
  runtime: Duration(minutes: minutes),
  maxDepth: depth,
  waterTemp: 27,
  site: DiveSite(id: 's$id', name: site),
);

final _dives = [
  _dive('d3', 'Salt Pier', 8, 18.4, 52),
  _dive('d2', 'Something Special', 7, 22, 48),
  _dive('d1', 'Hilma Hooker', 6, 29.3, 41),
];

void main() {
  group('recent dives', () {
    testWidgets('a row per dive, and a row opens its dive', (tester) async {
      final nav = await pumpPanel(
        tester,
        const RecentDivesPanel(),
        width: 900,
        overrides: [recentDivesProvider.overrideWith((ref) async => _dives)],
      );
      expect(find.text('Salt Pier'), findsOneWidget);
      expect(find.text('Hilma Hooker'), findsOneWidget);
      expect(find.text('DATE'), findsOneWidget);
      await tester.tap(find.text('Something Special'));
      await tester.pumpAndSettle();
      expect(nav.location, '/dives/d2');
    });

    testWidgets('a phone drops the date column', (tester) async {
      await pumpPanel(
        tester,
        const RecentDivesPanel(),
        width: 390,
        overrides: [recentDivesProvider.overrideWith((ref) async => _dives)],
      );
      expect(find.text('DATE'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no dives says so', (tester) async {
      await pumpPanel(
        tester,
        const RecentDivesPanel(),
        overrides: [recentDivesProvider.overrideWith((ref) async => [])],
      );
      expect(find.text('No dives logged yet'), findsOneWidget);
    });
  });

  group('latest profile', () {
    testWidgets('draws the profile and opens the dive', (tester) async {
      final nav = await pumpPanel(
        tester,
        const LatestProfilePanel(),
        overrides: [
          homeLatestProfileProvider.overrideWith(
            (ref) async => (
              dive: _dives.first,
              points: [(0.0, 0.0), (600.0, 18.4), (3000.0, 5.0), (3120.0, 0.0)],
            ),
          ),
        ],
      );
      expect(find.textContaining('Salt Pier'), findsOneWidget);
      await tester.tap(find.byType(LatestProfilePanel));
      await tester.pumpAndSettle();
      expect(nav.location, '/dives/d3');
    });

    testWidgets('a dive with no samples says so', (tester) async {
      await pumpPanel(
        tester,
        const LatestProfilePanel(),
        overrides: [
          homeLatestProfileProvider.overrideWith(
            (ref) async => (dive: _dives.first, points: <(double, double)>[]),
          ),
        ],
      );
      expect(find.text('No profile data for this dive'), findsOneWidget);
    });
  });

  group('latest against average', () {
    testWidgets('compares with the average when there is one', (tester) async {
      await pumpPanel(
        tester,
        const LatestVsAveragePanel(),
        overrides: [
          recentDivesProvider.overrideWith((ref) async => _dives),
          homeAveragesProvider.overrideWith(
            (ref) async => (
              averages: const HomeAverages(
                maxDepth: 21,
                runtimeSeconds: 2820,
                diveCount: 40,
              ),
              sac: null,
            ),
          ),
          homeSacSeriesProvider.overrideWith((ref) async => []),
        ],
      );
      expect(find.textContaining('avg 21'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no averages shows the values alone', (tester) async {
      await pumpPanel(
        tester,
        const LatestVsAveragePanel(),
        overrides: [
          recentDivesProvider.overrideWith((ref) async => _dives),
          homeAveragesProvider.overrideWith(
            (ref) async => (
              averages: const HomeAverages(
                maxDepth: null,
                runtimeSeconds: null,
                diveCount: 0,
              ),
              sac: null,
            ),
          ),
          homeSacSeriesProvider.overrideWith((ref) async => []),
        ],
      );
      expect(find.textContaining('avg'), findsNothing);
      expect(find.textContaining('18.4'), findsOneWidget);
    });
  });

  testWidgets('species seen lately names species and the total', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const SpeciesSeenPanel(),
      overrides: [
        homeRecentSpeciesProvider.overrideWith(
          (ref) async => const [
            SpeciesSighting(name: 'Green turtle', diveCount: 6),
            SpeciesSighting(name: 'French angelfish', diveCount: 5),
          ],
        ),
        dashboardQuickStatsProvider.overrideWith(
          (ref) async => const DashboardQuickStats(speciesDiscovered: 143),
        ),
      ],
    );
    expect(find.text('Green turtle'), findsOneWidget);
    expect(find.text('143 total'), findsOneWidget);
  });

  testWidgets('the first-dive panel offers to log or import', (tester) async {
    await pumpPanel(tester, const FirstDivePanel(), width: 800);
    expect(find.text('Log or import your first dive'), findsOneWidget);
    expect(find.text('Log Dive'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
  });

  testWidgets('on this day names the year and site', (tester) async {
    final nav = await pumpPanel(
      tester,
      const OnThisDayPanel(),
      overrides: [
        onThisDayProvider.overrideWith(
          (ref) async => [
            Dive(
              id: 'old',
              dateTime: DateTime.utc(2024, 11, 20, 9),
              maxDepth: 31.2,
              runtime: const Duration(minutes: 44),
              site: const DiveSite(id: 'bh', name: 'Blue Hole, Dahab'),
            ),
          ],
        ),
      ],
    );
    expect(find.textContaining('Blue Hole, Dahab'), findsOneWidget);
    await tester.tap(find.byType(OnThisDayPanel));
    await tester.pumpAndSettle();
    expect(nav.location, '/dives/old');
  });

  testWidgets('conditional panels with nothing to show build nothing', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const Column(
        children: [
          OnThisDayPanel(),
          ActiveCoursePanel(),
          WaitingForDownloadPanel(),
          PhotosPanel(),
          RecentSitesPanel(),
        ],
      ),
      overrides: [
        onThisDayProvider.overrideWith((ref) async => []),
        activeCoursesProgressProvider.overrideWith((ref) async => []),
        recentSitesProvider.overrideWith((ref) async => []),
        recentMediaProvider.overrideWith((ref) async => <MediaItem>[]),
        draftDivesProvider.overrideWith((ref) async => <Dive>[]),
      ],
    );
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('recent dives survive text scale 2 at phone width', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const RecentDivesPanel(),
      width: 360,
      textScale: 2,
      overrides: [recentDivesProvider.overrideWith((ref) async => _dives)],
    );
    expect(tester.takeException(), isNull);
  });
}
