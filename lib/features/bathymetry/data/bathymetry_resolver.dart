import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

const _log = LoggerService('BathymetryResolver');

/// The outcome of walking the source tiers for one coordinate.
///
/// - `grid != null && definitive`: usable terrain, cacheable as the answer.
/// - `grid != null && !definitive`: usable terrain, but reached only past a
///   source that failed transiently (issue #1770). Show it, but must NOT be
///   cached: the failed source may well have won, and a cached fallback
///   would stop it from ever being asked again.
/// - `grid == null && definitive`: fetched fine, genuinely no water here —
///   cacheable as a negative answer.
/// - `grid == null && !definitive`: transient failure — must NOT be cached.
class BathymetryResolution {
  final BathymetryGrid? grid;
  final bool definitive;

  const BathymetryResolution.ok(BathymetryGrid this.grid) : definitive = true;
  const BathymetryResolution.provisional(BathymetryGrid this.grid)
    : definitive = false;
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

  /// [spanMeters] defaults to [defaultSpanMeters] (the always-loaded 8 km
  /// base square). Callers building a smaller, additional LOD patch pass a
  /// narrower span explicitly; every source-quality gate below (known-
  /// fraction floor, wet-fraction floor) applies identically regardless of
  /// span, so a patch source that cannot actually deliver finer detail is
  /// rejected the same way the base fetch would reject it.
  Future<BathymetryResolution> resolve(
    GeoPoint center, {
    double? spanMeters,
  }) async {
    final span = spanMeters ?? defaultSpanMeters;
    final (:ordered, :probeFailed) = await _order(center);
    var globalSourceSaidDry = false;
    // Whether any source failed to answer (probe or fetch) on the way to the
    // result. Such a source may have outranked the winner, or found water a
    // global source called dry, so the answer is only provisional: returned
    // for display, never cached as definitive (issue #1770).
    //
    // A failed probe taints the result wherever that source sits in the
    // declared order: without its capability the resolver cannot know its
    // cell size, and a materially finer source preempts regardless of rank
    // (see [preemptionFactor]). Unlike a fetch failure, it cannot be placed
    // "below the winner". NoaaDemSource's coverage regions keep this from
    // reaching coordinates where the only network probe could never win.
    var sawTransientFailure = probeFailed;
    for (final source in ordered) {
      try {
        final grid = await source.fetch(center, spanMeters: span);
        if (grid.knownFraction < source.minKnownFraction) {
          // Nominally fine, actually absent. Deliberately NOT treated as a
          // dry answer: a grid this empty proves nothing about the water,
          // and caching it as 'empty' would pin the cell forever. The
          // floor itself is per-source -- see [BathymetrySource.
          // minKnownFraction]'s doc for why the same number is wrong for a
          // regional, already-confirmed-covered source like swissBATHY3D.
          _log.debug(
            '${source.id} rejected at ${center.latitude},${center.longitude}: '
            'knownFraction ${grid.knownFraction} < ${source.minKnownFraction}',
          );
          continue;
        }
        if (grid.wetFraction >= minWetFraction) {
          if (!sawTransientFailure) return BathymetryResolution.ok(grid);
          _log.info(
            '${source.id} accepted provisionally at '
            '${center.latitude},${center.longitude}: a source ahead of it '
            'failed transiently, so this answer is not cached',
          );
          return BathymetryResolution.provisional(grid);
        }
        _log.debug(
          '${source.id} rejected at ${center.latitude},${center.longitude}: '
          'wetFraction ${grid.wetFraction} < $minWetFraction',
        );
        // A dry answer only proves "no water here" if the source actually
        // covers everywhere; a regional edge cell proves nothing.
        if (source.global) globalSourceSaidDry = true;
      } on BathymetryFetchException catch (e) {
        // Transient: fall through to the next source.
        sawTransientFailure = true;
        _log.warning(
          '${source.id} fetch failed at ${center.latitude},${center.longitude}',
          error: e,
        );
      } catch (e, stackTrace) {
        // A source blowing up with anything else (a TypeError from an
        // unexpected response shape, an ArgumentError) must not kill the
        // whole scene: treat it exactly like a transient failure.
        sawTransientFailure = true;
        _log.warning(
          '${source.id} fetch threw unexpectedly at '
          '${center.latitude},${center.longitude}',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    // Every source was walked here, so a failure anywhere (ahead of the dry
    // answer or behind it) is a source that never said whether it had water.
    return globalSourceSaidDry && !sawTransientFailure
        ? const BathymetryResolution.empty()
        : const BathymetryResolution.transientFailure();
  }

  /// Covering sources in fetch order. Probes run concurrently because a
  /// probe may be a network call and they are independent. A probe that
  /// fails for any reason drops that source rather than failing the scene,
  /// but is reported as [probeFailed]: "could not ask" is not "does not
  /// cover", and the resolver must not cache an answer that source might
  /// have beaten.
  Future<({List<BathymetrySource> ordered, bool probeFailed})> _order(
    GeoPoint center,
  ) async {
    var probeFailed = false;
    final caps = await Future.wait(
      sources.map((s) async {
        try {
          return await s.probe(center);
        } catch (e, stackTrace) {
          probeFailed = true;
          _log.warning(
            '${s.id} probe failed at ${center.latitude},${center.longitude}',
            error: e,
            stackTrace: stackTrace,
          );
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
    return (
      ordered: [for (final c in covering) c.source],
      probeFailed: probeFailed,
    );
  }
}
