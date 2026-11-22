import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// The number of distinct dives each of [computerIds] recorded: a data
/// source from it, primary or not, or the dive's own `computer_id` (a dive
/// attributed before data sources existed). This is what "Dives imported"
/// shows (issue #4846). The stored `dive_count` only ever counted a
/// computer's own downloads, so dives that came to it later by a relink or a
/// merge were missing from it. The same union decides which dives carry the
/// computer's Equipment item. A computer with no dives has no entry.
Future<Map<String, int>> diveComputerDiveCounts(
  AppDatabase db,
  List<String> computerIds,
) async {
  final counts = <String, int>{};
  // Each id is bound twice per statement.
  for (final chunk in seriesIdChunks(
    computerIds.toSet().toList(),
    size: kSeriesIdChunkSize ~/ 2,
  )) {
    final marks = List.filled(chunk.length, '?').join(', ');
    final rows = await db
        .customSelect(
          'SELECT computer_id, COUNT(*) AS dives FROM ('
          'SELECT computer_id, dive_id FROM dive_data_sources '
          'WHERE computer_id IN ($marks) '
          'UNION SELECT computer_id, id FROM dives '
          'WHERE computer_id IN ($marks)'
          ') GROUP BY computer_id',
          variables: [
            for (final id in [...chunk, ...chunk]) Variable<String>(id),
          ],
          readsFrom: {db.diveDataSources, db.dives},
        )
        .get();
    for (final r in rows) {
      counts[r.read<String>('computer_id')] = r.read<int>('dives');
    }
  }
  return counts;
}
