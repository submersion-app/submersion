import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_lod.dart';

void main() {
  group('BathymetryLodStage.spanMeters', () {
    test('matches the documented span per stage', () {
      expect(BathymetryLodStage.overview.spanMeters, 8000);
      expect(BathymetryLodStage.medium.spanMeters, 6000);
      expect(BathymetryLodStage.fine.spanMeters, 4000);
      expect(BathymetryLodStage.superFine.spanMeters, 1000);
    });
  });

  group('BathymetryLodStage.maxGridDim', () {
    test('overview/medium/fine share the repository default', () {
      expect(BathymetryLodStage.overview.maxGridDim, 120);
      expect(BathymetryLodStage.medium.maxGridDim, 120);
      expect(BathymetryLodStage.fine.maxGridDim, 120);
    });

    test('superFine raises the cap well above any shipped source\'s '
        'native resolution over its span', () {
      expect(BathymetryLodStage.superFine.maxGridDim, 600);
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

    test('just below the superFine threshold stays fine', () {
      expect(bathymetryLodStageForZoom(6.499), BathymetryLodStage.fine);
    });

    test('exactly at the superFine threshold switches to superFine', () {
      expect(bathymetryLodStageForZoom(6.5), BathymetryLodStage.superFine);
    });

    test('just above the superFine threshold is superFine', () {
      expect(bathymetryLodStageForZoom(6.501), BathymetryLodStage.superFine);
    });

    test('the viewport maximum zoom (8.0) is superFine', () {
      expect(bathymetryLodStageForZoom(8.0), BathymetryLodStage.superFine);
    });
  });
}
