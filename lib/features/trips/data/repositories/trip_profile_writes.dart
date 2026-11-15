import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

/// When a dive's stored profile samples are written: a download or an import
/// filling in a dive that was logged by hand, a reparse, a merge.
///
/// The trip day picker asks for its profiles again on each one, which brings
/// in the samples of a dive it drew as an estimate. A dive it already drew
/// from samples keeps that shape: the shared batcher re-reads only the dives
/// it holds none for, so a reparse shows on the next app start. It watches
/// the samples' own table and nothing else, on purpose: every tick sends the
/// picker back to the database for each dive it holds no samples for, and an
/// edit to a dive's notes, tanks or events changes none of them.
class TripProfileWrites {
  AppDatabase get _db => DatabaseService.instance.database;

  /// Debounced like the app's other change ticks, so a download writing many
  /// dives is one tick once it goes quiet.
  Stream<void> watch() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.diveProfileSeries))
      .debounce(DiveRepository.changeTickDebounce);
}
