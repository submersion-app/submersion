import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_playback_context.dart';

import 'site_terrain_pane_test_support.dart';

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
                  (ref) async => (
                    overlay: testActivePathOverlay(sourceLabel: 'Seacraft ENC'),
                    hasLinkedRoute: false,
                  ),
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

  Rect dockRect(WidgetTester tester) => tester.getRect(
    find
        .ancestor(
          of: find.byKey(const ValueKey('seascapeAppearanceButton')),
          matching: find.byType(Card),
        )
        .first,
  );

  // The docked card's width is only known once it has been laid out with
  // the pane's own actions in it, which happens when the scene is ready; the
  // caption must not be drawn under it on any frame before then.
  for (final withToggle in const [false, true]) {
    testWidgets('the source caption never overlaps the docked card on any '
        'frame${withToggle ? ', with a host toggle' : ''}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        page(readyState(), leadingActions: withToggle ? _hostToggle : const []),
      );
      var sawCaption = false;
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump();
        final caption = find.textContaining('Seafloor');
        if (caption.evaluate().isEmpty) continue;
        sawCaption = true;
        final rect = tester.getRect(caption);
        final dock = dockRect(tester);
        expect(
          rect.overlaps(dock),
          isFalse,
          reason: 'frame $frame: caption $rect overlaps the docked card $dock',
        );
      }
      expect(sawCaption, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  // Beside a wide docked card on a narrow pane the column would be squeezed
  // to a sliver; there it goes below the card instead.
  testWidgets('on a pane too narrow for both, the overlays drop below the '
      'docked card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(240, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(page(readyState(), leadingActions: _hostToggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    final caption = tester.getRect(find.textContaining('Seafloor'));
    final dock = dockRect(tester);
    expect(caption.top, greaterThanOrEqualTo(dock.bottom));
    expect(caption.width, greaterThan(150));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
