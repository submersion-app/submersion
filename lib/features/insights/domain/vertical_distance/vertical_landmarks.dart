import 'dart:math' as math;

/// Which half of the scale: total ascent rises past mountains, total
/// descent sinks past ocean depths (issue #4569).
enum VerticalLeg { ascent, descent }

/// Every landmark the scale can show. The localized name of each lives in
/// `verticalLandmarkName`, which switches over this enum with no default, so
/// a landmark added here without a name does not compile.
enum VerticalLandmarkId {
  // Up
  statueOfLiberty,
  greatPyramid,
  eiffelTower,
  empireStateBuilding,
  burjKhalifa,
  benNevis,
  mountKosciuszko,
  mountFuji,
  matterhorn,
  montBlanc,
  kilimanjaro,
  denali,
  aconcagua,
  k2,
  everest,
  olympusMons,
  karmanLine,
  internationalSpaceStation,
  // Down
  recreationalLimit,
  greatBlueHole,
  deansBlueHole,
  dragonHole,
  deepestScubaDive,
  craterLake,
  lakeTanganyika,
  lakeBaikal,
  deepestWhaleDive,
  averageOceanDepth,
  titanic,
  bismarck,
  molloyDeep,
  deepestShipwreck,
  javaTrench,
  southSandwichTrench,
  puertoRicoTrench,
  tongaTrench,
  challengerDeep,
  kolaBorehole,
}

/// A height or depth the diver's total is measured against.
class VerticalLandmark {
  const VerticalLandmark(this.id, this.meters, {this.multiple = 1});

  final VerticalLandmarkId id;

  /// Height or depth in metres, already multiplied by [multiple].
  final double meters;

  /// 1 for a named landmark; n for "n x Everest" or "n x Challenger Deep".
  final int multiple;
}

/// Heights, ascending. Each figure is the one its source gives, rounded to
/// the metre.
const List<VerticalLandmark> ascentLandmarks = [
  // US National Park Service, ground to torch: 92.99 m.
  VerticalLandmark(VerticalLandmarkId.statueOfLiberty, 93),
  // Commonly quoted 138.5 to 138.8 m for the present, eroded height.
  VerticalLandmark(VerticalLandmarkId.greatPyramid, 139),
  // Societe d'Exploitation de la Tour Eiffel, with the 2022 antenna.
  VerticalLandmark(VerticalLandmarkId.eiffelTower, 330),
  // Empire State Building fact sheet, to the tip: 443.2 m.
  VerticalLandmark(VerticalLandmarkId.empireStateBuilding, 443),
  // Emaar, Burj Khalifa facts and figures.
  VerticalLandmark(VerticalLandmarkId.burjKhalifa, 828),
  // Ordnance Survey, 2016: 1,344.527 m.
  VerticalLandmark(VerticalLandmarkId.benNevis, 1345),
  // Geoscience Australia, highest mountains.
  VerticalLandmark(VerticalLandmarkId.mountKosciuszko, 2228),
  // Geospatial Information Authority of Japan.
  VerticalLandmark(VerticalLandmarkId.mountFuji, 3776),
  // 1999 GPS survey: 4,477.54 m.
  VerticalLandmark(VerticalLandmarkId.matterhorn, 4478),
  // Haute-Savoie surveyors, September 2026: 4,807.47 m (the ice cap moves).
  VerticalLandmark(VerticalLandmarkId.montBlanc, 4807),
  // Official figure; GPS surveys give 5,890 to 5,892 m.
  VerticalLandmark(VerticalLandmarkId.kilimanjaro, 5895),
  // USGS, 2015: 20,310 ft.
  VerticalLandmark(VerticalLandmarkId.denali, 6190),
  // Instituto Geografico Nacional (Argentina), 2012: 6,960.8 m.
  VerticalLandmark(VerticalLandmarkId.aconcagua, 6961),
  // Commonly quoted; a 2014 GNSS survey gave 8,609 m.
  VerticalLandmark(VerticalLandmarkId.k2, 8611),
  // Nepal and China joint survey, 2020: 8,848.86 m.
  VerticalLandmark(VerticalLandmarkId.everest, 8849),
  // USGS MOLA map I-2782, summit above the Mars datum.
  VerticalLandmark(VerticalLandmarkId.olympusMons, 21229),
  // Federation Aeronautique Internationale's edge of space.
  VerticalLandmark(VerticalLandmarkId.karmanLine, 100000),
  // NASA: a typical altitude; the orbit ranges from 370 to 460 km.
  VerticalLandmark(VerticalLandmarkId.internationalSpaceStation, 400000),
];

