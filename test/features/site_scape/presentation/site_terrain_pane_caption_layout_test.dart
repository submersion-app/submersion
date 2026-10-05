import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_playback_context.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_active_path_overlay_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

import 'site_terrain_pane_test_support.dart';

SiteActivePathOverlay _overlay() => buildSiteActivePathOverlay(
  path: const ReckonedPath(
    points: [
      ReckonedPoint(east: 0, north: 0, depth: 0, timeSeconds: 0),
      ReckonedPoint(east: 5, north: 0, depth: 8, timeSeconds: 60),
    ],
    provenance: PathProvenance.measured,
    sourceLabel: 'Seacraft ENC',
    minEast: 0,
    maxEast: 5,
    minNorth: 0,
    maxNorth: 0,
    maxDepth: 8,
    durationSeconds: 60,
  ),
  anchor: (east: 0.0, north: 0.0),
  projection: SpatialProjection(
    minEast: -50,
    maxEast: 50,
    minNorth: -50,
    maxNorth: 50,
    maxDepth: 20,
  ),
)!;

/// Stands in for a host's 2D/3D toggle: the fullscreen scape seats two
/// extra buttons in the docked card, which makes it wider.
const _hostToggle = [
  IconButton(onPressed: null, icon: Icon(Icons.map_outlined, size: 20)),
  IconButton(onPressed: null, icon: Icon(Icons.terrain, size: 20)),
];

void main() {
  // The overlays are placed against the pane's physical left edge, like the
  // docked card and the zoom column they keep clear of on the right; a
  // right-to-left locale must not mirror the legend over to the controls.
  testWidgets('the depth legend stays at the left edge in a right-to-left '
      'locale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(page(readyState(), locale: const Locale('ar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.getRect(find.byKey(const ValueKey('seascapeDepthLegend'))).left,
      8,
    );
  });

  // On a phone-width pane the source caption ran under the docked control
  // card at the top right, and the overlays stacked below it at fixed
  // offsets collided once it wrapped.
  for (final width in const [320.0, 360.0, 390.0]) {
    for (final withToggle in const [false, true]) {
      for (final withPlayback in const [false, true]) {
        final label =
            '${width.round()}px wide'
            '${withToggle ? ', with a host toggle' : ''}'
            '${withPlayback ? ', with a dive caption' : ''}';
        testWidgets('the top-left overlays clear the docked card, $label', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 520));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            page(
              readyState(),
              leadingActions: withToggle ? _hostToggle : const [],
              playbackContext: withPlayback
                  ? const DivePlaybackContext('d1')
                  : null,
              extraOverrides: [
                siteActivePathOverlayProvider((
                  siteId: 'site-1',
                  pathId: 'd1',
                  source: PathOverlaySource.dive,
                )).overrideWith(
                  (ref) async => (overlay: _overlay(), hasLinkedRoute: false),
                ),
              ],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          final dock = tester.getRect(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('seascapeAppearanceButton')),
                  matching: find.byType(Card),
                )
                .first,
          );
          final overlays = <String, Rect>{
            'source caption': tester.getRect(find.textContaining('Seafloor')),
            'depth legend': tester.getRect(
              find.byKey(const ValueKey('seascapeDepthLegend')),
            ),
            if (withPlayback)
              'dive caption': tester.getRect(
                find.text('Recorded track (Seacraft ENC)'),
              ),
          };

          expect(tester.takeException(), isNull);
          overlays.forEach((name, rect) {
            expect(
              rect.overlaps(dock),
              isFalse,
              reason: '$name $rect overlaps the docked card $dock',
            );
          });
          final names = overlays.keys.toList();
          for (var i = 0; i < names.length; i++) {
            for (var j = i + 1; j < names.length; j++) {
              final a = overlays[names[i]]!;
              final b = overlays[names[j]]!;
              expect(
                a.overlaps(b),
                isFalse,
                reason: '${names[i]} $a overlaps ${names[j]} $b',
              );
            }
          }

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }
}
