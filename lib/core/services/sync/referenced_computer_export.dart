import 'package:collection/collection.dart' show IterableExtension;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/device_local_fields.dart';

/// Ids per query when fetching referenced computers, well below SQLite's
/// bound-variable limit.
const _chunk = 500;

/// Every synced table with a foreign key to `dive_computers`: its sync entity
/// type, its table, and the JSON key its rows name the computer by. A schema
/// test fails when a table gains a computer link this list lacks, and
/// [withReferencedComputers] asserts the serializer passes each one.
const computerReferences = <({String entity, String table, String key})>[
  (entity: 'dives', table: 'dives', key: 'computerId'),
  (entity: 'diveDataSources', table: 'dive_data_sources', key: 'computerId'),
  (entity: 'diveTanks', table: 'dive_tanks', key: 'computerId'),
  (entity: 'qualityFindings', table: 'quality_findings', key: 'computerId'),
  (entity: 'transmitters', table: 'transmitters', key: 'diveComputerId'),
  (
    entity: 'diveProfileEvents',
    table: 'dive_profile_events',
    key: 'computerId',
  ),
  (entity: 'gasSwitches', table: 'gas_switches', key: 'computerId'),
  (
    entity: 'diveComputerConnections',
    table: 'dive_computer_connections',
    key: 'computerId',
  ),
  (
    entity: 'diveProfileSeries',
    table: 'dive_profile_series',
    key: 'computerId',
  ),
  (
    entity: 'tankPressureSeries',
    table: 'tank_pressure_series',
    key: 'computerId',
  ),
];

/// [exported] plus every computer a row in [referencing] (exported rows by
/// entity type, one entry per [computerReferences] entity) points at, for an
/// incremental changeset (issue #4368). A peer that applies a row without
/// the computer it names has its foreign-key repair clear the link for good,
/// and a computer older than the watermark, or one an earlier apply on the
/// peer failed to keep, is otherwise not sent again until its own clock
/// moves. Resending an unchanged computer is a no-op on the peer. A base
/// ([hlcSince] null) already carries every computer.
Future<List<Map<String, dynamic>>> withReferencedComputers(
  AppDatabase db,
  List<Map<String, dynamic>> exported, {
  required String? hlcSince,
  required Map<String, List<Map<String, dynamic>>> referencing,
}) async {
  assert(
    computerReferences.every((r) => referencing.containsKey(r.entity)),
    'every entity in computerReferences must be passed',
  );
  if (hlcSince == null) return exported;
  final have = {for (final row in exported) row['id']};
  final missing = {
    for (final (:entity, table: _, :key) in computerReferences)
      for (final row in referencing[entity] ?? const <Map<String, dynamic>>[])
        if (row[key] case final String id when !have.contains(id)) id,
  }.toList();
  if (missing.isEmpty) return exported;
  return [
    ...exported,
    for (final chunk in missing.slices(_chunk))
      for (final row in await (db.select(
        db.diveComputers,
      )..where((t) => t.id.isIn(chunk))).get())
        withoutDeviceLocalColumns('diveComputers', row.toJson()),
  ];
}
