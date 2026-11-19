import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_seascape_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_3d_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_preview_provider.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../site_scape/presentation/site_terrain_pane_test_support.dart'
    show readyState;

/// The 3D views draw a correction a sitting holds without writing it
/// (issue #4527, plan 5).
void main() {
  NavTrack route({int samples = 0, String? siteId, GeoPoint? anchor}) =>
      NavTrack(
        id: 't1',
        siteId: siteId,
        source: NavTrackSource.seacraftEnc,
        startTime: 0,
        endTime: 600000,
        pointCount: samples,
        anchorLatitude: anchor?.latitude,
        anchorLongitude: anchor?.longitude,
        points: [
          for (var i = 0; i < samples; i++)
            NavTrackPoint(
              timestamp: i * 10,
              north: i * 10.0,
              east: 0,
              depth: 5.0 + i,
              distance: i * 10.0,
            ),
        ],
        createdAt: DateTime.utc(2026, 7, 28),
        updatedAt: DateTime.utc(2026, 7, 28),
      );

  ProviderContainer containerFor(NavTrack stored) {
    final container = ProviderContainer(
      overrides: [
        navTrackByIdProvider('t1').overrideWith((ref) async => stored),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a registered route is what the 3D scene data reads', () async {
    // Stored with no samples: the 3D preview has no profile to draw.
    final container = containerFor(route());
    final keep = container.listen(navTrack3dSceneDataProvider('t1'), (_, _) {});
    addTearDown(keep.close);
    expect(
      await container.read(navTrack3dSceneDataProvider('t1').future),
      isNull,
    );

    container.read(navTrackPreviewProvider('t1').notifier).state = route(
      samples: 10,
    );

    expect(
      await container.read(navTrack3dSceneDataProvider('t1').future),
      isNotNull,
    );
  });

  test('cleared, the 3D views read the route as stored again', () async {
    final stored = route(samples: 10);
    final container = containerFor(stored);
    final preview = route(samples: 10, anchor: const GeoPoint(1, 2));
    container.read(navTrackPreviewProvider('t1').notifier).state = preview;
    expect(
      (await container.read(navTrackShownIn3dProvider('t1').future))!.anchor,
      const GeoPoint(1, 2),
    );

    container.read(navTrackPreviewProvider('t1').notifier).state = null;

    expect(
      (await container.read(navTrackShownIn3dProvider('t1').future))!.anchor,
      isNull,
    );
  });

  test('a held site alone is shown differently', () {
    expect(
      navTrackShownDifferently(route(siteId: 's2'), route(siteId: 's1')),
      isTrue,
    );
  });

  test('two routes placed alike are not shown differently', () {
    final a = route(anchor: const GeoPoint(1, 2));
    expect(
      navTrackShownDifferently(a, route(anchor: const GeoPoint(1, 2))),
      isFalse,
    );
    expect(navTrackShownDifferently(a, route()), isTrue);
    expect(
      navTrackShownDifferently(
        a,
        a.withCorrection(a.correction.copyWith(scaleFactor: 2)),
      ),
      isTrue,
    );
    expect(
      navTrackShownDifferently(
        a,
        a.withCorrection(
          a.correction.copyWith(endMode: NavTrackEndMode.sameAsStart),
        ),
      ),
      isTrue,
    );
  });

  testWidgets('showNavTrackIn3d previews only a different placement, and only '
      'while the view is open', (tester) async {
    final overrides = await getBaseOverrides();
    final stored = route(anchor: const GeoPoint(1, 2));
    final moved = route(anchor: const GeoPoint(3, 4));
    final seen = <NavTrack?>[];
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await showNavTrackIn3d(
      widgetRef,
      shown: stored,
      stored: stored,
      push: () async => seen.add(widgetRef.read(navTrackPreviewProvider('t1'))),
    );
    await showNavTrackIn3d(
      widgetRef,
      shown: moved,
      stored: stored,
      push: () async => seen.add(widgetRef.read(navTrackPreviewProvider('t1'))),
    );

    expect(seen, [null, moved]);
    expect(widgetRef.read(navTrackPreviewProvider('t1')), isNull);
  });

  testWidgets('a route at a site opens its own seascape while a correction '
      'is held', (tester) async {
    final overrides = await getBaseOverrides();
    final stored = route(samples: 10, siteId: 'site-1');
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          navTrackByIdProvider('t1').overrideWith((ref) async => stored),
          navTrackPreviewProvider('t1').overrideWith(
            (ref) => route(
              samples: 10,
              siteId: 'site-1',
              anchor: const GeoPoint(1, 2),
            ),
          ),
          siteSeascapeProvider((
            siteId: 'site-1',
            isolatePaths: true,
          )).overrideWith((ref) async => readyState()),
          siteFeaturesProvider('site-1').overrideWith((ref) async => []),
        ],
        child: const NavTrackSeascapePage(trackId: 't1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SiteTerrainPane), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the preview is cleared even when its opener has gone', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final showOpener = ValueNotifier(true);
    final closeView = Completer<void>();
    WidgetRef? openerRef;
    late WidgetRef readerRef;
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Column(
          children: [
            Consumer(
              builder: (context, ref, _) {
                readerRef = ref;
                return const SizedBox.shrink();
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: showOpener,
              builder: (context, shown, _) => shown
                  ? Consumer(
                      builder: (context, ref, _) {
                        openerRef = ref;
                        return const SizedBox.shrink();
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
    final moved = route(anchor: const GeoPoint(3, 4));

    final shown = showNavTrackIn3d(
      openerRef!,
      shown: moved,
      stored: route(),
      push: () => closeView.future,
    );
    expect(readerRef.read(navTrackPreviewProvider('t1')), moved);
    showOpener.value = false;
    await tester.pump();
    closeView.complete();
    await shown;

    expect(readerRef.read(navTrackPreviewProvider('t1')), isNull);
  });
}
