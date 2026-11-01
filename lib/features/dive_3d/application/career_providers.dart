import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_3d/domain/career/career_dive_shape.dart';
import 'package:submersion/features/dive_3d/domain/career/career_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/career/career_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// A career-terrain query: all dives at a site, or dives in a date range.
/// Structural equality (record) makes it a stable family key.
typedef CareerQuery = ({
  String? siteId,
  DateTime? fromDate,
  DateTime? toDate,
  int cap,
});

CareerQuery careerSiteQuery(String siteId, {int cap = 60}) =>
    (siteId: siteId, fromDate: null, toDate: null, cap: cap);

CareerQuery careerRangeQuery(DateTime from, DateTime to, {int cap = 60}) =>
    (siteId: null, fromDate: from, toDate: to, cap: cap);

/// The set of dives for the terrain, newest-kept up to [CareerQuery.cap],
/// re-indexed oldest-first. Null when no dive matches, or none that matches
/// has a profile to draw.
///
/// Two repository reads, both bounded to the set (issue #3857): the newest
/// matching dives as id and start, then every kept dive's primary-source
/// profile in one batch, decoded and reduced to [kCareerPointsPerDive]
/// points off the UI isolate (inline only when the whole set is a few
/// hundred samples). Dives outside the site or date range are never
/// hydrated and their profiles never read: a site read seeks the site
/// index, and a date-range read scans the `dives` rows once in SQL.
///
/// Follows the analysis-input tick: it covers the dives table, the profile
/// series and the data sources, which are exactly what this reads.
final careerSceneDataProvider =
    FutureProvider.family<CareerSceneData?, CareerQuery>((ref, query) async {
      final repository = ref.watch(diveRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      ref.invalidateSelfWhen(repository.watchAnalysisInputChanges());

      final newest = await repository.getNewestDiveStarts(
        diverId: diverId,
        siteId: query.siteId,
        from: query.fromDate,
        to: query.toDate,
        limit: query.cap,
      );
      if (newest.isEmpty) return null;
      final kept = newest.reversed.toList(); // oldest first

      final shapes = await repository.reducePrimarySourceProfiles([
        for (final dive in kept) dive.id,
      ], careerDiveShapeOf);
      final inputs = <CareerDiveInput>[];
      for (final dive in kept) {
        final shape = shapes[dive.id];
        if (shape == null) continue; // no profile, or a manual dive
        inputs.add(
          CareerDiveInput(
            index: inputs.length,
            date: dive.start,
            maxDepthMeters: shape.maxDepthMeters,
            times: shape.times,
            depths: shape.depths,
          ),
        );
      }
      if (inputs.isEmpty) return null;
      return CareerSceneData(dives: inputs);
    });

typedef CareerGeometryKey = ({CareerQuery query, CareerColorMode colorMode});

/// The renderable career terrain per (query, color mode).
final careerGeometryProvider =
    FutureProvider.family<Scene3d?, CareerGeometryKey>((ref, key) async {
      final data = await ref.watch(careerSceneDataProvider(key.query).future);
      if (data == null) return null;
      if (data.dives.length < 8) {
        return const CareerGeometryService().build(
          data,
          colorMode: key.colorMode,
        );
      }
      return compute(_careerIsolate, (data, key.colorMode));
    });

Scene3d _careerIsolate((CareerSceneData, CareerColorMode) input) =>
    const CareerGeometryService().build(input.$1, colorMode: input.$2);
