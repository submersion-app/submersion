import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_lod.dart';

void main() {
  group('BathymetryLodStage.spanMeters', () {
    test('matches the documented span per stage', () {
      expect(BathymetryLodStage.overview.spanMeters, 8000);
      expect(BathymetryLodStage.medium.spanMeters, 2000);
      expect(BathymetryLodStage.fine.spanMeters, 500);
    });
  });

  group('bathymetryLodStageForZoom', () {
    test('the viewport minimum zoom (0.4) is overview', () {
      expect(bathymetryLodStageForZoom(0.4), BathymetryLodStage.overview);
    });

    test('just below the medium threshold stays overview', () {
      expect(bathymetryLodStageForZoom(1.999), BathymetryLodStage.overview);
    });

    test('exactly at the medium threshold switches to medium', () {
      expect(bathymetryLodStageForZoom(2.0), BathymetryLodStage.medium);
    });

    test('just above the medium threshold is medium', () {
      expect(bathymetryLodStageForZoom(2.001), BathymetryLodStage.medium);
    });

    test('just below the fine threshold stays medium', () {
      expect(bathymetryLodStageForZoom(4.499), BathymetryLodStage.medium);
    });

    test('exactly at the fine threshold switches to fine', () {
      expect(bathymetryLodStageForZoom(4.5), BathymetryLodStage.fine);
    });

    test('just above the fine threshold is fine', () {
      expect(bathymetryLodStageForZoom(4.501), BathymetryLodStage.fine);
    });

    test('the viewport maximum zoom (8.0) is fine', () {
      expect(bathymetryLodStageForZoom(8.0), BathymetryLodStage.fine);
    });
  });
}
