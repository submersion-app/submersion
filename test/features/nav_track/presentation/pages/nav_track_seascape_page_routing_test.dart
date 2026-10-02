import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_playback_context.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_seascape_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../site_scape/presentation/site_terrain_pane_test_support.dart'
    show readyState;

NavTrack _track({required String id, String? siteId}) => NavTrack(
  id: id,
  siteId: siteId,
  source: NavTrackSource.seacraftEnc,
  startTime: 0,
  endTime: 60,
  pointCount: 0,
  createdAt: DateTime.utc(2026, 7, 28),
  updatedAt: DateTime.utc(2026, 7, 28),
);

void main() {
  testWidgets(
    'a route with a site routes to SiteTerrainPane with a nav-track playback context',
    (tester) async {
      final overrides = await getBaseOverrides();
      // Never completes until told to: lets the assertion below observe
      // the frame BEFORE navTrackByIdProvider resolves (see the matching
      // dive-side test for why this matters).
      final completer = Completer<NavTrack>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete(_track(id: 't1'));
      });
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            navTrackByIdProvider('t1').overrideWith((ref) => completer.future),
            siteSeascapeProvider(
              'site-1',
            ).overrideWith((ref) async => readyState()),
            siteFeaturesProvider('site-1').overrideWith((ref) async => []),
            siteActivePathOverlayProvider((
              siteId: 'site-1',
              pathId: 't1',
              source: PathOverlaySource.navTrack,
            )).overrideWith((ref) async => null),
          ],
          child: const NavTrackSeascapePage(trackId: 't1'),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(SiteTerrainPane), findsNothing);

      completer.complete(_track(id: 't1', siteId: 'site-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final pane = tester.widget<SiteTerrainPane>(find.byType(SiteTerrainPane));
      expect(pane.siteId, 'site-1');
      expect(pane.playbackContext, isA<NavTrackPlaybackContext>());
      expect((pane.playbackContext as NavTrackPlaybackContext).trackId, 't1');
    },
  );

  testWidgets('a route with no site keeps the standalone implementation', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          navTrackByIdProvider(
            't1',
          ).overrideWith((ref) async => _track(id: 't1')),
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

  testWidgets(
    'a route whose site has no coordinates keeps the standalone implementation',
    (tester) async {
      // SiteTerrainPane would only show a "no coordinates" message there,
      // with no path or timeline; the standalone view still plays it back.
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            navTrackByIdProvider(
              't1',
            ).overrideWith((ref) async => _track(id: 't1', siteId: 'site-1')),
            siteSeascapeProvider(
              'site-1',
            ).overrideWith((ref) async => const SiteSeascapeNoCoordinates()),
          ],
          child: const NavTrackSeascapePage(trackId: 't1'),
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
