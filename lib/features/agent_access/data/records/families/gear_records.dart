import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/documents/gear_documents.dart';
import 'package:submersion/features/agent_access/data/documents/media_document.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_share.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

final _equipmentScope = rootScope(QuerySubject.equipment);
final _viaEquipment = viaParent('equipment', 'equipment_id', _equipmentScope);

/// As `CylinderFillRepository.getAllVisibleTo`: a fill follows its cylinder,
/// and one on no cylinder belongs to whoever logged it.
QueryScope _fillScope(String diverId, String alias) {
  final visible = VisibilityFilter.equipmentSqlFragment(
    tableAlias: '${alias}e',
    diverId: diverId,
    conjunction: 'WHERE',
  );
  return (
    sql:
        '($alias.equipment_id IN (SELECT ${alias}e.id FROM equipment '
        '${alias}e${visible.whereClause}) OR ($alias.equipment_id IS NULL '
        'AND $alias.diver_id = ?))',
    params: [for (final v in visible.variables) v.value as Object, diverId],
  );
}

/// Gear and everything recorded against it.
List<RecordEntry> gearEntries(RecordRepositories r) => [
  RecordEntity<EquipmentItem>(
    name: 'equipment',
    table: 'equipment',
    scope: _equipmentScope,
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) async =>
        byId(await r.equipment.getEquipmentByIds(ids), (e) => e.id),
    document: equipmentDocument,
    summaryKeys: const ['name', 'type', 'brand', 'model', 'status'],
    blocks: {
      'service_records': (item, _) async => [
        for (final s in await r.serviceRecords.getRecordsForEquipment(item.id))
          serviceRecordDocument(s),
      ],
      'service_schedules': (item, _) async => [
        for (final s in await r.serviceSchedules.getSchedulesForEquipment(
          item.id,
        ))
          serviceScheduleDocument(s),
      ],
      'components': (item, _) async => [
        for (final c in await r.equipmentComponents.getComponents(item.id))
          equipmentComponentDocument(c),
      ],
      'shares': (item, _) async => [
        for (final s in await r.equipmentShares.getSharesFor(item.id))
          equipmentShareDocument(s),
      ],
      'tags': (item, _) async => [
        for (final t in await r.equipmentTags.getTagsForEquipment(item.id))
          t.name,
      ],
      'media': (item, _) async => [
        for (final m in await r.media.getMediaForEquipment(item.id))
          mediaDocument(m),
      ],
      'location_moves': (item, _) async => [
        for (final m in await r.equipmentLocationMoves.getMovesFor(item.id))
          equipmentLocationMoveDocument(m),
      ],
      'observations': (item, _) async => [
        for (final o in await r.equipmentObservations.getForEquipment(item.id))
          equipmentObservationDocument(o),
      ],
      'fills': (item, load) async => [
        for (final f in await r.cylinderFills.getAllVisibleTo(load.diverId))
          if (f.equipmentId == item.id) cylinderFillDocument(f),
      ],
      'transmitters': (item, _) async => [
        for (final x in await r.transmitters.getForEquipment(item.id))
          transmitterDocument(x),
      ],
    },
  ),
  RecordEntity<ServiceRecord>(
    name: 'service_records',
    table: 'service_records',
    scope: _viaEquipment,
    parentColumn: 'equipment_id',
    orderBy: 'r0.equipment_id, r0.service_date DESC',
    load: (ids, _) => loadEach(ids, r.serviceRecords.getRecordById),
    document: serviceRecordDocument,
    summaryKeys: const ['equipment_id', 'category', 'service_date', 'provider'],
  ),
  RecordEntity<ServiceSchedule>(
    name: 'service_schedules',
    table: 'service_schedules',
    scope: _viaEquipment,
    parentColumn: 'equipment_id',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'service_schedules',
      parentColumn: 'equipment_id',
      ids: ids,
      idOf: (s) => s.id,
      byParents: r.serviceSchedules.getSchedulesForEquipmentIds,
    ),
    document: serviceScheduleDocument,
    summaryKeys: const [
      'equipment_id',
      'service_kind_id',
      'interval_days',
      'enabled',
    ],
  ),
  RecordEntity<ServiceKind>(
    name: 'service_kinds',
    table: 'service_kinds',
    scope: ownedNullOrBuiltIn(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.serviceKinds.getKindById),
    document: serviceKindDocument,
    summaryKeys: const ['name', 'is_built_in', 'default_interval_days'],
  ),
  RecordEntity<EquipmentComponent>(
    name: 'equipment_components',
    table: 'equipment_components',
    scope: viaParent('equipment', 'parent_equipment_id', _equipmentScope),
    parentColumn: 'parent_equipment_id',
    orderBy: 'r0.parent_equipment_id, r0.sort_order',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'equipment_components',
      parentColumn: 'parent_equipment_id',
      ids: ids,
      idOf: (c) => c.id,
      byParents: (parents) async => {
        for (final id in parents)
          id: await r.equipmentComponents.getComponents(id),
      },
    ),
    document: equipmentComponentDocument,
    summaryKeys: const [
      'parent_equipment_id',
      'component_equipment_id',
      'role',
    ],
  ),
  RecordEntity<EquipmentShare>(
    name: 'equipment_shares',
    table: 'equipment_shares',
    scope: _viaEquipment,
    parentColumn: 'equipment_id',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'equipment_shares',
      parentColumn: 'equipment_id',
      ids: ids,
      idOf: (s) => s.id,
      byParents: r.equipmentShares.getSharesForItems,
    ),
    document: equipmentShareDocument,
    summaryKeys: const ['equipment_id', 'diver_id'],
  ),
  RecordEntity<EquipmentLocationMove>(
    name: 'equipment_location_moves',
    table: 'equipment_location_moves',
    scope: _viaEquipment,
    parentColumn: 'equipment_id',
    orderBy: 'r0.equipment_id, r0.moved_at DESC',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'equipment_location_moves',
      parentColumn: 'equipment_id',
      ids: ids,
      idOf: (m) => m.id,
      byParents: (parents) async => {
        for (final id in parents)
          id: await r.equipmentLocationMoves.getMovesFor(id),
      },
    ),
    document: equipmentLocationMoveDocument,
    summaryKeys: const ['equipment_id', 'location_id', 'moved_at'],
  ),
  RecordEntity<EquipmentObservation>(
    name: 'equipment_observations',
    table: 'equipment_observations',
    scope: _viaEquipment,
    parentColumn: 'equipment_id',
    orderBy: 'r0.equipment_id, r0.observed_at DESC',
    load: (ids, _) => loadEach(ids, r.equipmentObservations.getById),
    document: equipmentObservationDocument,
    summaryKeys: const ['equipment_id', 'dive_id', 'observed_at', 'status'],
  ),
  RecordEntity<CylinderFill>(
    name: 'cylinder_fills',
    table: 'cylinder_fills',
    scope: _fillScope,
    parentColumn: 'equipment_id',
    orderBy: 'r0.filled_at DESC',
    load: (ids, _) => loadEach(ids, r.cylinderFills.getById),
    document: cylinderFillDocument,
    summaryKeys: const ['equipment_id', 'filled_at', 'o2_fraction'],
  ),
  RecordEntity<EquipmentSet>(
    name: 'equipment_sets',
    table: 'equipment_sets',
    scope: owned(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.equipmentSets.getSetById),
    document: equipmentSetDocument,
    summaryKeys: const ['name', 'description', 'is_default'],
    blocks: {
      'items': (set, _) async => [
        for (final e in await r.equipment.getEquipmentByIds(set.equipmentIds))
          equipmentDocument(e),
      ],
      'geofences': (set, _) async => [
        for (final g in await r.equipmentSets.getGeofencesForSet(set.id))
          equipmentSetGeofenceDocument(g),
      ],
    },
  ),
  RecordEntity<EquipmentLocation>(
    name: 'equipment_locations',
    table: 'equipment_locations',
    scope: ownedOrNull(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.equipmentLocations.getLocation),
    document: equipmentLocationDocument,
    summaryKeys: const ['name', 'kind', 'is_archived'],
  ),
  RecordEntity<Transmitter>(
    name: 'transmitters',
    table: 'transmitters',
    scope: owned(),
    orderBy: 'r0.label COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.transmitters.getById),
    document: transmitterDocument,
    summaryKeys: const ['label', 'transmitter_serial', 'role'],
  ),
  RecordEntity<CylinderConfig>(
    name: 'cylinder_configs',
    table: 'cylinder_configs',
    scope: owned(),
    orderBy: 'r0.sort_order, r0.name',
    load: (ids, load) => loadEach(
      ids,
      (id) => r.cylinderConfigs.getConfigById(
        id,
        includeItems: load.include.contains('items'),
      ),
    ),
    document: cylinderConfigDocument,
    summaryKeys: const ['name', 'description'],
    blocks: {
      'items': (config, _) async => [
        for (final i in config.items) cylinderConfigItemDocument(i),
      ],
    },
  ),
];
