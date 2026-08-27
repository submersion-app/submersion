import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/domain/career/career_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/career/career_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';

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

DateTime _startOf(Dive d) => d.entryTime ?? d.dateTime;

bool _matches(Dive dive, CareerQuery q) {
  if (q.siteId != null) return dive.site?.id == q.siteId;
  final start = _startOf(dive);
  final afterFrom = q.fromDate == null || !start.isBefore(q.fromDate!);
  final beforeTo = q.toDate == null || !start.isAfter(q.toDate!);
  return afterFrom && beforeTo;
}

/// Downsample target per dive in the terrain (mini-profile resolution).
const int _pointsPerDive = 120;

/// The set of dives for the terrain, newest-kept up to [CareerQuery.cap],
/// re-indexed oldest-first. Null when no dive matches.
final careerSceneDataProvider =
    FutureProvider.family<CareerSceneData?, CareerQuery>((ref, query) async {
      final all = await ref.watch(divesProvider.future);
      final matched = all.where((d) => _matches(d, query)).toList()
        ..sort((a, b) => _startOf(b).compareTo(_startOf(a))); // newest first
      final kept = matched.take(query.cap).toList().reversed.toList();
      if (kept.isEmpty) return null;

      final inputs = <CareerDiveInput>[];
      for (var i = 0; i < kept.length; i++) {
        final dive = kept[i];
        final sources = await ref.watch(sourceProfilesProvider(dive.id).future);
        final points = sources.values.firstOrNull?.points ?? const [];
        if (points.length < 2) continue;
        final sorted = [...points]..sort((a, b) => a.timestamp - b.timestamp);
        final indices = decimateSeriesIndices([
          for (final p in sorted) p.depth,
        ], targetPoints: _pointsPerDive);
        var maxDepth = 0.0;
        for (final p in sorted) {
          if (p.depth > maxDepth) maxDepth = p.depth;
        }
        inputs.add(
          CareerDiveInput(
            index: inputs.length,
            date: _startOf(dive),
            maxDepthMeters: maxDepth,
            times: [for (final j in indices) sorted[j].timestamp.toDouble()],
            depths: [for (final j in indices) sorted[j].depth],
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
