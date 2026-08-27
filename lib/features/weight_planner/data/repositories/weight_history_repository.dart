import 'package:drift/drift.dart';

import 'package:submersion/core/buoyancy/weight_observation.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/services/equipment_lead.dart';

/// Assembles weight-prediction training rows from the dive log.
///
/// Six batch queries (dives, dive_weights, dive_equipment, dive_tanks, and
/// equipment + equipment_attributes for gear-carried lead) -- no per-dive
/// N+1. Only dives that recorded any weight qualify.
class WeightHistoryRepository {
  WeightHistoryRepository([AppDatabase? db]) : _dbOverride = db;

  final AppDatabase? _dbOverride;
  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  /// Emits when the gear side of an observation's carried lead changes.
  ///
  /// Since #1103 an observation's `carriedKg` also comes from weights-type
  /// equipment, whose mass lives in `equipment_attributes`. `saveAttributes`
  /// writes that table alone, so watching `equipment` would miss an
  /// attribute-only write (a sync apply, for instance) entirely; both tables
  /// are needed. Dives-table changes are watched separately by the caller.
  Stream<void> watchGearLeadChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([_db.equipment, _db.equipmentAttributes]),
  );

  /// All dives of [diverId] that recorded any weight, ordered oldest-first.
  Future<List<WeightObservation>> observationsForDiver(String diverId) async {
    final diveRows =
        await (_db.select(_db.dives)
              ..where((d) => d.diverId.equals(diverId))
              ..orderBy([(d) => OrderingTerm.asc(d.diveDateTime)]))
            .get();
    if (diveRows.isEmpty) return const [];

    final diveIds = diveRows.map((d) => d.id).toList();

    final weightRows = await (_db.select(
      _db.diveWeights,
    )..where((w) => w.diveId.isIn(diveIds))).get();
    final equipmentRows = await (_db.select(
      _db.diveEquipment,
    )..where((e) => e.diveId.isIn(diveIds))).get();
    final tankRows = await (_db.select(
      _db.diveTanks,
    )..where((t) => t.diveId.isIn(diveIds))).get();

    final weightsByDive = <String, List<DiveWeight>>{};
    for (final row in weightRows) {
      weightsByDive.putIfAbsent(row.diveId, () => []).add(row);
    }
    final equipmentByDive = <String, List<String>>{};
    for (final row in equipmentRows) {
      equipmentByDive.putIfAbsent(row.diveId, () => []).add(row.equipmentId);
    }
    final leadByEquipment = await _gearCarriedLead(
      equipmentRows.map((e) => e.equipmentId).toSet(),
    );
    final tanksByDive = <String, List<ObservedTank>>{};
    for (final row in tankRows) {
      tanksByDive
          .putIfAbsent(row.diveId, () => [])
          .add(
            ObservedTank(
              volumeL: row.volume,
              workingPressureBar: row.workingPressure,
              material: row.tankMaterial != null
                  ? TankMaterial.values.firstWhere(
                      (m) => m.name == row.tankMaterial,
                      orElse: () => TankMaterial.aluminum,
                    )
                  : null,
              presetName: row.presetName,
            ),
          );
    }

    final observations = <WeightObservation>[];
    for (final dive in diveRows) {
      final typedWeights = weightsByDive[dive.id] ?? const [];
      final placement = <String, double>{};
      var carried = 0.0;
      for (final w in typedWeights) {
        carried += w.amountKg;
        placement.update(
          w.weightType,
          (v) => v + w.amountKg,
          ifAbsent: () => w.amountKg,
        );
      }
      if (typedWeights.isEmpty) {
        carried = dive.weightAmount ?? 0.0;
      }
      // Ballast built into the rig (weighted plates, weighted STAs, bolt-on
      // trim) is lead the diver carried even when the Weights section is
      // empty. Without it these dives failed the `carried <= 0` gate below
      // and never became training rows at all (issue #1103).
      for (final equipmentId in equipmentByDive[dive.id] ?? const <String>[]) {
        final gear = leadByEquipment[equipmentId];
        if (gear == null) continue;
        carried += gear.kg;
        final placedAs = gear.placement?.name;
        if (placedAs != null) {
          placement.update(
            placedAs,
            (v) => v + gear.kg,
            ifAbsent: () => gear.kg,
          );
        }
      }
      if (carried <= 0) continue;

      observations.add(
        WeightObservation(
          diveId: dive.id,
          diveDateTime: DateTime.fromMillisecondsSinceEpoch(dive.diveDateTime),
          waterType: dive.waterType != null
              ? WaterType.values.firstWhere(
                  (w) => w.name == dive.waterType,
                  orElse: () => WaterType.salt,
                )
              : null,
          carriedKg: carried,
          placement: placement,
          equipmentIds: equipmentByDive[dive.id] ?? const [],
          tanks: tanksByDive[dive.id] ?? const [],
          feedback: dive.weightingFeedback,
          feedbackKg: dive.weightingFeedbackKg,
        ),
      );
    }
    return observations;
  }

  /// Ballast and placement for every [EquipmentType.weights] item among
  /// [equipmentIds], keyed by equipment id. Items that declare no usable mass
  /// are omitted, so a weights item with no numbers changes nothing.
  ///
  /// Two more batch queries (equipment, equipment_attributes), keeping the
  /// no-N+1 property of the caller.
  Future<Map<String, _GearLead>> _gearCarriedLead(
    Set<String> equipmentIds,
  ) async {
    if (equipmentIds.isEmpty) return const {};
    final ids = equipmentIds.toList();

    final gearRows =
        await (_db.select(_db.equipment)..where(
              (e) => e.id.isIn(ids) & e.type.equals(EquipmentType.weights.name),
            ))
            .get();
    if (gearRows.isEmpty) return const {};

    final weightsIds = gearRows.map((e) => e.id).toList();
    final attrRows =
        await (_db.select(_db.equipmentAttributes)..where(
              (a) => a.equipmentId.isIn(weightsIds) & a.isCustom.equals(false),
            ))
            .get();

    final attrsByEquipment = <String, Map<String, EquipmentAttributeRow>>{};
    for (final row in attrRows) {
      attrsByEquipment
          .putIfAbsent(row.equipmentId, () => {})
          .putIfAbsent(row.attrKey, () => row);
    }

    final result = <String, _GearLead>{};
    for (final gear in gearRows) {
      final attrs = attrsByEquipment[gear.id] ?? const {};
      final kg = EquipmentLead.ballastKg(
        dryWeightKg: attrs[EquipmentAttrKeys.dryWeightKg]?.valueNum,
        buoyancyKg: attrs[EquipmentAttrKeys.buoyancyKg]?.valueNum,
      );
      if (kg <= 0) continue;
      result[gear.id] = _GearLead(
        kg: kg,
        placement: EquipmentLead.placementFor(
          attrs[EquipmentAttrKeys.weightStyle]?.valueText,
        ),
      );
    }
    return result;
  }
}

/// One weights item's contribution to a dive's carried lead.
class _GearLead {
  final double kg;
  final WeightType? placement;
  const _GearLead({required this.kg, required this.placement});
}
