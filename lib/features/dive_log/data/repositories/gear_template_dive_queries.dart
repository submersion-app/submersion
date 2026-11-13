import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_visibility_queries.dart';

/// The reads behind replaying a gear template change on the dives that carry
/// it (issues #1487 and #4283): which dives carry an assembly or a set, how
/// many, and which gear each dive's diver may be given. `DiveRepository`
/// keeps the public methods, so the widget tests' fakes can override them.
class GearTemplateDiveQueries {
  final AppDatabase _db;

  const GearTemplateDiveQueries(this._db);

  /// The gear column that makes a dive carry an assembly, and the one that
  /// makes it carry a set. Fixed names, never user input.
  static const _gearColumn = 'equipment_id';
  static const _setColumn = 'via_set_id';

  /// Dives with a gear row for [assemblyId]: planned ones, and logged ones
  /// too with [alsoLogged].
  Future<List<String>> diveIdsWithAssembly(
    String assemblyId, {
    required bool alsoLogged,
  }) => _diveIdsCarrying(_gearColumn, assemblyId, alsoLogged: alsoLogged);

  /// Dives with a gear row set [setId] put there, planned ones and logged
  /// ones with [alsoLogged].
  Future<List<String>> diveIdsWithSet(
    String setId, {
    required bool alsoLogged,
  }) => _diveIdsCarrying(_setColumn, setId, alsoLogged: alsoLogged);

  /// Logged dives with a gear row set [setId] put there, the ones a member
  /// change kept as they were (issue #4500).
  // stats-scope-exempt: picks the dives that stop naming a changed set; a
  // dive left out of statistics still carries the gear
  Future<List<String>> loggedDiveIdsWithSet(String setId) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT de.dive_id AS id FROM dive_equipment de '
          'JOIN dives d ON d.id = de.dive_id '
          'WHERE de.$_setColumn = ?1 AND d.is_planned = 0',
          variables: [Variable.withString(setId)],
          readsFrom: {_db.diveEquipment, _db.dives},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// How many [planned] (or logged) dives carry [assemblyId].
  Future<int> countWithAssembly(String assemblyId, {required bool planned}) =>
      _countDivesCarrying(_gearColumn, assemblyId, planned: planned);

  /// How many [planned] (or logged) dives carry set [setId].
  Future<int> countWithSet(String setId, {required bool planned}) =>
      _countDivesCarrying(_setColumn, setId, planned: planned);

  /// Dives with a gear row whose [column] is [id]: planned ones, and logged
  /// ones too with [alsoLogged]. Every diver's, as a template is shared.
  // stats-scope-exempt: picks the dives a gear template change rewrites;
  // a dive left out of statistics still carries the gear
  Future<List<String>> _diveIdsCarrying(
    String column,
    String id, {
    required bool alsoLogged,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT de.dive_id AS id FROM dive_equipment de '
          'JOIN dives d ON d.id = de.dive_id '
          'WHERE de.$column = ?1'
          '${alsoLogged ? '' : ' AND d.is_planned = 1'}',
          variables: [Variable.withString(id)],
          readsFrom: {_db.diveEquipment, _db.dives},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  // stats-scope-exempt: counts the dives a gear template change would
  // rewrite, for the question before it; not a statistic
  Future<int> _countDivesCarrying(
    String column,
    String id, {
    required bool planned,
  }) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(DISTINCT de.dive_id) AS n FROM dive_equipment de '
          'JOIN dives d ON d.id = de.dive_id '
          'WHERE de.$column = ?1 AND d.is_planned = ?2',
          variables: [Variable.withString(id), Variable.withBool(planned)],
          readsFrom: {_db.diveEquipment, _db.dives},
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// The members set [setId] holds now.
  Future<Set<String>> membersOfSet(String setId) async {
    final rows =
        await (_db.selectOnly(_db.equipmentSetItems)
              ..addColumns([_db.equipmentSetItems.equipmentId])
              ..where(_db.equipmentSetItems.setId.equals(setId)))
            .get();
    return {for (final r in rows) r.read(_db.equipmentSetItems.equipmentId)!};
  }

  /// The diver set [setId] belongs to, null for an ownerless set.
  Future<String?> ownerOfSet(String setId) async {
    final row =
        await (_db.selectOnly(_db.equipmentSets)
              ..addColumns([_db.equipmentSets.diverId])
              ..where(_db.equipmentSets.id.equals(setId)))
            .getSingleOrNull();
    return row?.read(_db.equipmentSets.diverId);
  }

  /// The diver item [equipmentId] belongs to, null for unowned gear.
  Future<String?> ownerOfEquipment(String equipmentId) async {
    final row =
        await (_db.selectOnly(_db.equipment)
              ..addColumns([_db.equipment.diverId])
              ..where(_db.equipment.id.equals(equipmentId)))
            .getSingleOrNull();
    return row?.read(_db.equipment.diverId);
  }

  /// Whether a dive of [diveIds] may be given each of [candidates]: the
  /// filter applying a set uses for the dive's diver (`usableSetMemberIds`),
  /// so no other profile's unshared gear and nothing on the wishlist. A dive
  /// with no diver is filtered for [fallbackDiverId], as the edit page falls
  /// back to the diver it is open for; with neither it is unfiltered.
  Future<bool Function(String diveId, String equipmentId)> usableOnDives(
    List<String> diveIds,
    Set<String> candidates, {
    String? fallbackDiverId,
  }) async {
    if (diveIds.isEmpty || candidates.isEmpty) return (_, _) => true;
    final diverOf = {
      for (final MapEntry(:key, :value) in (await _diverIdsOf(diveIds)).entries)
        key: value ?? fallbackDiverId,
    };
    final visibility = EquipmentVisibilityQueries(_db);
    final ids = candidates.toList();
    final usableBy = <String, Set<String>>{
      for (final diverId in {...diverOf.values.nonNulls})
        diverId: (await visibility.usableSetMemberIds(ids, diverId)).toSet(),
    };
    return (diveId, equipmentId) {
      final usable = usableBy[diverOf[diveId]];
      return usable == null || usable.contains(equipmentId);
    };
  }

  /// Each of [diveIds]' diver, null for an unowned dive.
  Future<Map<String, String?>> _diverIdsOf(List<String> diveIds) async {
    final out = <String, String?>{};
    for (final chunk in seriesIdChunks(diveIds)) {
      final rows =
          await (_db.selectOnly(_db.dives)
                ..addColumns([_db.dives.id, _db.dives.diverId])
                ..where(_db.dives.id.isIn(chunk)))
              .get();
      for (final r in rows) {
        out[r.read(_db.dives.id)!] = r.read(_db.dives.diverId);
      }
    }
    return out;
  }
}
