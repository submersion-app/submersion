import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_child_row_repository.dart';

/// The weights and cylinders a rule's "add equipment set" action wrote on a
/// dive (issue #4525): how a run records them and how undo takes them back.
///
/// Recorded like every other rule change, as a before and an after list
/// under the field names below. Undo restores `before` only while the dive
/// is still exactly as the run left it, as the other fields do.
class RuleSetBundleChanges {
  RuleSetBundleChanges(this._db)
    : _rows = DiveChildRowRepository(database: _db);

  /// The `field` of a recorded change to a dive's weights.
  static const weightsField = 'weights';

  /// The `field` of a recorded change to a dive's tanks.
  static const tanksField = 'tanks';

  static const _same = DeepCollectionEquality();

  final AppDatabase _db;
  final DiveChildRowRepository _rows;

  /// Each dive's weights as recorded values, oldest row first. A dive with
  /// none maps to an empty list.
  Future<Map<String, List<Map<String, Object?>>>> weights(
    List<String> diveIds,
  ) async {
    final byDive = {for (final id in diveIds) id: <Map<String, Object?>>[]};
    if (diveIds.isEmpty) return byDive;
    final rows =
        await (_db.select(_db.diveWeights)
              ..where((w) => w.diveId.isIn(diveIds))
              ..orderBy([(w) => OrderingTerm.asc(w.rowId)]))
            .get();
    for (final r in rows) {
      byDive[r.diveId]!.add({
        'id': r.id,
        'type': r.weightType,
        'kg': r.amountKg,
        'label': r.label,
        'notes': r.notes,
      });
    }
    return byDive;
  }

  /// Each dive's tanks as recorded values, in tank order: the columns a
  /// set's cylinders can write.
  Future<Map<String, List<Map<String, Object?>>>> tanks(
    List<String> diveIds,
  ) async {
    final byDive = {for (final id in diveIds) id: <Map<String, Object?>>[]};
    if (diveIds.isEmpty) return byDive;
    final rows =
        await (_db.select(_db.diveTanks)
              ..where((t) => t.diveId.isIn(diveIds))
              ..orderBy([
                (t) => OrderingTerm.asc(t.tankOrder),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    for (final r in rows) {
      byDive[r.diveId]!.add({
        'id': r.id,
        'role': r.tankRole,
        'roleSource': r.roleSource,
        'volume': r.volume,
        'pressure': r.workingPressure,
        'material': r.tankMaterial,
        'start': r.startPressure,
        'name': r.tankName,
        'o2': r.o2Percent,
        'he': r.hePercent,
        'order': r.tankOrder,
      });
    }
    return byDive;
  }

  /// Takes back the weights a run wrote on [diveId]. False when they are no
  /// longer as the run left them, and nothing is touched.
  Future<bool> undoWeights(String diveId, Object? before, Object? after) async {
    final current = (await weights([diveId]))[diveId]!;
    if (!_same.equals(current, _list(after))) return false;
    final keep = {for (final w in _list(before)) w['id']};
    for (final w in current) {
      if (!keep.contains(w['id'])) await _rows.deleteWeight(w['id']! as String);
    }
    return true;
  }

  /// Takes back the cylinders a run inserted on [diveId] and the gaps it
  /// filled. False when the tanks are no longer as the run left them.
  Future<bool> undoTanks(String diveId, Object? before, Object? after) async {
    final current = (await tanks([diveId]))[diveId]!;
    if (!_same.equals(current, _list(after))) return false;
    final was = {for (final t in _list(before)) t['id']: t};
    for (final tank in current) {
      final id = tank['id']! as String;
      final prior = was[id];
      if (prior == null) {
        await _rows.deleteTank(id);
      } else if (!_same.equals(prior, tank)) {
        await _rows.updateTank(
          id,
          DiveTanksCompanion(
            volume: Value(_num(prior['volume'])),
            workingPressure: Value(_num(prior['pressure'])),
            tankMaterial: Value(prior['material'] as String?),
            startPressure: Value(_num(prior['start'])),
            tankName: Value(prior['name'] as String?),
            roleSource: Value(prior['roleSource'] as String?),
          ),
        );
      }
    }
    return true;
  }

  static double? _num(Object? value) => (value as num?)?.toDouble();

  static List<Map<String, Object?>> _list(Object? recorded) => [
    for (final entry in (recorded as List?) ?? const [])
      Map<String, Object?>.from(entry as Map),
  ];
}
