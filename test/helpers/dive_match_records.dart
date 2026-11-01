import 'package:submersion/features/dive_import/domain/models/dive_match_record.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// What duplicate matching would read of [dive] from the database.
DiveMatchRecord diveMatchRecordOf(Dive dive) => DiveMatchRecord(
  id: dive.id,
  dateTime: dive.dateTime,
  maxDepth: dive.maxDepth,
  runtime: dive.runtime,
  entryTime: dive.entryTime,
  exitTime: dive.exitTime,
  bottomTime: dive.bottomTime,
  siteName: dive.site?.name,
);
