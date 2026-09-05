import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/data/sources/emodnet_source.dart';
import 'package:submersion/features/bathymetry/data/sources/etopo_erddap_source.dart';
import 'package:submersion/features/bathymetry/data/sources/gmrt_source.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_bathy_tile_cache_repository.dart';
import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';
import 'package:submersion/features/bathymetry/data/swiss_lake_depth_service.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// How long a TRANSIENT null (fetch failure, cache DB not ready) survives
/// before the grid provider forgets it and lets the next read retry.
/// Without this, one offline moment would pin "no bathymetry" onto a cell
/// for the whole app session — Riverpod families memoize their last value.
/// Mutable only so tests can zero it.
@visibleForTesting
Duration bathymetryTransientRetryBackoff = const Duration(seconds: 30);

/// Null when the local cache database is not initialized (early startup,
/// plain widget tests): bathymetry silently degrades to synthesized
/// terrain rather than erroring.
final bathymetryRepositoryProvider = Provider<BathymetryRepository?>((ref) {
  try {
    final db = LocalCacheDatabaseService.instance.database;
    return BathymetryRepository(
      db: db,
      resolver: BathymetryResolver(
        // Tier order: swissBATHY3D first (lake-only, ~0.5-2 m, beats every
        // other tier where it applies), then regional survey data, then
        // global GMRT, then the coarse public-domain fallback.
        sources: [
          SwissBathy3dSource(tileCache: SwissBathyTileCacheRepository(db)),
          EmodnetSource(),
          GmrtSource(),
          EtopoErddapSource(),
        ],
      ),
    );
  } on StateError {
    return null;
  }
});

/// Depth queries for Swiss dive sites via swissBATHY3D directly (Part 1 of
/// the Bathymetrie-Daten Schweiz task) — bypasses the resolver's tiered
/// best-source-wins mosaic since this is a single-coordinate lookup, not a
/// terrain grid for rendering. Null when the local cache database is not
/// initialized, matching [bathymetryRepositoryProvider].
final swissLakeDepthServiceProvider = Provider<SwissLakeDepthService?>((ref) {
  try {
    final db = LocalCacheDatabaseService.instance.database;
    return SwissLakeDepthService(
      SwissBathy3dSource(tileCache: SwissBathyTileCacheRepository(db)),
    );
  } on StateError {
    return null;
  }
});

/// Immediately revalidates every cached swissBATHY3D tile's freshness (the
/// "reload map data" action in Settings > Appearance), instead of waiting
/// for each tile's individual [SwissBathy3dSource.staleCheckInterval] to
/// elapse. Null when the local cache database is not initialized, matching
/// [bathymetryRepositoryProvider].
final swissBathyManualRefreshProvider =
    Provider<Future<SwissBathyRefreshSummary?> Function()>((ref) {
      return () async {
        final LocalCacheDatabase db;
        try {
          db = LocalCacheDatabaseService.instance.database;
        } on StateError {
          return null;
        }
        final source = SwissBathy3dSource(
          tileCache: SwissBathyTileCacheRepository(db),
        );
        return source.refreshAllCachedTiles();
      };
    });

/// The cached/fetched grid for a QUANTIZED coordinate cell. Callers must
/// key the family with [BathymetryRepository.quantize] so every coordinate
/// in a cell shares one entry. Never errors: null means no real terrain —
/// but only DEFINITIVE nulls (a cached "no water here") are memoized;
/// transient failures self-invalidate after
/// [bathymetryTransientRetryBackoff] so a later visit retries.
// no-tick: a write-once cache in the local-only cache database. Rows are keyed
// by quantized cell and never updated in place -- a span change misses the old
// key rather than rewriting it -- and the transient-failure case already
// self-invalidates on a backoff timer.
final bathymetryGridProvider =
    FutureProvider.family<BathymetryGrid?, ({double lat, double lon})>((
      ref,
      cell,
    ) async {
      void retryLater() {
        final timer = Timer(
          bathymetryTransientRetryBackoff,
          ref.invalidateSelf,
        );
        ref.onDispose(timer.cancel);
      }

      final repo = ref.watch(bathymetryRepositoryProvider);
      if (repo == null) {
        retryLater(); // cache DB may simply not be ready yet
        return null;
      }
      final center = GeoPoint(cell.lat, cell.lon);
      final grid = await repo.getGrid(center);
      if (grid == null && !await repo.hasCachedAnswer(center)) {
        retryLater(); // transient failure, not a real "no water here"
      }
      return grid;
    });
