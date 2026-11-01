import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_reduction.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';

/// The columns of a shown `dive_data_sources` row that decide which series it
/// owns.
///
/// Not the row itself: this crosses to a background isolate, and a row can
/// carry its whole raw download.
typedef ShownSource = ({String id, String? computerId});

/// The sources one dive shows, in shown order, and the shown row each of its
/// source rows speaks through: what [sourceProfilesReduction] needs per dive.
typedef DiveShownSources = ({
  List<ShownSource> shownSources,
  Map<String, String> shownIdByRow,
});

/// Reduces a dive's series to one profile per source, by the rules
/// `DiveRepository.getProfilesByDataSource` documents.
///
/// [shownSources] are the rows the dive shows, in shown order. [shownIdByRow]
/// maps every source row to the shown row that speaks for it.
SeriesReduce<Map<String, SourceProfile>> sourceProfilesReduction({
  required String diveId,
  required List<ShownSource> shownSources,
  required Map<String, String> shownIdByRow,
}) =>
    (series) => shownSources.isEmpty
    ? _syntheticPrimaryProfile(diveId, series)
    : _profilesBySource(series, shownSources, shownIdByRow);

/// [reduce] over the primary source's profile of every dive in
/// [shownByDive]: the first entry [sourceProfilesReduction] would give that
/// dive, so a batched reader sees exactly the samples the single-dive read
/// shows for the primary source, superseded originals dropped and all.
///
/// Every dive in [shownByDive] gets an entry. One with no series, or whose
/// sources own none, reduces an empty list; the caller decides what that
/// means (issue #3857: the career terrain skips it, as it skipped an empty
/// bucket before).
///
/// [series] must be grouped by dive and ordered within each dive as
/// `ProfileSeriesRepository.getRowsForDives` returns them. Both this and
/// [reduce] cross to a background isolate, so [reduce] must be a top-level
/// function (see [SeriesReduce]).
SeriesReduce<Map<String, R>> primarySourceProfilesReduction<R>({
  required Map<String, DiveShownSources> shownByDive,
  required R Function(List<DiveProfilePoint> points) reduce,
}) => (series) {
  final byDive = <String, List<ProfileSeries>>{};
  for (final s in series) {
    byDive.putIfAbsent(s.diveId, () => []).add(s);
  }
  return {
    for (final MapEntry(key: diveId, value: shown) in shownByDive.entries)
      diveId: reduce(
        sourceProfilesReduction(
              diveId: diveId,
              shownSources: shown.shownSources,
              shownIdByRow: shown.shownIdByRow,
            )(byDive[diveId] ?? const []).values.firstOrNull?.points ??
            const [],
      ),
  };
};

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
  final live = _liveSeriesByShownSource(series, shownSources, shownIdByRow);
  return {
    for (final s in shownSources)
      s.id: SourceProfile(
        sourceId: s.id,
        computerId: s.computerId,
        isEdited: s.id == shownSources.first.id && live.primaryIsEdited,
        points: mergeSeriesPoints(live.byShownId[s.id]!),
      ),
  };
}

/// The series behind each source's profile in [sourceProfilesReduction], kept
/// apart and filed under the source row that owns each one, for a reader that
/// has to reproduce them rather than draw them (issue #3965).
///
/// Keyed by row, not by shown source: a row that collapsed into another's chip
/// still owns its series, and a restore gives it them back. A series naming no
/// row goes to the row the read gives it to.
///
/// Reads only identity and summary columns, so [series] may hold no samples.
Map<String, List<ProfileSeries>> liveSeriesBySourceRow({
  required List<ProfileSeries> series,
  required List<ShownSource> shownSources,
  required Map<String, String> shownIdByRow,
}) {
  final live = _liveSeriesByShownSource(series, shownSources, shownIdByRow);
  final byRow = <String, List<ProfileSeries>>{};
  for (final entry in live.byShownId.entries) {
    for (final s in entry.value) {
      final owner = shownIdByRow.containsKey(s.sourceId)
          ? s.sourceId!
          : entry.key;
      byRow.putIfAbsent(owner, () => []).add(s);
    }
  }
  return byRow;
}

/// [series] grouped by the shown source that speaks for it, without the ones
/// a saved edit superseded. [shownSources] is never empty.
({Map<String, List<ProfileSeries>> byShownId, bool primaryIsEdited})
_liveSeriesByShownSource(
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
  return (
    byShownId: {
      for (final s in shownSources)
        // The primary's superseded originals were already dropped above;
        // another source may still own an edit and its original.
        s.id: s.id == primary.id
            ? grouped[s.id]!
            : liveSeriesOf(grouped[s.id]!),
    },
    primaryIsEdited: primaryIsEdited,
  );
}
