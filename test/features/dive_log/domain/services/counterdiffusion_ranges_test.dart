import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/domain/entities/counterdiffusion_analysis.dart';
import 'package:submersion/features/dive_log/domain/services/counterdiffusion_ranges.dart';

/// Issue #4530: the profile marks where the tissue model shows isobaric
/// counterdiffusion, and, on request, every phase in which nitrogen and
/// helium move in opposite directions.
void main() {
  // ZH-L16C compartment 1 (N2 4.0 min, He 1.51 min).
  TissueCompartment comp({
    int number = 1,
    required double pN2,
    required double pHe,
  }) => TissueCompartment(
    compartmentNumber: number,
    halfTimeN2: 4.0,
    halfTimeHe: 1.51,
    mValueAN2: 1.2599,
    mValueBN2: 0.5050,
    mValueAHe: 1.7424,
    mValueBHe: 0.4245,
    currentPN2: pN2,
    currentPHe: pHe,
  );

  DecoStatus status(
    List<TissueCompartment> comps, {
    double? inspiredN2,
    double? inspiredHe,
  }) => DecoStatus(
    compartments: comps,
    ndlSeconds: 0,
    ceilingMeters: 0,
    ttsSeconds: 0,
    gfLow: 0.3,
    gfHigh: 0.7,
    decoStops: const [],
    currentDepthMeters: 30,
    ambientPressureBar: 4.0,
    inspiredN2Bar: inspiredN2,
    inspiredHeBar: inspiredHe,
  );

  // Tissue holds 2.0 bar inert, breathes 1.95 bar: helium enters faster
  // than nitrogen leaves, so it takes gas up net. ICD proper.
  DecoStatus icd({int number = 1}) => status(
    [comp(number: number, pN2: 0.4, pHe: 1.6)],
    inspiredN2: 0.05,
    inspiredHe: 1.9,
  );

  // Nitrogen enters, helium leaves, and the breathed total (2.0) is above
  // the tissue's (0.7): ordinary uptake, only opposing.
  DecoStatus uptake() =>
      status([comp(pN2: 0.4, pHe: 0.3)], inspiredN2: 2.0, inspiredHe: 0.0);

  // Nitrogen enters, helium leaves faster: net off-gassing, opposing.
  DecoStatus offgassing() =>
      status([comp(pN2: 0.4, pHe: 1.6)], inspiredN2: 1.0, inspiredHe: 0.0);

  // Both gases at the inspired pressure: nothing moves.
  DecoStatus still() =>
      status([comp(pN2: 0.74, pHe: 0.0)], inspiredN2: 0.74, inspiredHe: 0.0);

  List<int> every10s(int count) => [for (var i = 0; i < count; i++) i * 10];

  group('counterdiffusionAnalysisOf', () {
    test('marks ICD where the tissue takes gas up against a lower inspired '
        'total', () {
      final statuses = [still(), icd(), icd(), icd(), icd(), still()];

      final result = counterdiffusionAnalysisOf(statuses, every10s(6));

      expect(result.icdRanges, const [
        CounterdiffusionRange(
          startSeconds: 10,
          endSeconds: 50,
          kind: CounterdiffusionKind.netOngassing,
          compartmentNumbers: [1],
        ),
      ]);
      expect(result.opposingRanges.single.startSeconds, 10);
      expect(result.opposingRanges.single.endSeconds, 50);
      expect(result.heliumPresent, isTrue);
    });

    test('ordinary uptake with helium leaving is opposing, never ICD', () {
      final statuses = [uptake(), uptake(), uptake(), uptake()];

      final result = counterdiffusionAnalysisOf(statuses, every10s(4));

      expect(result.icdRanges, isEmpty);
      expect(result.opposingRanges, const [
        CounterdiffusionRange(
          startSeconds: 0,
          endSeconds: 30,
          kind: CounterdiffusionKind.opposing,
          compartmentNumbers: [1],
        ),
      ]);
    });

    test('net off-gassing with opposite gases is opposing only', () {
      final statuses = [offgassing(), offgassing(), offgassing(), offgassing()];

      final result = counterdiffusionAnalysisOf(statuses, every10s(4));

      expect(result.icdRanges, isEmpty);
      expect(result.opposingRanges, hasLength(1));
    });

    test('a net on-gassing rate below the minimum is not ICD', () {
      // Both gases move (each beyond the 0.01 bar tolerance) and the tissue
      // holds more than is breathed (2.0 against 1.98), but the net rate
      // ln2 * (-0.04 / 4 + 0.02 / 1.51) is about 0.002 bar/min.
      DecoStatus faint() => status(
        [comp(pN2: 0.4, pHe: 1.6)],
        inspiredN2: 0.36,
        inspiredHe: 1.62,
      );
      final statuses = [faint(), faint(), faint(), faint()];

      final result = counterdiffusionAnalysisOf(statuses, every10s(4));

      expect(result.icdRanges, isEmpty);
    });

    test('drops runs shorter than the minimum duration', () {
      final statuses = [still(), icd(), icd(), still(), still()];

      final result = counterdiffusionAnalysisOf(statuses, every10s(5));

      expect(result.icdRanges, isEmpty);
      expect(result.opposingRanges, isEmpty);
    });

    test('merges runs separated by a short gap', () {
      final statuses = [
        icd(),
        icd(),
        icd(),
        still(),
        icd(),
        icd(),
        icd(),
        icd(),
      ];
      // A 15 s gap between 20 s and 35 s.
      final timestamps = [0, 10, 20, 27, 35, 45, 55, 65];

      final result = counterdiffusionAnalysisOf(
        statuses,
        timestamps,
        mergeGapSeconds: 15,
      );

      expect(result.icdRanges.single.startSeconds, 0);
      expect(result.icdRanges.single.endSeconds, 65);
    });

    test('a run lasts until the next sample, so sparse sampling still '
        'counts the time', () {
      // One ICD sample on a computer logging every 60 s: a minute of ICD.
      final result = counterdiffusionAnalysisOf(
        [still(), icd(), still()],
        const [0, 60, 120],
      );

      expect(result.icdRanges.single.startSeconds, 60);
      expect(result.icdRanges.single.endSeconds, 120);
    });

    test('a single quiet sample between two runs is merged over at 10 s '
        'sampling', () {
      final statuses = [icd(), icd(), icd(), still(), icd(), icd(), icd()];

      final result = counterdiffusionAnalysisOf(statuses, every10s(7));

      expect(result.icdRanges.single.startSeconds, 0);
      expect(result.icdRanges.single.endSeconds, 60);
    });

    test('air-saturated tissue on its first breaths of trimix is not ICD', () {
      // At 1 bar both the tissue and Tx 21/35 hold 0.74 bar of inert gas:
      // helium enters faster than nitrogen leaves, but the tissue does not
      // hold more than is breathed.
      DecoStatus firstBreaths() => status(
        [comp(pN2: 0.7405, pHe: 0.0)],
        inspiredN2: 0.4124,
        inspiredHe: 0.3281,
      );
      final statuses = List.generate(6, (_) => firstBreaths());

      final result = counterdiffusionAnalysisOf(statuses, every10s(6));

      expect(result.icdRanges, isEmpty);
      expect(result.opposingRanges, hasLength(1));
    });

    test('lists every compartment that met the kind, ascending', () {
      DecoStatus mixed(int a, int b) => status(
        [
          comp(number: a, pN2: 0.4, pHe: 1.6),
          comp(number: b, pN2: 0.74, pHe: 0.0),
        ],
        inspiredN2: 0.05,
        inspiredHe: 1.9,
      );
      final statuses = [mixed(5, 2), mixed(5, 2), mixed(3, 2), mixed(3, 2)];

      final result = counterdiffusionAnalysisOf(statuses, every10s(4));

      expect(result.icdRanges.single.compartmentNumbers, [3, 5]);
    });

    test('an unknown inspired gas marks nothing', () {
      final unknown = status([comp(pN2: 0.4, pHe: 1.6)]);
      final statuses = [unknown, unknown, unknown, unknown];

      final result = counterdiffusionAnalysisOf(statuses, every10s(4));

      expect(result.icdRanges, isEmpty);
      expect(result.opposingRanges, isEmpty);
      expect(result.heliumPresent, isTrue);
    });

    test('a dive without helium in gas or tissue reports none', () {
      final statuses = [still(), still(), still()];

      final result = counterdiffusionAnalysisOf(statuses, every10s(3));

      expect(result, CounterdiffusionAnalysis.none);
    });

    test('residual helium from an earlier dive counts as helium present', () {
      // Nitrox breathed, but the tissue still holds helium.
      final statuses = [uptake(), uptake(), uptake(), uptake()];

      final result = counterdiffusionAnalysisOf(statuses, every10s(4));

      expect(result.heliumPresent, isTrue);
    });

    test('mismatched or empty inputs report none', () {
      expect(
        counterdiffusionAnalysisOf(const [], const []),
        CounterdiffusionAnalysis.none,
      );
      expect(
        counterdiffusionAnalysisOf([icd(), icd()], const [0]),
        CounterdiffusionAnalysis.none,
      );
    });
  });

  group('netHaldaneRateBarPerMin', () {
    test('sums both gases with ln 2 over their half-times', () {
      final c = comp(pN2: 0.4, pHe: 1.6);

      // ln2 * ((0.05 - 0.4) / 4.0 + (1.9 - 1.6) / 1.51)
      expect(
        netHaldaneRateBarPerMin(c, inspiredN2Bar: 0.05, inspiredHeBar: 1.9),
        closeTo(0.0771, 0.0005),
      );
    });
  });
}
