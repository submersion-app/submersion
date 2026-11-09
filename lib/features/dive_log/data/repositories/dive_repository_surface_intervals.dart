part of 'dive_repository_impl.dart';

/// Surface intervals for a chosen set of dives (#4333).
extension DiveSurfaceIntervals on DiveRepository {
  /// The surface interval of each dive in [ids] that has one, keyed by id:
  /// the stored value, else the gap [diveSurfaceIntervalSecondsSql] works out
  /// from the previous dive, as the detail page and the dive table show it.
  /// A first dive, or an id that names no dive, is left out.
  ///
  /// Only the rows returned are narrowed to [ids]; the previous dive is still
  /// looked for across the whole log, so the gap matches [getSurfaceIntervals].
  // stats-scope-exempt: physiological interval between real dives, not a statistic
  Future<Map<String, Duration>> getSurfaceIntervalsFor(List<String> ids) async {
    final result = <String, Duration>{};
    for (final chunk in seriesIdChunks(ids.toSet().toList())) {
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT d.id AS id, ${diveSurfaceIntervalSecondsSql('d')} AS si '
            'FROM dives d WHERE d.id IN ($marks)',
            variables: [for (final id in chunk) Variable.withString(id)],
            readsFrom: {_db.dives, _db.diveProfileSeries},
          )
          .get();
      for (final row in rows) {
        if (row.readNullable<int>('si') case final seconds?) {
          result[row.read<String>('id')] = Duration(seconds: seconds);
        }
      }
    }
    return result;
  }
}
