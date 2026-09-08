import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The outcome of walking the source tiers for one coordinate.
///
/// - `grid != null`: usable terrain (definitive).
/// - `grid == null && definitive`: fetched fine, genuinely no water here —
///   cacheable as a negative answer.
/// - `grid == null && !definitive`: transient failure — must NOT be cached.
class BathymetryResolution {
  final BathymetryGrid? grid;
  final bool definitive;

  const BathymetryResolution.ok(BathymetryGrid this.grid) : definitive = true;
  const BathymetryResolution.empty() : grid = null, definitive = true;
  const BathymetryResolution.transientFailure()
    : grid = null,
      definitive = false;
}

/// Best-source-wins. Probes every source, orders them by MATERIALLY better
/// resolution, then fetches in that order and takes the first grid passing
/// both quality floors.
///
/// No mosaicking: sources use different vertical datums (EMODnet is LAT,
/// GMRT and ETOPO are MSL), so stitching two of them together would leave
/// a visible step wherever they meet.
class BathymetryResolver {
  static const double minWetFraction = 0.10;

  /// A grid must actually have readings. EMODnet's Caribbean tile answers
  /// 99.96% wet on 48% coverage, and the missing half renders as a flat
  /// slab at the waterline. Coverage that thin is not usable terrain, and
  /// it is not an answer about the water either.
  static const double minKnownFraction = 0.60;

  /// How much finer a source must be to jump ahead of the declared list
  /// order. Declared resolution is a claim, so only a MATERIAL difference
  /// may override the curated tier order: NOAA CUDEM at 3.4 m preempts
  /// GMRT's 60 m, while GMRT's nominal 60 m does not preempt EMODnet's
  /// surveyed 115 m, which in Europe would trade real data for a grid that
  /// may be upsampled GEBCO.
  static const double preemptionFactor = 2.0;

  /// Request-box width. 8 km shows the surrounding seascape, not just the
  /// site itself; the repository's downsample cap bounds the render cost.
  /// This value is part of the cache key, see [BathymetryRepository.keyFor],
  /// so changing it refetches.
  static const double defaultSpanMeters = 8000;

  final List<BathymetrySource> sources;

  const BathymetryResolver({required this.sources});

  Future<BathymetryResolution> resolve(GeoPoint center) async {
    final ordered = await _order(center);
    var globalSourceSaidDry = false;
    for (final source in ordered) {
      try {
        final grid = await source.fetch(center, spanMeters: defaultSpanMeters);
        if (grid.knownFraction < minKnownFraction) {
          // Nominally fine, actually absent. Deliberately NOT treated as a
          // dry answer: a grid this empty proves nothing about the water,
          // and caching it as 'empty' would pin the cell forever.
          continue;
        }
        if (grid.wetFraction >= minWetFraction) {
          return BathymetryResolution.ok(grid);
        }
        // A dry answer only proves "no water here" if the source actually
        // covers everywhere; a regional edge cell proves nothing.
        if (source.global) globalSourceSaidDry = true;
      } on BathymetryFetchException {
        // Transient: fall through to the next source.
      } catch (_) {
        // A source blowing up with anything else (a TypeError from an
        // unexpected response shape, an ArgumentError) must not kill the
        // whole scene: treat it exactly like a transient failure.
      }
    }
    return globalSourceSaidDry
        ? const BathymetryResolution.empty()
        : const BathymetryResolution.transientFailure();
  }

  /// Covering sources in fetch order. Probes run concurrently because a
  /// probe may be a network call and they are independent; a probe that
  /// fails for any reason drops that source rather than failing the scene.
  Future<List<BathymetrySource>> _order(GeoPoint center) async {
    final caps = await Future.wait(
      sources.map((s) async {
        try {
          return await s.probe(center);
        } catch (_) {
          return null;
        }
      }),
    );
    final covering = <({BathymetrySource source, int rank, double cell})>[];
    for (var i = 0; i < sources.length; i++) {
      final cap = caps[i];
      if (cap == null) continue;
      covering.add((source: sources[i], rank: i, cell: cap.cellSizeMeters));
    }
    // A source leads only when it is more than preemptionFactor finer than
    // the one it overtakes; within that band the declared order stands.
    //
    // The relation is not transitive, so this is not a total order and
    // List.sort may resolve a pathological three-source chain either way.
    // With the shipped sources (3.4 m, 60 m, 115 m, 450 m) it is
    // well-behaved, and the two cases that matter are pinned by tests. Do
    // not extend the source list without revisiting this.
    covering.sort((a, b) {
      if (a.cell * preemptionFactor < b.cell) return -1;
      if (b.cell * preemptionFactor < a.cell) return 1;
      return a.rank.compareTo(b.rank);
    });
    return [for (final c in covering) c.source];
  }
}
