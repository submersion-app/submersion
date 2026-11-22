/// The identity columns of one `dive_profile_series` row, read without its
/// blob by `ProfileSeriesRepository.getIdentitiesForDive`.
///
/// Kept in the domain, free of Flutter and of the repository, so the
/// database layer can use it: `database.dart`'s imports stay Flutter-free
/// (see `database_import_graph_test.dart`).
typedef ProfileSeriesIdentity = ({
  String id,
  String? computerId,
  String? sourceId,
  bool isPrimary,
  bool? isEdit,
});

/// The ids of the live series in [series] that are manual edits: the rule
/// behind `ProfileSeriesRepository.liveEditIds`, which documents it in full.
///
/// A series written since schema v357 says what it is in `is_edit`, and
/// that answer is final. One written before it, with the mark null, is an
/// edit by its shape: live with no computer, over a demoted generation of
/// its own source or of none.
Set<String> profileLiveEditIds(List<ProfileSeriesIdentity> series) {
  // A marked edit demoted beneath says the live series is the original
  // the diver re-activated over it, not an edit (issue #4386).
  bool editByShape(ProfileSeriesIdentity live) =>
      live.computerId == null &&
      series.any(
        (s) =>
            !s.isPrimary &&
            s.isEdit != true &&
            (live.sourceId == null ||
                s.sourceId == null ||
                s.sourceId == live.sourceId),
      );
  return {
    for (final live in series)
      if (live.isPrimary && (live.isEdit ?? editByShape(live))) live.id,
  };
}
