import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';

void main() {
  group('pickNearestTissueVertex', () {
    // 2 columns x 2 compartments at known screen points.
    final projected = <Offset>[
      const Offset(0, 0), // (col0, comp0)
      const Offset(0, 10), // (col0, comp1)
      const Offset(10, 0), // (col1, comp0)
      const Offset(10, 10), // (col1, comp1)
    ];
    final depths = <double>[0, 0, 0, 0];

    test('returns the nearest vertex within threshold', () {
      final pick = pickNearestTissueVertex(
        cursor: const Offset(9, 1),
        projected: projected,
        viewDepths: depths,
        columns: 2,
        compartments: 2,
      );
      expect(pick, isNotNull);
      expect(pick!.col, 1);
      expect(pick.comp, 0);
    });

    test('returns null when nothing is within threshold', () {
      final pick = pickNearestTissueVertex(
        cursor: const Offset(500, 500),
        projected: projected,
        viewDepths: depths,
        columns: 2,
        compartments: 2,
      );
      expect(pick, isNull);
    });

    test('on an exact screen-point overlap prefers the front-most '
        '(greater viewDepth)', () {
      final overlap = <Offset>[const Offset(0, 0), const Offset(0, 0)];
      final pick = pickNearestTissueVertex(
        cursor: const Offset(0, 0),
        projected: overlap,
        viewDepths: const [1.0, 5.0], // second is nearer the camera
        columns: 1,
        compartments: 2,
      );
      expect(pick!.comp, 1);
    });

    test('an equidistant tie between distinct points ignores depth '
        '(first encountered wins, not the deeper one)', () {
      // Two different screen points the same distance (5px) from the cursor.
      // Depth must NOT break this tie: they do not overlap, so the
      // strictly-first vertex wins regardless of the second being "in front".
      final equidistant = <Offset>[const Offset(-3, 4), const Offset(3, 4)];
      final pick = pickNearestTissueVertex(
        cursor: const Offset(0, 0),
        projected: equidistant,
        viewDepths: const [1.0, 5.0], // second is nearer the camera
        columns: 1,
        compartments: 2,
      );
      expect(pick!.comp, 0);
    });

    test('empty grid returns null', () {
      expect(
        pickNearestTissueVertex(
          cursor: Offset.zero,
          projected: const [],
          viewDepths: const [],
          columns: 0,
          compartments: 0,
        ),
        isNull,
      );
    });

    test(
      'returns null when array lengths do not match columns * compartments',
      () {
        // Caller claims a 3x2 grid (6 vertices) but only supplies 4 points.
        expect(
          pickNearestTissueVertex(
            cursor: Offset.zero,
            projected: const [
              Offset.zero,
              Offset.zero,
              Offset.zero,
              Offset.zero,
            ],
            viewDepths: const [0, 0, 0, 0],
            columns: 3,
            compartments: 2,
          ),
          isNull,
        );
      },
    );

    test('guards against zero compartments (no division by zero)', () {
      expect(
        pickNearestTissueVertex(
          cursor: Offset.zero,
          projected: const [Offset.zero],
          viewDepths: const [0],
          columns: 1,
          compartments: 0,
        ),
        isNull,
      );
    });
  });

  group('tissueSaturationStateForPercent', () {
    test('maps percent to state on half-open intervals', () {
      expect(
        tissueSaturationStateForPercent(44),
        TissueSaturationState.onGassing,
      );
      expect(
        tissueSaturationStateForPercent(45),
        TissueSaturationState.equilibrium,
      );
      expect(
        tissueSaturationStateForPercent(54.9),
        TissueSaturationState.equilibrium,
      );
      expect(
        tissueSaturationStateForPercent(55),
        TissueSaturationState.offGassing,
      );
      expect(
        tissueSaturationStateForPercent(100),
        TissueSaturationState.offGassing,
      );
      expect(
        tissueSaturationStateForPercent(100.1),
        TissueSaturationState.pastMValue,
      );
    });
  });
}
