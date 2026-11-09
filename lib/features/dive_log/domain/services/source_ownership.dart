import 'package:submersion/core/database/database.dart';

/// Whether [row] is the sole author of its `(dive_id, computer_id)` profile
/// strand, with that strand still in [row]'s own parse frame.
///
/// Re-parsing (dive computer raw bytes) and resyncing (a stored import file)
/// both delete what the source wrote on the strand and re-insert the parsed
/// samples at their own timestamps, so either is only safe when both hold.
/// A sequential combine breaks both: [DiveMergeService.apply] re-bases each
/// segment onto the merged timeline and carries every original's source row
/// over demoted to non-primary, so re-parsing one of them would drop half a
/// dive back at the original download's timestamps and delete the
/// synthesized surface-gap samples along the way (#1164).
///
/// Three signals, any of which disqualifies the row:
///
/// - **No row on the dive is primary.** That is exactly a combined dive:
///   the merge demotes all carried rows and the merged dive has no source
///   row of its own. [DiveConsolidationService] demotes only its
///   secondaries, so a consolidated dive keeps a primary row and its
///   per-computer strands stay re-parseable.
/// - **The row was carried by a combine** (`mergeSourceSlot` is set). The
///   merge re-based its samples by the segment's place on the merged
///   timeline and recorded no offset, so the raw bytes cannot put them back
///   there. The first signal stops seeing that once the dive has a primary
///   row again, which consolidating the combined dive with another import
///   gives it; the slot survives that, so this one does not (issue #4367).
///   It costs one false negative: [DiveUncombineService] keeps the slots of
///   a restored segment that holds several strands, whose samples it has
///   moved back to their own frame. Such a row keeps its profile rather
///   than re-parsing it, the safe direction to be wrong in.
/// - **A re-parseable sibling row shares this row's `computerId`** (null
///   counts as equal to null). The strand has more than one author, so
///   whichever source re-parses last would wipe out what the others wrote
///   -- true of same-computer halves regardless of the primary flag. Only
///   siblings carrying raw data count: deleting a computer nulls its
///   sources' `computerId` (FK `setNull`) and
///   `_backfillProvenanceSnapshots` adds rows with no `computerId` at all,
///   so sharing a null strand with a row that can never be re-parsed is an
///   ordinary shape, not contention.
bool sourceOwnsProfileStrand(
  DiveDataSourcesData row,
  List<DiveDataSourcesData> allRowsForDive,
) {
  if (!allRowsForDive.any((r) => r.isPrimary)) return false;
  if (row.mergeSourceSlot != null) return false;
  return !allRowsForDive.any(
    (r) =>
        r.id != row.id && r.computerId == row.computerId && r.rawData != null,
  );
}
