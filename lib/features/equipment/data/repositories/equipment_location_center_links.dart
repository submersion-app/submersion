import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

const _linkChunkSize = 500;

/// Clears the link on every place standing for one of [centerIds] and stages
/// each place (issue #3623). The place keeps its name, kind and history. The
/// schema's SET NULL would clear the link too, but it reaches no peer. Run
/// it inside the deleting transaction, before the centers go.
Future<void> clearEquipmentLocationCenterLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Iterable<String> centerIds, {
  required int now,
}) async {
  final ids = centerIds.toSet().toList();
  final staged = <String>{};
  for (var i = 0; i < ids.length; i += _linkChunkSize) {
    final chunk = ids.sublist(i, math.min(i + _linkChunkSize, ids.length));
    final rows = await (db.select(
      db.equipmentLocations,
    )..where((t) => t.diveCenterId.isIn(chunk))).get();
    if (rows.isEmpty) continue;
    await (db.update(
      db.equipmentLocations,
    )..where((t) => t.diveCenterId.isIn(chunk))).write(
      EquipmentLocationsCompanion(
        diveCenterId: const Value(null),
        updatedAt: Value(now),
      ),
    );
    staged.addAll(rows.map((r) => r.id));
  }
  for (final id in staged) {
    await syncRepository.markRecordPending(
      entityType: 'equipmentLocations',
      recordId: id,
      localUpdatedAt: now,
    );
  }
}
