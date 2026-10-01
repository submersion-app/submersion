import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_playback_context.dart';
import 'package:submersion/features/dive_3d/presentation/pages/spatial_site_page.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _site = DiveSite(id: 'site-1', name: 'Salt Pier');

void main() {
  testWidgets(
    'a dive with a site routes to SiteTerrainPane with a dive playback context',
    (tester) async {
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
}
