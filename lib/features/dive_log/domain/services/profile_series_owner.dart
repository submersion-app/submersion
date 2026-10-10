import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

/// The data source of [sources] that owns a profile series with the given
/// [sourceId] and [computerId], or null when none does.
///
/// The same rule as the repository's ownership predicate: the source FK
/// first, then the source recording the same computer (`IS` semantics, so a
/// series with no computer belongs to a source with no computer). The second
/// half covers a series that predates the FK, and a source [sources] does not
/// list because it collapsed into its strand's chip on read. Among several
/// such sources the primary one wins, as it already holds the flag a switch
/// to the series would give it.
DiveDataSource? owningDataSource({
  required String? sourceId,
  required String? computerId,
  required List<DiveDataSource> sources,
}) {
  if (sourceId != null) {
    final bySource = sources.where((s) => s.id == sourceId).firstOrNull;
    if (bySource != null) return bySource;
  }
  final candidates = sources.where((s) => s.computerId == computerId);
  return candidates.where((s) => s.isPrimary).firstOrNull ??
      candidates.firstOrNull;
}
