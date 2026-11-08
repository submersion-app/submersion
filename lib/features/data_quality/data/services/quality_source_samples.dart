import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';
import 'package:submersion/features/dive_log/domain/services/series_source_owner.dart';

/// Each source's own samples, where the dive places them on the primary's
/// timeline (#4296), for [DiveQualityContext.sourceSamples]: every source
/// placed against the primary trace, and none that trace is drawn from.
///
/// A source that owns a primary series is part of the trace, not placed
/// against it: the flagged primary, or with none flagged, the source of a
/// single-computer dive's profile and every half of a combined one (a
/// Combine keeps each half's series primary and no source primary).
/// Checking one half against a trace that holds both would read a later
/// half that looks like the first as the first one misplaced. A
/// consolidated computer's series are never primary, so it is carried
/// wherever its source sorts.
///
/// Each series is grouped under [seriesSourceOwner]'s pick, and only a
/// source's live generation is read ([liveSeriesOf]): an edited source owns
/// its original and its edit over the same timestamps, and merging both
/// would interleave two profiles into one trace. Samples are sanitized like
/// the primary's: finite depths only.
Map<String, List<QualitySample>> qualitySourceSamples(
  List<DiveDataSource> sources,
  List<ProfileSeries> series,
) {
  if (sources.length < 2) return const {};
  String? ownerOf(ProfileSeries s) => seriesSourceOwner(
    sourceId: s.sourceId,
    computerId: s.computerId,
    sources: sources,
  );
  final onPrimaryTrace = {
    for (final s in sources)
      if (s.isPrimary) s.id,
    for (final s in series)
      if (s.isPrimary) ?ownerOf(s),
  };
  final grouped = <String, List<ProfileSeries>>{};
  for (final s in series) {
    final owner = ownerOf(s);
    if (owner == null || onPrimaryTrace.contains(owner)) continue;
    grouped.putIfAbsent(owner, () => []).add(s);
  }
  return {
    for (final entry in grouped.entries)
      entry.key: [
        for (final p in mergeSeriesPointsCollapsingDuplicates(
          liveSeriesOf(entry.value),
        ))
          if (p.depth.isFinite) QualitySample(t: p.timestamp, depth: p.depth),
      ],
  };
}
