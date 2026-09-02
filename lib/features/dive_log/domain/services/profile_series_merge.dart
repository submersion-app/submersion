import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample_point.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';

/// Every sample of every series in [series], interleaved by timestamp.
///
/// This is what `ORDER BY timestamp` over the legacy row table produced for
/// a multi-source dive. Stable: samples that share a timestamp keep the
/// order of [series] and then their order within the series, so callers
/// that pass series in `(start_timestamp, id)` order get a deterministic
/// list on every device.
List<DiveProfilePoint> mergeSeriesPoints(List<ProfileSeries> series) {
  if (series.isEmpty) return const [];
  if (series.length == 1) return series.single.points;
  final entries = <(int timestamp, int order, ProfileSample sample)>[];
  var order = 0;
  for (final s in series) {
    for (final sample in s.samples) {
      entries.add((sample.timestamp, order++, sample));
    }
  }
  entries.sort((a, b) {
    final byTime = a.$1.compareTo(b.$1);
    return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
  });
  return [for (final entry in entries) entry.$3.toPoint()];
}

/// [mergeSeriesPoints] with the legacy `_dropDuplicateSamples` rule applied:
/// a legacy row carried its identity columns, so whole-row equality only ever
/// collapsed duplicates INSIDE one identity group `(computerId, sourceId,
/// isPrimary)`. Two devices that each download the same computer mint
/// different series ids and sync unions them; this is the read that keeps
/// those from rendering every sample twice. Identical samples from two
/// different computers are both kept, as the legacy read kept them.
List<DiveProfilePoint> mergeSeriesPointsCollapsingDuplicates(
  List<ProfileSeries> series,
) {
  if (series.isEmpty) return const [];
  final entries =
      <(int timestamp, int order, ProfileSeries owner, ProfileSample sample)>[];
  var order = 0;
  for (final s in series) {
    for (final sample in s.samples) {
      entries.add((sample.timestamp, order++, s, sample));
    }
  }
  entries.sort((a, b) {
    final byTime = a.$1.compareTo(b.$1);
    return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
  });
  final seen = <(String?, String?, bool, ProfileSample)>{};
  return [
    for (final e in entries)
      if (seen.add((e.$3.computerId, e.$3.sourceId, e.$3.isPrimary, e.$4)))
        e.$4.toPoint(),
  ];
}

/// Interleaves every sample of [series] by timestamp into one tank pressure
/// list. Ties keep series order, then within-series order, so the result is
/// deterministic for the `(start_timestamp, id)` order the repositories
/// return.
List<TankPressurePoint> mergeTankSeriesPoints(List<TankPressureSeries> series) {
  if (series.isEmpty) return const [];
  final entries = <(int, int, TankPressurePoint)>[];
  var order = 0;
  for (final s in series) {
    for (var i = 0; i < s.samples.length; i++) {
      final sample = s.samples[i];
      entries.add((
        sample.timestamp,
        order++,
        TankPressurePoint(
          tankId: s.tankId,
          timestamp: sample.timestamp,
          pressure: sample.pressure,
        ),
      ));
    }
  }
  entries.sort((a, b) {
    final byTime = a.$1.compareTo(b.$1);
    return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
  });
  return [for (final e in entries) e.$3];
}

/// Series-level twin of `DiveRepository._dropSupersededOriginals`.
///
/// A saved profile edit demotes the originals and inserts a null-computer
/// series under the same source; the demoted originals of the primary
/// family are superseded and must not render next to the edit. Family
/// membership follows the legacy rule: with no data sources every series is
/// family; otherwise a null-computer series or one on the primary computer
/// is. The caller resolves the primary computer only when a demoted series
/// carries a computer id, as `_dropSupersededOriginals` does; when it does
/// not, only null-computer series are family. Nothing is dropped unless the
/// family holds both a primary and a demoted member.
List<ProfileSeries> dropSupersededSeries(
  List<ProfileSeries> series, {
  required bool hasSources,
  required String? primaryComputerId,
}) {
  if (!series.any((s) => !s.isPrimary) || !series.any((s) => s.isPrimary)) {
    return series;
  }
  bool isFamily(ProfileSeries s) =>
      !hasSources || s.computerId == null || s.computerId == primaryComputerId;
  final family = series.where(isFamily);
  final edited =
      family.any((s) => s.isPrimary) && family.any((s) => !s.isPrimary);
  if (!edited) return series;
  return [
    for (final s in series)
      if (s.isPrimary || !isFamily(s)) s,
  ];
}
