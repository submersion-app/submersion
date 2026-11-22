import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';

import 'manifest_fixture.dart';

VisionModels _models() => VisionModels.fromManifest(
  SpeciesPackManifest.parse(manifestV2Json()),
  detectorPaths: const ['/d', '/m'],
  classifierPath: '/c',
);

void main() {
  group('momentPadding (issue #4882)', () {
    test('a video box under 256 px on its shorter side is cropped at 0.6', () {
      final models = _models();

      expect(models.momentPadding(boxWidth: 400, boxHeight: 255.9), 0.6);
      expect(models.momentPadding(boxWidth: 255, boxHeight: 1000), 0.6);
      expect(models.momentPadding(boxWidth: 64, boxHeight: 90), 0.6);
    });

    test('a small box is never cropped tighter than the pack padding', () {
      final models = _models().copyWith(cropPadding: 0.8);

      expect(models.momentPadding(boxWidth: 100, boxHeight: 100), 0.8);
    });

    test('a box 256 px or more on its shorter side keeps the pack padding', () {
      final models = _models();

      expect(models.momentPadding(boxWidth: 256, boxHeight: 300), 0.1);
      expect(models.momentPadding(boxWidth: 1800, boxHeight: 900), 0.1);
    });

    test('a negative or infinite small-box setting is refused', () {
      final models = _models();

      expect(
        () => models.copyWith(smallBoxPadding: -0.6),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => models.copyWith(smallBoxPadding: double.infinity),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => models.copyWith(smallBoxSide: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a small box side of 0 crops every moment at the pack padding', () {
      final models = _models().copyWith(smallBoxSide: 0);

      expect(models.momentPadding(boxWidth: 10, boxHeight: 10), 0.1);
    });
  });
}
