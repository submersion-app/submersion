/// Phase 3 of in-place editing (issue #4527): the record pages other than
/// dives and sites (buddies, dive centres, certifications, courses,
/// documents, species, GPS and underwater tracks, trips, gear items and
/// equipment sets) open locked and edit in place.
///
/// One switch for all of them, off by default, turned on with
/// `--dart-define=UNLOCK_RECORD_EDITING=true` until the last of them is
/// done. Pages read it through a widget parameter that defaults to it, so a
/// test can turn it on for one page.
const bool kUnlockRecordEditing = bool.fromEnvironment('UNLOCK_RECORD_EDITING');
