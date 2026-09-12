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
/// through 1980): https://pubdb.bfe.admin.ch/de/publication/download/925 —
/// except where individually noted below, for lakes added later that BFE
/// publication does not cover; those instead cite BAFU's hydrodaten.admin.ch
/// long-term station means (1991-2025).
///
/// These are historical long-term averages, not real-time gauge readings —
/// appropriate for this app's coarse LN02-to-depth conversion, since most of
/// these lakes barely drift from their mean level over time. Lungernsee is
/// the one exception in this table (see its own entry below) — a heavily
/// regulated reservoir whose real level swings roughly 40 m across a year,
/// far beyond what a single mean can approximate.
///
/// This list was cross-checked (2026-09-10) against every item the
/// swissBATHY3D STAC collection actually publishes — three lakes previously
/// listed here (Greifensee, Lago di Lugano, Pfäffikersee) turned out to have
/// no matching STAC item at all (always "no data", not a bug), and five
/// published lakes were missing from this list entirely (Lac de Joux,
/// Lungernsee, Silsersee, Silvaplanersee, Rotsee) — both corrected here.
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
    name: 'Murtensee',
    meanLevelMeters: 429.21,
    minLat: 46.88,
    maxLat: 46.96,
    minLon: 7.05,
    maxLon: 7.14,
  ),
  // Listed AFTER Murtensee: Neuenburgersee's real STAC bbox substantially
  // overlaps Murtensee's (they are connected via the Broye canal), so
  // Murtensee -- the smaller, more specific lake -- must be checked first
  // or every Murtensee coordinate would silently resolve to
  // Neuenburgersee's 429.20 m instead of Murtensee's own 429.21 m
  // (self-check following the Copilot review pattern for Rotsee).
  SwissLakeLevel(
    name: 'Neuenburgersee',
    meanLevelMeters: 429.20,
    minLat: 46.75,
    maxLat: 47.10,
    // maxLon tightened from 7.10: real bbox ends 7.0720, overlapping
    // Bielersee's real bbox (starts 7.0695) by the width of the
    // connecting Zihlkanal. Split at the midpoint rather than reordering
    // -- unlike Murtensee, neither lake is clearly "more specific" for a
    // canal coordinate.
    minLon: 6.66,
    maxLon: 7.07,
  ),
  // No BAFU long-term station series found; 419 m is the figure
  // consistently reported by general geographic references (swisstopo map
  // data), not the specific BFE 1983 publication the rest of this table
  // cites. A small, unregulated natural lake, so unlike Lungernsee a
  // single mean is still an appropriate approximation here.
  //
  // Listed BEFORE Vierwaldstättersee deliberately: Vierwaldstättersee's own
  // box is a coarse rectangle drawn around its irregular real shoreline and
  // sweeps over dry land north of Lucerne where Rotsee actually sits (a
  // real, physically separate lake, not part of Vierwaldstättersee) --
  // findSwissLake takes the first bbox match in list order, so without this
  // ordering every Rotsee coordinate would silently resolve to
  // Vierwaldstättersee's 433.58 m instead of Rotsee's own 419.00 m, a
  // ~14.6 m depth error (Copilot review).
  SwissLakeLevel(
    name: 'Rotsee',
    meanLevelMeters: 419.00,
    minLat: 47.06,
    maxLat: 47.08,
    minLon: 8.29,
    maxLon: 8.33,
  ),
  SwissLakeLevel(
    name: 'Zugersee',
    meanLevelMeters: 413.59,
    minLat: 47.10,
    maxLat: 47.23,
    minLon: 8.44,
    maxLon: 8.53,
  ),
  // Listed AFTER Zugersee: Vierwaldstättersee's real bbox extends to
  // lat 47.0822, genuinely overlapping Zugersee's real bbox (starts
  // 47.0538) -- Zugersee, the smaller/more specific lake, must be
  // checked first (self-check following the Copilot review pattern for
  // Rotsee).
  SwissLakeLevel(
    name: 'Vierwaldstättersee',
    meanLevelMeters: 433.58,
    minLat: 46.92,
    // maxLat tightened from 47.13: real bbox ends 47.0822, and the
    // previous, more generous value had no real coverage to justify it --
    // it only produced table-only overlaps with Zürichsee and Ägerisee
    // (neither of which overlaps Vierwaldstättersee's real bbox at all).
    maxLat: 47.09,
    minLon: 8.30,
    maxLon: 8.65,
  ),
  SwissLakeLevel(
    name: 'Zürichsee',
    meanLevelMeters: 405.92,
    // minLat tightened from 47.13: real bbox starts 47.1946, well clear of
    // both Vierwaldstättersee's and Ägerisee's real bboxes -- the previous
    // value only produced table-only overlaps with both.
    minLat: 47.19,
    maxLat: 47.36,
    minLon: 8.55,
    maxLon: 8.85,
  ),
  SwissLakeLevel(
    name: 'Thunersee',
    meanLevelMeters: 557.66,
    minLat: 46.63,
    maxLat: 46.75,
    minLon: 7.63,
    // maxLon tightened from 7.87: real bbox ends 7.8444, with a real gap
    // (not a canal connection) before Brienzersee's real bbox starts
    // 7.8569 -- a pure table-rounding artifact, unlike the
    // Neuenburgersee/Bielersee or Rotsee/Vierwaldstättersee overlaps.
    maxLon: 7.85,
  ),
  SwissLakeLevel(
    name: 'Brienzersee',
    meanLevelMeters: 563.74,
    minLat: 46.66,
    maxLat: 46.76,
    // minLon tightened from 7.86 down to 7.856 -- 7.86 clipped a small
    // sliver of Brienzersee's own real coverage (real bbox starts 7.8569).
    minLon: 7.856,
    maxLon: 8.08,
  ),
  SwissLakeLevel(
    name: 'Bielersee',
    meanLevelMeters: 429.15,
    minLat: 47.02,
    maxLat: 47.16,
    // minLon tightened from 7.05 -- see Neuenburgersee's comment on this
    // same overlap.
    minLon: 7.075,
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
    name: 'Ägerisee',
    meanLevelMeters: 723.89,
    minLat: 47.11,
    maxLat: 47.16,
    minLon: 8.60,
    maxLon: 8.65,
  ),
  SwissLakeLevel(
    name: 'Sarnersee',
    meanLevelMeters: 469.40,
    minLat: 46.85,
    maxLat: 46.92,
    minLon: 8.20,
    maxLon: 8.26,
  ),
  // BAFU hydrodaten.admin.ch station 2007, long-term mean 1991-2025.
  SwissLakeLevel(
    name: 'Lac de Joux',
    meanLevelMeters: 1004.03,
    minLat: 46.61,
    maxLat: 46.68,
    minLon: 6.24,
    maxLon: 6.35,
  ),
  // No BAFU long-term station mean available (heavily regulated reservoir,
  // not a natural-lake gauge series): Elektrizitätswerke Obwalden's own
  // concession fixes the level between 648.74 m (winter drawdown) and
  // 688.74 m, with 687.50-688.50 m required through the summer months —
  // roughly a 40 m annual swing, far beyond what a single mean can capture.
  // Per an explicit product decision, this uses the summer-operating
  // midpoint (688.00 m) rather than a misleading year-round average, since
  // diving here mostly happens in summer -- depths computed from this level
  // are still meaningfully wrong outside the May-October operating window.
  SwissLakeLevel(
    name: 'Lungernsee',
    meanLevelMeters: 688.00,
    minLat: 46.78,
    maxLat: 46.82,
    minLon: 8.14,
    maxLon: 8.18,
  ),
  // BAFU hydrodaten.admin.ch station 2072, long-term mean 1991-2025.
  // maxLon split from Silvaplanersee's minLon at the real gap between their
  // STAC item bboxes (Silsersee ends 9.7656, Silvaplanersee begins 9.7686)
  // -- a wider, symmetric buffer on both boxes independently made them
  // overlap and silently misassigned Silvaplanersee coordinates to
  // Silsersee's mean level, a ~6 m depth error (Copilot review).
  SwissLakeLevel(
    name: 'Silsersee',
    meanLevelMeters: 1796.65,
    minLat: 46.40,
    maxLat: 46.45,
    minLon: 9.69,
    maxLon: 9.766,
  ),
  // BAFU hydrodaten.admin.ch station 2073, long-term mean 1991-2025.
  SwissLakeLevel(
    name: 'Silvaplanersee',
    meanLevelMeters: 1790.57,
    minLat: 46.43,
    maxLat: 46.47,
    minLon: 9.767,
    maxLon: 9.81,
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
