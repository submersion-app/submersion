import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_scale_layout.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_scale_geometry.dart';

/// Turning a pointer position into a level on the scale (issue #4569).
void main() {
  VerticalScaleGeometry at(double total) => VerticalScaleGeometry(
    width: 400,
    layout: VerticalScaleLayout.compute(
      totalMeters: total,
      halfHeightPx: kVerticalScaleHalfHeight,
    ),
    labelsOnLeft: true,
  );

  test('the nearer of a passed tick and the next landmark wins', () {
    // Total 8,700: K2 (8,611) is passed and Everest (8,849) is next, under
    // 5 px apart. Half a pixel from K2 is K2, not Everest.
    final g = at(8700);
    final k2 = g.layout.offsetFor(8611);
    final everest = g.layout.offsetFor(8849);
    expect(everest - k2, lessThan(6));

    final onK2 = g.probeAt(Offset(200, g.seaY - (k2 + 0.5)))!;
    expect(onK2.landmark!.id, VerticalLandmarkId.k2);
    expect(onK2.ahead, isFalse);

    final onEverest = g.probeAt(Offset(200, g.seaY - (everest - 0.5)))!;
    expect(onEverest.landmark!.id, VerticalLandmarkId.everest);
    expect(onEverest.ahead, isTrue);
  });

  test('a level reads along the bar whatever the sideways position', () {
    final g = at(6380);
    final y = g.seaY + 130;
    final onBar = g.levelAt(y)!;
    expect(onBar.meters, closeTo(g.layout.metersAt(130), 1e-9));
    expect(onBar.direction, VerticalLeg.descent);
    // Past the bar's end there is no level.
    expect(g.levelAt(g.seaY + g.layout.barPx + 20), isNull);
  });
}
