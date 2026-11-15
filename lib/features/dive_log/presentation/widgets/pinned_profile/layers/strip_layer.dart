import 'package:submersion/core/constants/dive_detail_sections.dart';

/// One kind of data the pinned profile strip can draw over its depth line
/// while the card it belongs to is in view (issue #4562).
enum StripLayer {
  temperature,
  cns,
  surfaceGf,
  tankPressure,
  gtr,
  gasSwitches,
  sac,
  phases,
  media,
  tts,
  heartRate,
  annotations,
  safetyFindings,
  plannedDepth,
  sourceDepths;

  /// Whether this layer is a line on a scale of its own. Only these grow
  /// the strip: bands, ticks, dots and ghost depth lines read fine at its
  /// resting height.
  bool get isLine => switch (this) {
    temperature ||
    cns ||
    surfaceGf ||
    tankPressure ||
    gtr ||
    sac ||
    tts ||
    heartRate => true,
    gasSwitches ||
    phases ||
    media ||
    annotations ||
    safetyFindings ||
    plannedDepth ||
    sourceDepths => false,
  };
}

/// The layers each dive details card adds to the pinned strip while it is
/// in view. A card not listed has no data on the dive's timeline and adds
/// nothing.
const Map<DiveDetailSectionId, List<StripLayer>> kStripLayersByCard = {
  DiveDetailSectionId.environment: [StripLayer.temperature],
  DiveDetailSectionId.tissueLoading: [StripLayer.cns, StripLayer.surfaceGf],
  DiveDetailSectionId.tanks: [
    StripLayer.tankPressure,
    StripLayer.gtr,
    StripLayer.gasSwitches,
  ],
  DiveDetailSectionId.sacSegments: [StripLayer.sac, StripLayer.phases],
  DiveDetailSectionId.media: [StripLayer.media],
  DiveDetailSectionId.decoStatus: [StripLayer.tts],
  DiveDetailSectionId.health: [StripLayer.heartRate],
  DiveDetailSectionId.notes: [StripLayer.annotations],
  DiveDetailSectionId.safetyReview: [StripLayer.safetyFindings],
  DiveDetailSectionId.diveLab: [StripLayer.plannedDepth],
  DiveDetailSectionId.dataSources: [StripLayer.sourceDepths],
};

/// Every layer the [cards] add, together.
Set<StripLayer> stripLayersFor(Iterable<DiveDetailSectionId> cards) => {
  for (final card in cards) ...?kStripLayersByCard[card],
};
