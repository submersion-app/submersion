import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/domain/figure_space.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// Zones are the anchor points every label and every piece is placed by, so
/// they have to lie inside the figure and the left/right pairs have to be
/// true mirrors: a piece authored for the left twin is flipped onto the right.
void main() {
  test('every zone anchors inside the figure box', () {
    for (final zone in FigureZone.values) {
      expect(
        zone.anchorX,
        inInclusiveRange(0, kFigureWidth),
        reason: zone.name,
      );
      expect(
        zone.anchorY,
        inInclusiveRange(0, kFigureHeight),
        reason: zone.name,
      );
      expect(zone.capacity, greaterThanOrEqualTo(1), reason: zone.name);
    }
  });

  test('both views have zones', () {
    for (final view in FigureView.values) {
      expect(FigureZone.values.where((z) => z.view == view), isNotEmpty);
    }
  });

  test('mirrored zones sit at the mirror of an unmirrored twin', () {
    const pairs = {
      FigureZone.chestClipRight: FigureZone.chestClipLeft,
      FigureZone.wristRight: FigureZone.wristLeft,
      FigureZone.handRight: FigureZone.handLeft,
      FigureZone.hipRight: FigureZone.hipLeft,
      FigureZone.thighRight: FigureZone.thighLeft,
      FigureZone.stageRight: FigureZone.stageLeft,
      FigureZone.trimLeft: FigureZone.trimRight,
      FigureZone.sidemountLeft: FigureZone.sidemountRight,
    };
    for (final entry in pairs.entries) {
      final mirrored = entry.key;
      final twin = entry.value;
      expect(mirrored.mirrored, isTrue, reason: mirrored.name);
      expect(twin.mirrored, isFalse, reason: twin.name);
      expect(mirrored.view, twin.view, reason: mirrored.name);
      expect(mirrored.anchorX, closeTo(kFigureWidth - twin.anchorX, 0.001));
      expect(mirrored.anchorY, closeTo(twin.anchorY, 0.001));
    }
    final mirroredZones = FigureZone.values.where((z) => z.mirrored).toSet();
    expect(
      mirroredZones.difference({FigureZone.cameraArm}),
      pairs.keys.toSet(),
      reason: 'every mirrored zone must be listed here with its twin',
    );
  });
}
