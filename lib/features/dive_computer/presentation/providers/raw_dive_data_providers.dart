import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_computer/data/services/raw_dive_data_service.dart';

final rawDiveDataServiceProvider = Provider<RawDiveDataService>((ref) {
  return RawDiveDataService(db: DatabaseService.instance.database);
});

/// Raw dive computer data held across every computer, refreshed whenever a
/// download, import, reparse, sync or discard writes a data source row.
final rawDiveDataUsageProvider = FutureProvider<RawDiveDataUsage>((ref) {
  final service = ref.watch(rawDiveDataServiceProvider);
  ref.invalidateSelfWhen(
    service.db.tableUpdates(
      TableUpdateQuery.onTable(service.db.diveDataSources),
    ),
  );
  return service.getUsage();
});
