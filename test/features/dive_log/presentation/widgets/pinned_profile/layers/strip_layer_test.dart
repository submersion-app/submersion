import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';

void main() {
  test('tanks maps to pressure, GTR and gas switches', () {
    expect(stripLayersFor([DiveDetailSectionId.tanks]), {
      StripLayer.tankPressure,
      StripLayer.gtr,
      StripLayer.gasSwitches,
    });
  });

  test('cards with no timeline data map to nothing', () {
    expect(
      stripLayersFor([
        DiveDetailSectionId.altitude,
        DiveDetailSectionId.tide,
        DiveDetailSectionId.navTrack,
        DiveDetailSectionId.sightings,
        DiveDetailSectionId.details,
      ]),
      isEmpty,
    );
  });

  test('two cards union their layers', () {
    expect(
      stripLayersFor([
        DiveDetailSectionId.environment,
        DiveDetailSectionId.tissueLoading,
      ]),
      {StripLayer.temperature, StripLayer.cns, StripLayer.surfaceGf},
    );
  });

  test('every mapped card adds its approved layers', () {
    expect(kStripLayersByCard[DiveDetailSectionId.sacSegments], [
      StripLayer.sac,
      StripLayer.phases,
    ]);
    expect(kStripLayersByCard[DiveDetailSectionId.media], [StripLayer.media]);
    expect(kStripLayersByCard[DiveDetailSectionId.decoStatus], [
      StripLayer.tts,
    ]);
    expect(kStripLayersByCard[DiveDetailSectionId.health], [
      StripLayer.heartRate,
    ]);
    expect(kStripLayersByCard[DiveDetailSectionId.notes], [
      StripLayer.annotations,
    ]);
    expect(kStripLayersByCard[DiveDetailSectionId.safetyReview], [
      StripLayer.safetyFindings,
    ]);
    expect(kStripLayersByCard[DiveDetailSectionId.diveLab], [
      StripLayer.plannedDepth,
    ]);
    expect(kStripLayersByCard[DiveDetailSectionId.dataSources], [
      StripLayer.sourceDepths,
    ]);
    expect(kStripLayersByCard.length, 11);
  });

  test('only line layers are lines', () {
    const notLines = {
      StripLayer.phases,
      StripLayer.media,
      StripLayer.annotations,
      StripLayer.gasSwitches,
      StripLayer.safetyFindings,
      StripLayer.plannedDepth,
      StripLayer.sourceDepths,
    };
    for (final layer in StripLayer.values) {
      expect(layer.isLine, !notLines.contains(layer), reason: layer.name);
    }
  });
}
