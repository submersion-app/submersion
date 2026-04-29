import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

/// Create a list of ZH-L16C compartments with uniform tissue tension.
List<TissueCompartment> createCompartments({
  double pN2 = inspiredSurfaceN2Bar,
  double pHe = 0.0,
}) {
  return List.generate(zhl16CompartmentCount, (i) {
    return TissueCompartment(
      compartmentNumber: i + 1,
      halfTimeN2: zhl16cN2HalfTimes[i],
      halfTimeHe: zhl16cHeHalfTimes[i],
      mValueAN2: zhl16cN2A[i],
      mValueBN2: zhl16cN2B[i],
      mValueAHe: zhl16cHeA[i],
      mValueBHe: zhl16cHeB[i],
      currentPN2: pN2,
      currentPHe: pHe,
    );
  });
}

/// Create a DecoStatus with given compartments and ambient pressure.
DecoStatus createStatus({
  required List<TissueCompartment> compartments,
  double ambientPressureBar = 1.0,
  double currentDepthMeters = 0.0,
}) {
  return DecoStatus(
    compartments: compartments,
    ndlSeconds: 999 * 60,
    ceilingMeters: 0,
    ttsSeconds: 0,
    gfLow: 0.3,
    gfHigh: 0.7,
    decoStops: const [],
    currentDepthMeters: currentDepthMeters,
    ambientPressureBar: ambientPressureBar,
  );
}

void main() {
  group('DecoStatus.gf99', () {
    test('returns near-zero for surface-saturated tissues at surface', () {
      final status = createStatus(
        compartments: createCompartments(),
        ambientPressureBar: 1.0,
      );
      // Surface-saturated tissues (inspired surface N2) at 1.0 bar ambient
      // GF is clamped at 0 (undersaturated, but negatives not displayed)
      expect(status.gf99, equals(0.0));
    });

    test('returns 0.0 for empty compartments', () {
      final status = createStatus(
        compartments: const [],
        ambientPressureBar: 1.0,
      );
      expect(status.gf99, equals(0.0));
    });

    test('finds max GF across all compartments', () {
      // Create compartments with different tissue tensions
      // Compartment 1 (fast) with high loading, others normal
      final comps = createCompartments();
      final loaded = comps[0].copyWith(currentPN2: 2.5);
      final modified = [loaded, ...comps.skip(1)];

      final status = createStatus(
        compartments: modified,
        ambientPressureBar: 1.0,
      );

      // GF99 should be the GF of compartment 1 (the loaded one)
      final expectedGf = loaded.gradientFactor(1.0) * 100.0;
      expect(status.gf99, closeTo(expectedGf, 0.01));
    });

    test('increases with tissue loading', () {
      final low = createStatus(
        compartments: createCompartments(pN2: 1.0),
        ambientPressureBar: 1.0,
      );
      final high = createStatus(
        compartments: createCompartments(pN2: 2.0),
        ambientPressureBar: 1.0,
      );
      expect(high.gf99, greaterThan(low.gf99));
    });
  });

  group('DecoStatus.surfGf', () {
    test('returns near-zero for surface-saturated tissues', () {
      final status = createStatus(compartments: createCompartments());
      // Surface-saturated tissues should have near-zero or negative SurfGF
      expect(status.surfGf, lessThan(5.0));
    });

    test('returns 0.0 for empty compartments', () {
      final status = createStatus(compartments: const []);
      expect(status.surfGf, equals(0.0));
    });

    test('is greater than gf99 when at depth with loaded tissues', () {
      // At depth, ambient pressure is higher, so GF at depth < GF at surface
      final comps = createCompartments(pN2: 2.0);
      final status = createStatus(
        compartments: comps,
        ambientPressureBar: 2.0, // 10m depth
        currentDepthMeters: 10.0,
      );

      expect(status.surfGf, greaterThan(status.gf99));
    });

    test('equals gf99 at surface', () {
      final comps = createCompartments(pN2: 1.5);
      final status = createStatus(
        compartments: comps,
        ambientPressureBar: 1.0,
        currentDepthMeters: 0.0,
      );

      expect(status.surfGf, closeTo(status.gf99, 0.01));
    });
  });

  group('DecoStatus.gf99LeadingCompartmentNumber', () {
    test('returns 0 for empty compartments', () {
      final status = createStatus(compartments: const []);
      expect(status.gf99LeadingCompartmentNumber, equals(0));
    });

    test('identifies the compartment with highest GF at depth', () {
      // Load compartment 3 (index 2) more than others
      final comps = createCompartments(pN2: 1.0);
      final loaded = comps[2].copyWith(currentPN2: 3.0);
      final modified = [...comps.sublist(0, 2), loaded, ...comps.skip(3)];

      final status = createStatus(
        compartments: modified,
        ambientPressureBar: 1.0,
      );

      expect(status.gf99LeadingCompartmentNumber, equals(3));
    });

    test('may differ from leadingCompartmentNumber', () {
      // This tests the key difference: leadingCompartmentNumber uses
      // surface M-value (percentLoading), while gf99Leading uses GF at depth.
      // With uniform loading, fast compartments have higher GF at depth
      // but slow compartments may have higher percentLoading.
      final comps = createCompartments(pN2: 2.0);
      final status = createStatus(
        compartments: comps,
        ambientPressureBar: 3.0, // 20m depth
        currentDepthMeters: 20.0,
      );

      // At deep depths with uniform tissue tensions, the leading compartment
      // by GF99 may differ from leading by surface percentLoading
      // (this is the whole point of having both metrics)
      expect(status.gf99LeadingCompartmentNumber, isPositive);
      expect(status.leadingCompartmentNumber, isPositive);
    });
  });
}
