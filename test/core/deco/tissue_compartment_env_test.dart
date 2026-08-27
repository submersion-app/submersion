import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

TissueCompartment _comp1({double pN2 = 2.5, double pHe = 0.0}) {
  return TissueCompartment(
    compartmentNumber: 1,
    halfTimeN2: zhl16cN2HalfTimes[0],
    halfTimeHe: zhl16cHeHalfTimes[0],
    mValueAN2: zhl16cN2A[0],
    mValueBN2: zhl16cN2B[0],
    mValueAHe: zhl16cHeA[0],
    mValueBHe: zhl16cHeB[0],
    currentPN2: pN2,
    currentPHe: pHe,
  );
}

void main() {
  test('ceilingPressureBar is the pressure form of the legacy ceiling', () {
    final comp = _comp1();
    // Legacy: meters = (pBar - 1.0) * 10.0, clamped at 0.
    final pBar = comp.ceilingPressureBar(gf: 0.8);
    final legacyMeters = comp.ceiling(gf: 0.8);
    expect(legacyMeters, closeTo(((pBar - 1.0) * 10.0).clamp(0, 999), 1e-9));
  });

  test('ceilingPressureBar can be below 1 bar (clean tissue)', () {
    final comp = _comp1(pN2: inspiredSurfaceN2Bar);
    expect(comp.ceilingPressureBar(gf: 1.0), lessThan(1.0));
    expect(comp.ceiling(gf: 1.0), 0.0); // legacy clamps to 0
  });

  test('DecoStatus.surfGf evaluates at its surfacePressureBar', () {
    final comp = _comp1(pN2: 2.5);
    final atSeaLevel = DecoStatus(
      compartments: [comp],
      ndlSeconds: -1,
      ceilingMeters: 5,
      ttsSeconds: 600,
      gfLow: 0.3,
      gfHigh: 0.7,
      decoStops: const [],
      currentDepthMeters: 10,
      ambientPressureBar: 2.0,
    );
    final atAltitude = atSeaLevel.copyWith(surfacePressureBar: 0.795);
    // Lower surface pressure -> bigger supersaturation gradient at surface.
    expect(atAltitude.surfGf, greaterThan(atSeaLevel.surfGf));
    // Default (1.0 bar) matches the legacy surfaceGradientFactor path.
    expect(
      atSeaLevel.surfGf,
      closeTo((comp.surfaceGradientFactor * 100.0).clamp(0.0, 9999), 1e-9),
    );
  });
}
