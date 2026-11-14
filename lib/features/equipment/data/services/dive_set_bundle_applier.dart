import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/domain/services/cylinder_config_applier.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_child_row_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/set_bundle_loader.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_resolver.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// What an apply changed on a dive.
typedef SetBundleApplied = ({bool weights, bool tanks});

const SetBundleApplied _nothingApplied = (weights: false, tanks: false);

/// Applies the weights and cylinders of equipment sets to a saved dive with
/// nobody watching (issue #4525): imports, bulk edit and rules. Gear is put
/// on by the callers, as before.
///
/// It goes by the state of the dive, so every call is repeatable:
/// - weights are written only on a dive that has none (no weight rows and no
///   legacy scalar weight), and then all the sets' weights go in together;
/// - a dive with no tanks takes the sets' cylinders; a dive with tanks only
///   has gaps filled, and nothing is inserted or overwritten, because a tank
///   a dive computer reported with no role would otherwise gain a twin.
///
/// Best effort: a failure is logged and reported as no change, so it never
/// fails the import or edit it rides on.
class DiveSetBundleApplier {
  DiveSetBundleApplier({
    SetBundleLoader? loader,
    DiveRepository? dives,
    DiveChildRowRepository? rows,
    EquipmentSetRepository? sets,
    CylinderConfigApplier applier = const CylinderConfigApplier(),
  }) : _loader = loader ?? SetBundleLoader(),
       _dives = dives ?? DiveRepository(),
       _rows = rows ?? DiveChildRowRepository(),
       _sets = sets ?? EquipmentSetRepository(),
       _applier = applier;

  final SetBundleLoader _loader;
  final DiveRepository _dives;
  final DiveChildRowRepository _rows;
  final EquipmentSetRepository _sets;
  final CylinderConfigApplier _applier;
  final _log = LoggerService.forClass(DiveSetBundleApplier);

  db.AppDatabase get _db => DatabaseService.instance.database;

  /// Applies what [setIds] carry to [diveId], in the order given. A set
  /// another of them includes is absorbed into it, so its lead and
  /// cylinders count once.
  Future<SetBundleApplied> apply({
    required String diveId,
    required List<String> setIds,
    bool notify = true,
  }) async =>
      (await applyToDives(
        diveIds: [diveId],
        setIds: setIds,
        notify: notify,
      ))[diveId] ??
      _nothingApplied;

