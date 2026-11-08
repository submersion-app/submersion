import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';
import 'package:submersion/features/dive_log/domain/services/series_source_owner.dart';

/// Each non-primary source's own samples, where the dive places them on the
/// primary's timeline (#4296), for [DiveQualityContext.sourceSamples].
///
/// Each series is grouped under [seriesSourceOwner]'s pick. Samples are
/// sanitized like the primary's: finite depths only.
Map<String, List<QualitySample>> qualitySourceSamples(
  List<DiveDataSource> sources,
  List<ProfileSeries> series,
) {
  if (sources.length < 2) return const {};
  final primaryId = sources.where((s) => s.isPrimary).firstOrNull?.id;
  final grouped = <String, List<ProfileSeries>>{};
  for (final s in series) {
    final owner = seriesSourceOwner(
      sourceId: s.sourceId,
      computerId: s.computerId,
      sources: sources,
    );
    if (owner == null || owner == primaryId) continue;
    grouped.putIfAbsent(owner, () => []).add(s);
  }
  return {
    for (final entry in grouped.entries)
      entry.key: [
        for (final p in mergeSeriesPointsCollapsingDuplicates(entry.value))
          if (p.depth.isFinite) QualitySample(t: p.timestamp, depth: p.depth),
      ],
  };
}
