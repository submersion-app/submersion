import 'package:flutter/material.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/panels/conditional_panels.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/download_target_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import 'panel_harness.dart';

/// Each row in a conditional panel opens its own item, as the retired cards'
/// rows did; only the panel's empty space falls back to the panel's action.
void main() {
  Course course(String id, String name) => Course(
    id: id,
    diverId: 'me',
    name: name,
    agency: 'padi',
    startDate: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  testWidgets('a later on-this-day dive opens that dive', (tester) async {
    final nav = await pumpPanel(
      tester,
      const OnThisDayPanel(),
      overrides: [
        onThisDayProvider.overrideWith(
          (ref) async => [
            Dive(
              id: 'old1',
              dateTime: DateTime.utc(2024, 11, 20),
              site: const DiveSite(id: 'a', name: 'Blue Hole'),
            ),
            Dive(
              id: 'old2',
              dateTime: DateTime.utc(2022, 11, 20),
              site: const DiveSite(id: 'b', name: 'Canyon'),
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.text('Canyon'));
    await tester.pumpAndSettle();
    expect(nav.location, '/dives/old2');
  });

  testWidgets('a second course opens that course', (tester) async {
    final nav = await pumpPanel(
      tester,
      const ActiveCoursePanel(),
      overrides: [
        activeCoursesProgressProvider.overrideWith(
          (ref) async => [
            (
              course: course('c1', 'Rescue Diver'),
              progress: const CourseProgress(courseId: 'c1', requirements: []),
            ),
            (
              course: course('c2', 'Nitrox'),
              progress: const CourseProgress(courseId: 'c2', requirements: []),
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.text('Nitrox'));
    await tester.pumpAndSettle();
    expect(nav.location, '/courses/c2');
  });

  testWidgets('a waiting draft opens that dive, not a download', (
    tester,
  ) async {
    final nav = await pumpPanel(
      tester,
      const WaitingForDownloadPanel(),
      overrides: [
        draftDivesProvider.overrideWith(
          (ref) async => [
            Dive(
              id: 'draft1',
              dateTime: DateTime.utc(2026, 11, 8),
              exitTime: DateTime.utc(2026, 11, 8, 11),
              site: const DiveSite(id: 's', name: 'Salt Pier'),
            ),
          ],
        ),
        downloadTargetComputerProvider.overrideWith((ref) async => null),
      ],
    );
    await tester.tap(find.text('Salt Pier'));
    await tester.pumpAndSettle();
    expect(nav.location, '/dives/draft1');
  });

  // The panel opens the computer the diver downloaded from last, or the
  // computer list when there is none to pick (issue #637).
  for (final (computer, route) in [
    (
      DiveComputer(
        id: 'pc1',
        name: 'Perdix',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      '/dive-computers/pc1/download',
    ),
    (null, '/dive-computers'),
  ]) {
    testWidgets('waiting for download opens $route', (tester) async {
      final nav = await pumpPanel(
        tester,
        const WaitingForDownloadPanel(),
        overrides: [
          draftDivesProvider.overrideWith(
            (ref) async => [
              Dive(
                id: 'draft1',
                dateTime: DateTime.utc(2026, 11, 8),
                exitTime: DateTime.utc(2026, 11, 8, 11),
              ),
            ],
          ),
          downloadTargetComputerProvider.overrideWith((ref) async => computer),
        ],
      );
      await tester.tap(find.textContaining('WAITING FOR YOUR DIVE COMPUTER'));
      await tester.pumpAndSettle();
      expect(nav.location, route);
    });
  }

  testWidgets('the trip checklist row opens the trip beside a pre-dive row', (
    tester,
  ) async {
    final trip = Trip(
      id: 't1',
      name: 'Bonaire',
      startDate: DateTime.now().add(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final nav = await pumpPanel(
      tester,
      const PreDivePanel(),
      overrides: [
        preDiveActiveSessionProvider.overrideWith((ref) async => null),
        preDiveSessionsProvider.overrideWith(
          (ref) async => [
            PreDiveSession(
              id: 's1',
              templateName: 'Boat dive',
              startedAt: DateTime(2026),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              status: PreDiveSessionStatus.completed,
            ),
          ],
        ),
        preDiveTemplatesProvider.overrideWith((ref) async => []),
        homeTripChecklistProvider.overrideWith(
          (ref) async => (trip: trip, done: 2, total: 5),
        ),
      ],
    );
    await tester.tap(find.textContaining('Bonaire'));
    await tester.pumpAndSettle();
    expect(nav.location, '/trips/t1');
  });

  testWidgets('a pre-dive run under way resumes from its row', (tester) async {
    final active = PreDiveSession(
      id: 'run1',
      templateName: 'Boat dive',
      startedAt: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final nav = await pumpPanel(
      tester,
      const PreDivePanel(),
      overrides: [
        preDiveActiveSessionProvider.overrideWith((ref) async => active),
        preDiveSessionsProvider.overrideWith((ref) async => [active]),
        preDiveTemplatesProvider.overrideWith((ref) async => []),
        preDiveSessionItemsProvider('run1').overrideWith((ref) async => []),
        homeTripChecklistProvider.overrideWith((ref) async => null),
      ],
    );
    await tester.tap(find.textContaining('Resume'));
    await tester.pumpAndSettle();
    expect(nav.location, '/pre-dive-sessions/run1');
  });

  testWidgets('recent sites shows its map and opens the sites list', (
    tester,
  ) async {
    final nav = await pumpPanel(
      tester,
      const RecentSitesPanel(),
      overrides: [
        recentSitesProvider.overrideWith(
          (ref) async => const [
            RecentSitePin(
              siteName: 'Salt Pier',
              latitude: 12.08,
              longitude: -68.28,
            ),
            RecentSitePin(
              siteName: 'Bari Reef',
              latitude: 12.16,
              longitude: -68.28,
            ),
          ],
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('RECENT SITES'), findsOneWidget);
    await tester.tap(find.text('RECENT SITES'));
    await tester.pumpAndSettle();
    expect(nav.location, '/sites');
  });

  testWidgets(
    "the sites map's attribution opens, and the map itself opens the sites",
    (tester) async {
      final nav = await pumpPanel(
        tester,
        const RecentSitesPanel(),
        overrides: [
          recentSitesProvider.overrideWith(
            (ref) async => const [
              RecentSitePin(
                siteName: 'Salt Pier',
                latitude: 12.08,
                longitude: -68.28,
              ),
            ],
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 100));
      // The tile credit starts folded into an info button, which must take
      // its own tap rather than pass it to the panel.
      await tester.tap(find.byTooltip('Attributions'));
      await tester.pump();
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
      expect(nav.location, isNull);

      await tester.tapAt(tester.getCenter(find.byType(RecentSitesPanel)));
      await tester.pumpAndSettle();
      expect(nav.location, '/sites');
    },
  );

  group('the recent sites map', () {
    var pins = <RecentSitePin>[];
    const salt = RecentSitePin(
      siteName: 'Salt Pier',
      latitude: 12.08,
      longitude: -68.28,
    );
    const bari = RecentSitePin(
      siteName: 'Bari Reef',
      latitude: 12.16,
      longitude: -68.28,
    );
    const klein = RecentSitePin(
      siteName: 'Klein Bonaire',
      latitude: 12.16,
      longitude: -68.32,
    );

    Future<void> pumpMap(WidgetTester tester) async {
      await pumpPanel(
        tester,
        const RecentSitesPanel(),
        overrides: [recentSitesProvider.overrideWith((ref) async => pins)],
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<Element> reloadWith(
      WidgetTester tester,
      List<RecentSitePin> next,
    ) async {
      pins = next;
      ProviderScope.containerOf(
        tester.element(find.byType(RecentSitesPanel)),
      ).invalidate(recentSitesProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return tester.element(find.byType(FlutterMap));
    }

    // Keyed by its pins, unordered: the same sites again keep the map and
    // its tiles, and only a new site reframes it.
    testWidgets('keeps the map for the same pins in any order', (tester) async {
      pins = [salt, bari];
      await pumpMap(tester);
      final first = tester.element(find.byType(FlutterMap));
      expect(await reloadWith(tester, [bari, salt]), same(first));
      expect(await reloadWith(tester, [bari, salt]), same(first));
      expect(await reloadWith(tester, [bari, salt, klein]), isNot(same(first)));
    });

    testWidgets('one pin still draws, with one marker', (tester) async {
      pins = [salt];
      await pumpMap(tester);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a video in recent media carries its badge', (tester) async {
    await pumpPanel(
      tester,
      const PhotosPanel(),
      overrides: [
        recentMediaProvider.overrideWith(
          (ref) async => [
            MediaItem(
              id: 'v1',
              diveId: 'd1',
              mediaType: MediaType.video,
              sourceType: MediaSourceType.platformGallery,
              filePath: '/tmp/v1.mov',
              takenAt: DateTime(2026, 7, 1),
              createdAt: DateTime(2026, 7, 1),
              updatedAt: DateTime(2026, 7, 1),
            ),
          ],
        ),
      ],
    );
    expect(find.byIcon(Icons.play_circle), findsOneWidget);
  });
}
