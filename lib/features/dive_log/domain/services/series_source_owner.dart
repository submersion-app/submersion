import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

/// The source of [sources] a recorded series or event belongs to, or null.
///
/// A row that names a source belongs to it, when the dive still has it. One
/// that names none belongs to the source of its computer, but only when
/// exactly one source has that computer: two file imports carry no computer,
/// and a guess between them would move another recording.
String? seriesSourceOwner({
  required String? sourceId,
  required String? computerId,
  required List<DiveDataSource> sources,
}) {
  if (sourceId != null) {
    return sources.any((s) => s.id == sourceId) ? sourceId : null;
  }
  if (computerId == null) return null;
  final sharing = [
    for (final s in sources)
      if (s.computerId == computerId) s,
  ];
  return sharing.length == 1 ? sharing.single.id : null;
}
