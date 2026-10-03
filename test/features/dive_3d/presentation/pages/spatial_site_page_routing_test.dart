import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_playback_context.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/dive_3d/presentation/pages/spatial_site_page.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../site_scape/presentation/site_terrain_pane_test_support.dart'
    show readyState;

const _site = DiveSite(id: 'site-1', name: 'Salt Pier');

void main() {
  testWidgets(
    'a dive with a site routes to SiteTerrainPane with a dive playback context',
    (tester) async {
      final overrides = await getBaseOverrides();
      // Never completes until told to: lets the assertion below observe the
      // frame BEFORE diveProvider resolves, so a regression that reads
      // .valueOrNull before the dive settles (routing to the standalone
      // implementation's own expensive fetch while still loading) would
      // actually fail this test instead of passing once everything settles.
      final completer = Completer<Dive>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(
            Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 28)),
          );
        }
      });
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            diveProvider('d1').overrideWith((ref) => completer.future),
            siteSeascapeProvider(
              'site-1',
            ).overrideWith((ref) async => readyState()),
            siteFeaturesProvider('site-1').overrideWith((ref) async => []),
            siteActivePathOverlayProvider((
              siteId: 'site-1',
              pathId: 'd1',
              source: PathOverlaySource.dive,
            )).overrideWith((ref) async => null),
          ],
          child: const SpatialSitePage(diveId: 'd1'),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(SiteTerrainPane), findsNothing);
      expect(find.byType(Dive3dInteractiveViewport), findsNothing);

      completer.complete(
        Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 28), site: _site),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final pane = tester.widget<SiteTerrainPane>(find.byType(SiteTerrainPane));
      expect(pane.siteId, 'site-1');
      expect(pane.playbackContext, isA<DivePlaybackContext>());
      expect((pane.playbackContext as DivePlaybackContext).diveId, 'd1');
    },
  );

  testWidgets('a dive with no site keeps the standalone implementation', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          diveProvider('d1').overrideWith(
            (ref) async => Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 28)),
          ),
        ],
        child: const SpatialSitePage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SiteTerrainPane), findsNothing);
    expect(find.byType(Dive3dInteractiveViewport), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'a dive whose site has no coordinates keeps the standalone implementation',
    (tester) async {
      // SiteTerrainPane would only show a "no coordinates" message there,
      // with no path or timeline; the standalone view still plays it back.
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            diveProvider('d1').overrideWith(
              (ref) async => Dive(
                id: 'd1',
                dateTime: DateTime.utc(2026, 7, 28),
                site: _site,
              ),
            ),
            siteSeascapeProvider(
              'site-1',
            ).overrideWith((ref) async => const SiteSeascapeNoCoordinates()),
          ],
          child: const SpatialSitePage(diveId: 'd1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SiteTerrainPane), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
