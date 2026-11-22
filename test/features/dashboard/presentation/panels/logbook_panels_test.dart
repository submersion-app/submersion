import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
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
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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

    // Plotted against the sample times, so uneven spacing keeps its shape.
    testWidgets('the profile is drawn against its sample times', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        const LatestProfilePanel(),
        overrides: [
          homeLatestProfileProvider.overrideWith(
            (ref) async => (
              dive: _dives.first,
              points: [(0.0, 0.0), (120.0, 18.4), (2400.0, 5.0), (2580.0, 0.0)],
            ),
          ),
        ],
      );
      final line = tester.widget<HomeSparkline>(find.byType(HomeSparkline));
      expect(line.values, [0.0, 18.4, 5.0, 0.0]);
      expect(line.xs, [0.0, 120.0, 2400.0, 2580.0]);
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

    testWidgets('a dive with no site goes by its own name', (tester) async {
      final handle = tester.ensureSemantics();
      final unsited = Dive(
        id: 'n1',
        dateTime: DateTime.utc(2026, 11, 9, 21),
        entryTime: DateTime.utc(2026, 11, 9, 21),
        runtime: const Duration(minutes: 40),
        maxDepth: 12,
        name: 'Night drift',
      );
      await pumpPanel(
        tester,
        const LatestVsAveragePanel(),
        overrides: [
          recentDivesProvider.overrideWith((ref) async => [unsited]),
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
      expect(find.text('Night drift'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Latest dive vs average, Night drift'),
        findsOneWidget,
      );
      handle.dispose();
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
        homeSpeciesCountProvider.overrideWith((ref) async => 143),
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

  testWidgets(
    'each recent dive row stays its own tap target for screen readers',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPanel(
        tester,
        const RecentDivesPanel(),
        width: 900,
        overrides: [recentDivesProvider.overrideWith((ref) async => _dives)],
      );
      final node = tester.getSemantics(find.text('Something Special'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    },
  );

  testWidgets('the photos panel opens the media library', (tester) async {
    final nav = await pumpPanel(
      tester,
      const PhotosPanel(),
      overrides: [
        recentMediaProvider.overrideWith(
          (ref) async => [
            MediaItem(
              id: 'p1',
              mediaType: MediaType.photo,
              sourceType: MediaSourceType.platformGallery,
              filePath: '/tmp/p1.jpg',
              takenAt: DateTime(2026, 7, 1),
              createdAt: DateTime(2026, 7, 1),
              updatedAt: DateTime(2026, 7, 1),
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.text('RECENT MEDIA'));
    await tester.pumpAndSettle();
    expect(nav.location, '/media');
  });

  // Home shows a grid of small tiles: each decodes a thumbnail sized to its
  // tile, never the full-resolution original.
  testWidgets('recent media decodes thumbnails sized to their tiles', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const PhotosPanel(),
      overrides: [
        recentMediaProvider.overrideWith(
          (ref) async => [
            for (var i = 0; i < 6; i++)
              MediaItem(
                id: 'p$i',
                diveId: 'd1',
                mediaType: MediaType.photo,
                sourceType: MediaSourceType.platformGallery,
                filePath: '/tmp/p$i.jpg',
                takenAt: DateTime(2026, 7, 1),
                createdAt: DateTime(2026, 7, 1),
                updatedAt: DateTime(2026, 7, 1),
              ),
          ],
        ),
      ],
    );
    final views = find.byType(MediaItemView);
    expect(views, findsWidgets);
    final dpr = tester.view.devicePixelRatio;
    for (final e in views.evaluate()) {
      final view = e.widget as MediaItemView;
      final tile = tester.getSize(find.byWidget(view));
      expect(view.thumbnail, isTrue);
      expect(view.targetSize, isNotNull);
      expect(
        view.targetSize!.longestSide,
        lessThanOrEqualTo(tile.longestSide * dpr + 0.5),
      );
    }
  });

  testWidgets('latest vs average with no average draws no bars', (
    tester,
  ) async {
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
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('latest vs average while loading does not claim no dives', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const LatestVsAveragePanel(),
      overrides: [
        recentDivesProvider.overrideWith(
          (ref) => Completer<List<Dive>>().future,
        ),
        homeAveragesProvider.overrideWith(
          (ref) async => (
            averages: const HomeAverages(
              maxDepth: 20,
              runtimeSeconds: 2000,
              diveCount: 3,
            ),
            sac: null,
          ),
        ),
        homeSacSeriesProvider.overrideWith((ref) async => []),
      ],
    );
    expect(find.text('No dives logged yet'), findsNothing);
  });

  testWidgets('the latest profile names its numbers before the site', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const LatestProfilePanel(),
      overrides: [
        homeLatestProfileProvider.overrideWith(
          (ref) async => (
            dive: _dives.first,
            points: [(0.0, 0.0), (600.0, 18.4), (3120.0, 0.0)],
          ),
        ),
      ],
    );
    expect(find.textContaining(RegExp(r'^18\.4')), findsOneWidget);
  });

  testWidgets('a recent dive row reads as Dive N at its site', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPanel(
      tester,
      const RecentDivesPanel(),
      width: 900,
      overrides: [
        recentDivesProvider.overrideWith(
          (ref) async => [
            Dive(
              id: 'd412',
              diveNumber: 412,
              dateTime: DateTime.utc(2026, 11, 8),
              site: const DiveSite(id: 's', name: 'Salt Pier'),
            ),
          ],
        ),
      ],
    );
    final row = find.bySemanticsLabel('Dive 412 at Salt Pier');
    expect(row, findsOneWidget);
    final data = tester.getSemantics(row).getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isButton, isTrue);
    handle.dispose();
  });
  testWidgets("latest vs average shows gas in the diver's unit", (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const LatestVsAveragePanel(),
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      overrides: [
        recentDivesProvider.overrideWith((ref) async => _dives),
        homeAveragesProvider.overrideWith(
          (ref) async => (
            averages: const HomeAverages(
              maxDepth: null,
              runtimeSeconds: null,
              diveCount: 0,
            ),
            sac: 18.0,
          ),
        ),
        homeSacSeriesProvider.overrideWith(
          (ref) async => [
            TrendDataPoint(
              date: DateTime(2026, 11, 8),
              value: 16,
              diveId: 'd3',
            ),
          ],
        ),
      ],
    );
    // 16 and 18 L/min are 0.57 and 0.64 cuft/min, at RMV's two places.
    expect(find.text('0.57 cuft/min · avg 0.64 cuft/min'), findsOneWidget);
  });

  testWidgets('the latest profile leaves out a missing site', (tester) async {
    await pumpPanel(
      tester,
      const LatestProfilePanel(),
      overrides: [
        homeLatestProfileProvider.overrideWith(
          (ref) async => (
            dive: Dive(
              id: 'x',
              dateTime: DateTime.utc(2026, 11, 8, 10),
              runtime: const Duration(minutes: 41),
              maxDepth: 18.2,
            ),
            points: [(0.0, 0.0), (600.0, 18.2), (2460.0, 0.0)],
          ),
        ),
      ],
    );
    expect(find.text("18.2m · 41'"), findsOneWidget);
  });

  testWidgets('an unnamed recent dive adds no empty name to the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpPanel(
      tester,
      const RecentDivesPanel(),
      width: 900,
      overrides: [
        recentDivesProvider.overrideWith(
          (ref) async => [
            _dives.first,
            Dive(id: 'x', dateTime: DateTime.utc(2026, 11, 1, 10)),
          ],
        ),
      ],
    );
    expect(find.bySemanticsLabel('Recent dives, Salt Pier'), findsOneWidget);
    handle.dispose();
  });
}
