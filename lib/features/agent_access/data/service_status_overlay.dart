import 'dart:convert';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/equipment/data/services/loaded_service_clocks.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart'
    show serviceStatusTable;
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The verdicts `serviceDue` and `nextServiceDue` read, for any diver.
///
/// The cache table those fields compile against holds the active diver's
/// verdicts only, and a read tool must not write it. This evaluates the named
/// diver's clocks and returns them as a CTE named after the cache, so the
/// compiled query reads them unchanged. Each row is the verdict the cache
/// writer would pick: the worst clock, which the engine lists first. Retired
/// gear and gear with no clock have no row and read as ok, as they do from
/// the cache. One bound JSON parameter, so neither the row count nor an empty
/// list changes the statement.
Future<QueryCte> serviceStatusOverlay({
  required String diverId,
  required AppSettings settings,
  required RecordRepositories repositories,
  required DateTime now,
}) async {
  final items = await repositories.equipment.getActiveEquipment(
    diverId: diverId,
  );
  // Every kind, not only this diver's: a shared item's schedule can use its
  // owner's custom kind, and the engine drops a schedule whose kind is missing.
  final kinds = await repositories.serviceKinds.getAllKinds();
  final evaluated = await evaluateServiceClocksForItems(
    items,
    kindsById: {for (final k in kinds) k.id: k},
    settings: settings,
    schedules: repositories.serviceSchedules,
    records: repositories.serviceRecords,
    equipment: repositories.equipment,
    now: now,
  );
  final rows = [
    for (final MapEntry(key: id, value: statuses) in evaluated.entries)
      if (statuses.isNotEmpty)
        [
          id,
          statuses.first.severity.name,
          statuses.first.dueDate?.millisecondsSinceEpoch,
        ],
  ];
  return (
    sql:
        'WITH $serviceStatusTable(equipment_id, severity, due_date) AS ('
        "SELECT json_extract(value, '\$[0]'), json_extract(value, '\$[1]'), "
        "json_extract(value, '\$[2]') FROM json_each(?))",
    params: [jsonEncode(rows)],
  );
}
