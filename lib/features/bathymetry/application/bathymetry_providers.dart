import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/data/sources/emodnet_source.dart';
import 'package:submersion/features/bathymetry/data/sources/etopo_erddap_source.dart';
import 'package:submersion/features/bathymetry/data/sources/gmrt_source.dart';
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
        // Tier order: regional survey data first, then global GMRT, then
        // the coarse public-domain fallback.
        sources: [EmodnetSource(), GmrtSource(), EtopoErddapSource()],
      ),
    );
  } on StateError {
    return null;
  }
});

/// The cached/fetched grid for a QUANTIZED coordinate cell. Callers must
/// key the family with [BathymetryRepository.quantize] so every coordinate
/// in a cell shares one entry. Never errors: null means no real terrain —
/// but only DEFINITIVE nulls (a cached "no water here") are memoized;
/// transient failures self-invalidate after
/// [bathymetryTransientRetryBackoff] so a later visit retries.
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
