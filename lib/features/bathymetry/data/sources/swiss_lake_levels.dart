import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A Swiss lake's mean water level, used to turn a swissBATHY3D lake-bed
/// elevation (LN02, meters above sea level) into a depth: depth = level - Z.
/// [box] is a generous WGS84 bounding box around the lake's shoreline —
/// coarser than the real shoreline on purpose, since a false-positive match
/// just costs one wasted STAC lookup that then finds no tile.
class SwissLakeLevel {
  final String name;

  /// Mean water level in meters above sea level (LN02). At border lakes
  /// (Bodensee, Genfersee, Lago Maggiore) this is the Swiss reference gauge,
  /// per the task's design decision.
  final double meanLevelMeters;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  const SwissLakeLevel({
    required this.name,
    required this.meanLevelMeters,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  bool containsApprox(GeoPoint p) =>
      p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLon &&
      p.longitude <= maxLon;
}

/// Static table of Swiss lakes covered by swissBATHY3D, with their mean
/// water level. Deliberately NOT a database table (per task design decision)
/// so a new lake or a corrected level ships as a code change, no migration.
///
/// Mean-level figures are from the Bundesamt für Energie (BFE) publication
/// "Naturseen der Schweiz" (as of 1 January 1983, averages of annual series
/// through 1980): https://pubdb.bfe.admin.ch/de/publication/download/925
///
/// These are historical long-term averages, not real-time gauge readings —
/// appropriate for this app's coarse LN02-to-depth conversion, since
/// regulated lakes barely drift from their mean level over time.
const List<SwissLakeLevel> swissLakeLevels = [
  SwissLakeLevel(
    name: 'Genfersee (Lac Léman)',
    meanLevelMeters: 372.05,
    minLat: 46.20,
    maxLat: 46.51,
    minLon: 6.14,
    maxLon: 6.93,
  ),
  SwissLakeLevel(
    name: 'Bodensee (Obersee)',
    meanLevelMeters: 395.63,
    minLat: 47.50,
    maxLat: 47.72,
    minLon: 9.05,
    maxLon: 9.70,
  ),
  SwissLakeLevel(
    name: 'Neuenburgersee',
    meanLevelMeters: 429.20,
    minLat: 46.75,
    maxLat: 47.10,
    minLon: 6.66,
    maxLon: 7.10,
  ),
  SwissLakeLevel(
    name: 'Vierwaldstättersee',
    meanLevelMeters: 433.58,
    minLat: 46.92,
    maxLat: 47.13,
    minLon: 8.30,
    maxLon: 8.65,
  ),
  SwissLakeLevel(
    name: 'Zürichsee',
    meanLevelMeters: 405.92,
    minLat: 47.13,
    maxLat: 47.36,
    minLon: 8.55,
    maxLon: 8.85,
  ),
  SwissLakeLevel(
    name: 'Zugersee',
    meanLevelMeters: 413.59,
    minLat: 47.10,
    maxLat: 47.23,
    minLon: 8.44,
    maxLon: 8.53,
  ),
  SwissLakeLevel(
    name: 'Thunersee',
    meanLevelMeters: 557.66,
    minLat: 46.63,
    maxLat: 46.75,
    minLon: 7.63,
    maxLon: 7.87,
  ),
  SwissLakeLevel(
    name: 'Brienzersee',
    meanLevelMeters: 563.74,
    minLat: 46.66,
    maxLat: 46.76,
    minLon: 7.86,
    maxLon: 8.08,
  ),
  SwissLakeLevel(
    name: 'Bielersee',
    meanLevelMeters: 429.15,
    minLat: 47.02,
    maxLat: 47.16,
    minLon: 7.05,
    maxLon: 7.25,
  ),
  SwissLakeLevel(
    name: 'Walensee',
    meanLevelMeters: 419.07,
    minLat: 47.10,
    maxLat: 47.18,
    minLon: 9.13,
    maxLon: 9.35,
  ),
  SwissLakeLevel(
    name: 'Lago Maggiore (Schweizer Referenz)',
    meanLevelMeters: 193.52,
    minLat: 45.82,
    maxLat: 46.17,
    minLon: 8.60,
    maxLon: 8.90,
  ),
  SwissLakeLevel(
    name: 'Lago di Lugano',
    meanLevelMeters: 270.49,
    minLat: 45.85,
    maxLat: 46.05,
    minLon: 8.85,
    maxLon: 9.10,
  ),
  SwissLakeLevel(
    name: 'Greifensee',
    meanLevelMeters: 435.14,
    minLat: 47.32,
    maxLat: 47.39,
    minLon: 8.65,
    maxLon: 8.72,
  ),
  SwissLakeLevel(
    name: 'Hallwilersee',
    meanLevelMeters: 448.67,
    minLat: 47.24,
    maxLat: 47.32,
    minLon: 8.19,
    maxLon: 8.24,
  ),
  SwissLakeLevel(
    name: 'Baldeggersee',
    meanLevelMeters: 463.04,
    minLat: 47.18,
    maxLat: 47.23,
    minLon: 8.24,
    maxLon: 8.29,
  ),
  SwissLakeLevel(
    name: 'Sempachsee',
    meanLevelMeters: 503.77,
    minLat: 47.10,
    maxLat: 47.16,
    minLon: 8.13,
    maxLon: 8.20,
  ),
  SwissLakeLevel(
    name: 'Pfäffikersee',
    meanLevelMeters: 536.98,
    minLat: 47.34,
    maxLat: 47.38,
    minLon: 8.77,
    maxLon: 8.82,
  ),
  SwissLakeLevel(
    name: 'Ägerisee',
    meanLevelMeters: 723.89,
    minLat: 47.11,
    maxLat: 47.16,
    minLon: 8.60,
    maxLon: 8.65,
  ),
  SwissLakeLevel(
    name: 'Murtensee',
    meanLevelMeters: 429.21,
    minLat: 46.88,
    maxLat: 46.96,
    minLon: 7.05,
    maxLon: 7.14,
  ),
  SwissLakeLevel(
    name: 'Sarnersee',
    meanLevelMeters: 469.40,
    minLat: 46.85,
    maxLat: 46.92,
    minLon: 8.20,
    maxLon: 8.26,
  ),
];

/// The lake whose bounding box contains [p], or null when none matches
/// (the coordinate is outside all known swissBATHY3D lakes).
SwissLakeLevel? findSwissLake(GeoPoint p) {
  for (final lake in swissLakeLevels) {
    if (lake.containsApprox(p)) return lake;
  }
  return null;
}