  /// [apply] for each of [diveIds], reading the bundles once: a bulk edit
  /// or a rule run puts the same sets on every dive. A dive that fails is
  /// logged and reported as unchanged; the others still apply.
  Future<Map<String, SetBundleApplied>> applyToDives({
    required List<String> diveIds,
    required List<String> setIds,
    bool notify = true,
  }) async {
    final applied = <String, SetBundleApplied>{};
    if (setIds.isEmpty || diveIds.isEmpty) return applied;
    if (DatabaseService.instance.databaseOrNull == null) return applied;
    final List<WeightEntryDraft> weights;
    final List<CylinderConfigItem> cylinders;
    try {
      final bundles = await _loader.load(setIds);
      weights = [for (final b in bundles) ...b.weights];
      cylinders = _renumbered([for (final b in bundles) ...b.cylinders]);
    } catch (e, stackTrace) {
      _log.warning(
        'Reading what sets $setIds carry failed',
        error: e,
        stackTrace: stackTrace,
      );
      return applied;
    }
    if (weights.isEmpty && cylinders.isEmpty) return applied;

    var changed = false;
    for (final diveId in diveIds) {
      try {
        final result = await _db.transaction(() async {
          final wroteWeights = await _fillWeights(diveId, weights);
          final wroteTanks = await _mergeCylinders(diveId, cylinders);
          return (weights: wroteWeights, tanks: wroteTanks);
        });
        applied[diveId] = result;
        changed = changed || result.weights || result.tanks;
      } catch (e, stackTrace) {
        _log.warning(
          'Applying set weights and tanks to dive $diveId failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    if (notify && changed) SyncEventBus.notifyLocalChange();
    return applied;
  }

  /// [apply] for the sets whose gear the dive carries: [leadSetId] first
  /// (the default or location set, which may have no gear and so no tag),
  /// then [alsoSetIds] in the order given (sets that landed without
  /// leaving a tag, because their gear was already on the dive under
  /// another set's), then the tagged sets by name.
  ///
  /// With [retagAbsorbed], gear tagged with a set that another of them
  /// includes takes the outer set's tag, so a dive just created shows one
  /// set. Left off for a dive that already existed: its tags are history.
  Future<SetBundleApplied> applyTagged({
    required String diveId,
    String? leadSetId,
    List<String> alsoSetIds = const [],
    bool retagAbsorbed = false,
    bool notify = true,
  }) async {
    if (DatabaseService.instance.databaseOrNull == null) return _nothingApplied;
    try {
      final tagged = await _db
          .customSelect(
            'SELECT DISTINCT s.id AS id, s.name AS name '
            'FROM dive_equipment de JOIN equipment_sets s '
            'ON s.id = de.via_set_id WHERE de.dive_id = ? '
            'ORDER BY s.name COLLATE NOCASE, s.id',
            variables: [Variable<String>(diveId)],
            readsFrom: {_db.diveEquipment, _db.equipmentSets},
          )
          .get();
      final setIds = <String>{
        ?leadSetId,
        ...alsoSetIds,
        for (final row in tagged) row.read<String>('id'),
      }.toList();
      if (setIds.isEmpty) return _nothingApplied;
      if (retagAbsorbed) await _retagAbsorbed(diveId, setIds);
      return await apply(diveId: diveId, setIds: setIds, notify: notify);
    } catch (e, stackTrace) {
      _log.warning(
        'Applying the sets on dive $diveId failed',
        error: e,
        stackTrace: stackTrace,
      );
      return _nothingApplied;
    }
  }

  /// When a dive's set is swapped for another (a location match replacing
  /// the default), swaps the weights too, but only if they are still
  /// exactly what [fromSetId] filled in. An empty new bundle removes them.
  /// False when the dive's weights were left alone.
  Future<bool> swapWeights({
    required String diveId,
    required String fromSetId,
    required String toSetId,
  }) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final from = await _loader.loadOne(fromSetId);
      if (from == null || from.weights.isEmpty) return false;
      final onDive = await _weightsOf(diveId);
      if (!SetBundleResolver.sameWeights(
        _sorted(onDive),
        _sortedDrafts(from.weights),
      )) {
        return false;
      }
      final to = await _loader.loadOne(toSetId);
      await _db.transaction(
        () => _dives.bulkReplaceWeights([
          diveId,
        ], to?.toDiveWeights(diveId: diveId, newId: () => '') ?? const []),
      );
      return true;
    } catch (e, stackTrace) {
      _log.warning(
        'Swapping set weights on dive $diveId failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static List<CylinderConfigItem> _renumbered(List<CylinderConfigItem> items) =>
      [for (final (i, item) in items.indexed) item.copyWith(sortOrder: i)];

  Future<bool> _fillWeights(
    String diveId,
    List<WeightEntryDraft> weights,
  ) async {
    if (weights.isEmpty) return false;
    final dive = await (_db.select(
      _db.dives,
    )..where((d) => d.id.equals(diveId))).getSingleOrNull();
    if (dive == null) return false;
    // The legacy scalar is how older dives record their lead.
    if ((dive.weightAmount ?? 0) > 0) return false;
    if ((await _weightsOf(diveId)).isNotEmpty) return false;
    await _dives.bulkAddWeights(
      [diveId],
      [
        for (final w in weights)
          DiveWeight(
            id: '',
            diveId: diveId,
            weightType: w.weightType,
            amountKg: w.amountKg,
            notes: w.notes,
            label: w.label,
          ),
      ],
    );
    return true;
  }

  Future<bool> _mergeCylinders(
    String diveId,
    List<CylinderConfigItem> cylinders,
  ) async {
    if (cylinders.isEmpty) return false;
    final rows =
        await (_db.select(_db.diveTanks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
            .get();
    final plan = _applier.plan(
      existing: [for (final row in rows) _existing(row)],
      items: cylinders,
    );
    var changed = false;
    if (rows.isEmpty) {
      for (final op in plan.ops.whereType<InsertTank>()) {
        await _rows.addTank(diveId, _insert(op));
        changed = true;
      }
      return changed;
    }
    // A fill meant for a tank whose role the configuration would change
    // would put one cylinder's size on another, and one meant for a tank
    // whose known size, pressure or material contradicts the cylinder would
    // give a different cylinder this one's name and material. Either change
    // needs a person.
    final notThisCylinder = {
      for (final o in plan.overwrites)
        if (o.role != null || o.changesCylinder) o.tankId,
    };
    for (final op in plan.ops.whereType<FillTank>()) {
      if (op.isEmpty || notThisCylinder.contains(op.tankId)) continue;
      await _rows.updateTank(
        op.tankId,
        db.DiveTanksCompanion(
          volume: op.volumeL == null ? const Value.absent() : Value(op.volumeL),
          workingPressure: op.workingPressureBar == null
              ? const Value.absent()
              : Value(op.workingPressureBar),
          tankMaterial: op.tankMaterial == null
              ? const Value.absent()
              : Value(op.tankMaterial!.name),
          startPressure: op.startPressureBar == null
              ? const Value.absent()
              : Value(op.startPressureBar),
          tankName: op.tankName == null
              ? const Value.absent()
              : Value(op.tankName),
          roleSource: op.clearRoleSource
              ? const Value(null)
              : const Value.absent(),
        ),
      );
      changed = true;
    }
    return changed;
  }

  static ExistingTank _existing(db.DiveTank row) => ExistingTank(
    id: row.id,
    tankRole: TankRole.values.asNameMap()[row.tankRole] ?? TankRole.backGas,
    roleSource: TankRoleSource.values.asNameMap()[row.roleSource],
    volumeL: row.volume,
    workingPressureBar: row.workingPressure,
    tankMaterial: TankMaterial.values.asNameMap()[row.tankMaterial],
    startPressureBar: row.startPressure,
    tankName: row.tankName,
    tankOrder: row.tankOrder,
    o2Percent: row.o2Percent,
    hePercent: row.hePercent,
  );

  static db.DiveTanksCompanion _insert(InsertTank op) {
    final item = op.item;
    return db.DiveTanksCompanion(
      volume: Value(item.volumeL),
      workingPressure: Value(item.workingPressureBar),
      startPressure: Value(item.defaultStartPressureBar),
      o2Percent: Value(item.o2Percent),
      hePercent: Value(item.hePercent),
      tankOrder: Value(op.tankOrder),
      tankRole: Value(item.tankRole.name),
      tankMaterial: Value(item.tankMaterial?.name),
      tankName: Value(item.label),
    );
  }

  /// The dive's weight rows in the order they were written.
  Future<List<DiveWeight>> _weightsOf(String diveId) async {
    final rows =
        await (_db.select(_db.diveWeights)
              ..where((w) => w.diveId.equals(diveId))
              ..orderBy([(w) => OrderingTerm.asc(w.rowId)]))
            .get();
    return [
      for (final row in rows)
        DiveWeight(
          id: row.id,
          diveId: row.diveId,
          weightType:
              WeightType.values.asNameMap()[row.weightType] ?? WeightType.belt,
          amountKg: row.amountKg,
          notes: row.notes,
          label: row.label,
        ),
    ];
  }

  // The swap compares what is on the dive with what a set would fill in
  // whatever order the rows come back, so both sides sort the same way.
  static String _key(WeightType type, String label, String notes, double kg) =>
      '${type.name}|$label|$notes|${kg.toStringAsFixed(6)}';

  static List<DiveWeight> _sorted(List<DiveWeight> weights) =>
      [...weights]..sort(
        (a, b) => _key(
          a.weightType,
          a.label,
          a.notes,
          a.amountKg,
        ).compareTo(_key(b.weightType, b.label, b.notes, b.amountKg)),
      );

  static List<WeightEntryDraft> _sortedDrafts(List<WeightEntryDraft> drafts) =>
      [...drafts]..sort(
        (a, b) => _key(
          a.weightType,
          a.label,
          a.notes,
          a.amountKg,
        ).compareTo(_key(b.weightType, b.label, b.notes, b.amountKg)),
      );

  /// Moves the tags of sets that another of [setIds] includes to that outer
  /// set.
  Future<void> _retagAbsorbed(String diveId, List<String> setIds) async {
    final sets = await _sets.getAllSets(ids: setIds);
    // Only a set that stands may take another's gear: of two sets that
    // include each other, the resolver keeps one.
    final standing = {for (final s in SetBundleResolver.absorb(sets)) s.id};
    final outerOf = <String, String>{
      for (final set in sets)
        if (standing.contains(set.id))
          for (final included in set.includedSetIds)
            if (included != set.id && setIds.contains(included))
              included: set.id,
    };
    if (outerOf.isEmpty) return;
    final rows = await (_db.select(
      _db.diveEquipment,
    )..where((r) => r.diveId.equals(diveId))).get();
    if (!rows.any((r) => outerOf.containsKey(r.viaSetId))) return;
    await _db.transaction(
      () => _dives.replaceGearRows(diveId, [
        for (final row in rows)
          GearProvenance(
            equipmentId: row.equipmentId,
            viaEquipmentId: row.viaEquipmentId,
            viaSetId: outerOf[row.viaSetId] ?? row.viaSetId,
          ),
      ]),
    );
  }
}