/// Depths, ascending. Trench figures other than Challenger Deep are from one
/// peer-reviewed survey: Bongiovanni, Stewart and Jamieson, Geoscience Data
/// Journal 9(1), 2022.
const List<VerticalLandmark> descentLandmarks = [
  // The recreational limit most training agencies set.
  VerticalLandmark(VerticalLandmarkId.recreationalLimit, 40),
  // 1997 Cambrian Foundation survey.
  VerticalLandmark(VerticalLandmarkId.greatBlueHole, 124),
  // Wilson, Bahamas Journal of Science, 1994.
  VerticalLandmark(VerticalLandmarkId.deansBlueHole, 202),
  // Li et al., Scientific Reports, 2018: 300.89 m.
  VerticalLandmark(VerticalLandmarkId.dragonHole, 301),
  // Guinness World Records, Ahmed Gabr, 2014: 332.35 m.
  VerticalLandmark(VerticalLandmarkId.deepestScubaDive, 332),
  // USGS bathymetry of Crater Lake.
  VerticalLandmark(VerticalLandmarkId.craterLake, 594),
  // FAO Lake Tanganyika Research.
  VerticalLandmark(VerticalLandmarkId.lakeTanganyika, 1470),
  // Limnological Institute, Irkutsk.
  VerticalLandmark(VerticalLandmarkId.lakeBaikal, 1642),
  // Schorr et al., PLOS ONE, 2014: a Cuvier's beaked whale.
  VerticalLandmark(VerticalLandmarkId.deepestWhaleDive, 2992),
  // NOAA: the average depth of the ocean.
  VerticalLandmark(VerticalLandmarkId.averageOceanDepth, 3682),
  // NOAA, the wreck of the Titanic.
  VerticalLandmark(VerticalLandmarkId.titanic, 3800),
  // Approximate depth of the wreck of the Bismarck.
  VerticalLandmark(VerticalLandmarkId.bismarck, 4790),
  // Deepest point of the Arctic Ocean.
  VerticalLandmark(VerticalLandmarkId.molloyDeep, 5551),
  // Guinness World Records, USS Samuel B. Roberts.
  VerticalLandmark(VerticalLandmarkId.deepestShipwreck, 6865),
  // Deepest point of the Indian Ocean.
  VerticalLandmark(VerticalLandmarkId.javaTrench, 7187),
  // Deepest point of the Southern Ocean, south of 60 degrees.
  VerticalLandmark(VerticalLandmarkId.southSandwichTrench, 7432),
  // Deepest point of the Atlantic Ocean.
  VerticalLandmark(VerticalLandmarkId.puertoRicoTrench, 8378),
  // Horizon Deep.
  VerticalLandmark(VerticalLandmarkId.tongaTrench, 10816),
  // Greenaway et al. for NOAA, 2021; the deepest known point of the ocean.
  VerticalLandmark(VerticalLandmarkId.challengerDeep, 10935),
  // Kola Superdeep Borehole, the deepest hole drilled.
  VerticalLandmark(VerticalLandmarkId.kolaBorehole, 12262),
];

List<VerticalLandmark> _named(VerticalLeg d) =>
    d == VerticalLeg.ascent ? ascentLandmarks : descentLandmarks;

/// Past the top of each named list the scale keeps going in multiples of
/// its tallest or deepest natural landmark.
VerticalLandmark _base(VerticalLeg d) => d == VerticalLeg.ascent
    ? ascentLandmarks.firstWhere((l) => l.id == VerticalLandmarkId.everest)
    : descentLandmarks.firstWhere(
        (l) => l.id == VerticalLandmarkId.challengerDeep,
      );

VerticalLandmark _multipleOf(VerticalLandmark base, int n) =>
    VerticalLandmark(base.id, base.meters * n, multiple: n);

/// Every landmark at or below [total] metres, ascending: the named ones
/// merged with the multiples (2 x and up) of the base landmark.
List<VerticalLandmark> passedLandmarks(VerticalLeg d, double total) {
  final base = _base(d);
  final passed = [
    for (final l in _named(d))
      if (l.meters <= total) l,
    for (var n = 2; base.meters * n <= total; n++) _multipleOf(base, n),
  ]..sort((a, b) => a.meters.compareTo(b.meters));
  return passed;
}

/// The smallest landmark above [total] metres. Never null: the multiples
/// go on without limit. Worked out directly, without walking the
/// multiples, so it costs the same for any total.
VerticalLandmark nextLandmark(VerticalLeg d, double total) {
  final base = _base(d);
  final n = math.max(2, (total / base.meters).floor() + 1);
  final multiple = _multipleOf(base, n);
  for (final l in _named(d)) {
    if (l.meters > total) {
      return l.meters < multiple.meters ? l : multiple;
    }
  }
  return multiple;
}
