import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_reduction.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';

/// The columns of a shown `dive_data_sources` row that decide which series it
/// owns.
///
/// Not the row itself: this crosses to a background isolate, and a row can
/// carry its whole raw download.
typedef ShownSource = ({String id, String? computerId});

/// Reduces a dive's series to one profile per source. Keys are source ids,
/// primary source first.
///
/// [shownSources] are the rows the dive shows, in shown order. [shownIdByRow]
/// maps every source row to the shown row that speaks for it.
///
/// Rows with a null computerId belong to the primary source (schema
/// convention). Rows whose computerId matches no source also fall back to the
/// primary source so no data is ever dropped or bucketed under an invented
/// key. When an edited profile exists, the primary source carries only the
/// edited rows (isEdited: true).
SeriesReduce<Map<String, SourceProfile>> sourceProfilesReduction({
  required String diveId,
  required List<ShownSource> shownSources,
  required Map<String, String> shownIdByRow,
}) =>
    (series) => shownSources.isEmpty
    ? _syntheticPrimaryProfile(diveId, series)
    : _profilesBySource(series, shownSources, shownIdByRow);

/// Dives with series but no dive_data_sources row (older imports predate that
/// table): synthesize the primary source.
Map<String, SourceProfile> _syntheticPrimaryProfile(
  String diveId,
  List<ProfileSeries> series,
) {
  final primary = [
    for (final s in series)
      if (s.isPrimary) s,
  ];
  if (primary.isEmpty) return {};
  final syntheticSourceId = legacyDataSourceId(diveId);
  return {
    syntheticSourceId: SourceProfile(
      sourceId: syntheticSourceId,
      computerId: primary.first.computerId,
      isEdited: series.any((s) => !s.isPrimary),
      points: mergeSeriesPoints(primary),
    ),
  };
}

Map<String, SourceProfile> _profilesBySource(
  List<ProfileSeries> series,
  List<ShownSource> shownSources,
  Map<String, String> shownIdByRow,
) {
  final primary = shownSources.first;
  final sourceIdByComputer = <String, String>{
    for (final s in shownSources)
      if (s.computerId != null) s.computerId!: s.id,
  };
  // The FK is authoritative; a series without one follows the pre-v154
  // computer convention (issue #1149).
  bool isPrimaryFamily(ProfileSeries s) => shownIdByRow.containsKey(s.sourceId)
      ? shownIdByRow[s.sourceId] == primary.id
      : s.computerId == null || s.computerId == primary.computerId;
  final family = series.where(isPrimaryFamily);
  final hasEditedProfile =
      family.any((s) => s.isPrimary) && family.any((s) => !s.isPrimary);

  final grouped = <String, List<ProfileSeries>>{
    for (final s in shownSources) s.id: [],
  };
  var primaryIsEdited = false;
  for (final s in series) {
    final owner = shownIdByRow.containsKey(s.sourceId)
        ? shownIdByRow[s.sourceId]!
        : s.computerId == null
        ? primary.id
        : (sourceIdByComputer[s.computerId!] ?? primary.id);
    if (hasEditedProfile && isPrimaryFamily(s)) {
      if (!s.isPrimary) continue;
      primaryIsEdited = true;
    }
    grouped[owner]!.add(s);
  }
  return {
    for (final s in shownSources)
      s.id: SourceProfile(
        sourceId: s.id,
        computerId: s.computerId,
        isEdited: s.id == primary.id && primaryIsEdited,
        // The primary's superseded originals were already dropped above;
        // another source may still own an edit and its original.
        points: mergeSeriesPoints(
          s.id == primary.id ? grouped[s.id]! : liveSeriesOf(grouped[s.id]!),
        ),
      ),
  };
}
