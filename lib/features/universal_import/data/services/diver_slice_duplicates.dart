import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/data/services/payload_slicer.dart';

/// One slice's duplicate check, moved onto the full payload's indices
/// (issue #1893). An in-batch pointer names another dive of the same slice,
/// so it moves too.
ImportDuplicateResult duplicatesToGlobal(
  DiverSlice slice,
  ImportDuplicateResult local,
) {
  const dives = ImportEntityType.dives;
  return ImportDuplicateResult(
    duplicates: {
      for (final entry in local.duplicates.entries)
        entry.key: slice.toGlobalSet(entry.key, entry.value),
    },
    diveMatches: {
      for (final entry in local.diveMatches.entries)
        slice.toGlobal(dives, entry.key): withInBatchIndex(
          entry.value,
          switch (entry.value.inBatchIndex) {
            final int i => slice.toGlobal(dives, i),
            null => null,
          },
        ),
    },
    entityMatches: {
      for (final entry in local.entityMatches.entries)
        entry.key: slice.toGlobalMap(entry.key, entry.value),
    },
  );
}

/// Results that [duplicatesToGlobal] already moved, combined into one.
ImportDuplicateResult mergeDuplicateResults(
  Iterable<ImportDuplicateResult> results,
) {
  final duplicates = <ImportEntityType, Set<int>>{};
  final diveMatches = <int, DiveMatchResult>{};
  final entityMatches = <ImportEntityType, Map<int, EntityMatchResult>>{};
  for (final result in results) {
    result.duplicates.forEach(
      (type, indices) => (duplicates[type] ??= {}).addAll(indices),
    );
    diveMatches.addAll(result.diveMatches);
    result.entityMatches.forEach(
      (type, matches) => (entityMatches[type] ??= {}).addAll(matches),
    );
  }
  return ImportDuplicateResult(
    duplicates: duplicates,
    diveMatches: diveMatches,
    entityMatches: entityMatches,
  );
}

/// [match] with its in-batch pointer replaced; every other field is kept.
DiveMatchResult withInBatchIndex(DiveMatchResult match, int? inBatchIndex) {
  return DiveMatchResult(
    diveId: match.diveId,
    score: match.score,
    timeDifferenceMs: match.timeDifferenceMs,
    depthDifferenceMeters: match.depthDifferenceMeters,
    durationDifferenceSeconds: match.durationDifferenceSeconds,
    siteName: match.siteName,
    matchedComputerId: match.matchedComputerId,
    matchedExistingSource: match.matchedExistingSource,
    inBatchIndex: inBatchIndex,
  );
}
