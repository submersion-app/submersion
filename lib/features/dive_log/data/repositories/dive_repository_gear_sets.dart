part of 'dive_repository_impl.dart';

/// Whole equipment sets on many dives at once (#4284), for logbook rules and
/// bulk edit. Gear a set brings carries the set's id, as on the dive edit
/// page, so a set can later be taken off by what it brought.
extension DiveGearSets on DiveRepository {
  /// Each set's equipment ids, in [setIds] order. A set that has gone, or
  /// has no items, gives none. A member on the wishlist stays in the set but
  /// never goes on a dive (#2025), as the set picker leaves it out too.
  Future<List<({String setId, List<String> equipmentIds})>> _setItems(
    List<String> setIds,
  ) async {
    if (setIds.isEmpty) return const [];
    final items = _db.equipmentSetItems;
    final gear = _db.equipment;
    final rows =
        await (_db.select(items).join([
                innerJoin(gear, gear.id.equalsExp(items.equipmentId)),
              ])
              ..where(
                items.setId.isIn(setIds) &
                    gear.status.isNotValue(EquipmentStatus.wanted.name),
              )
              ..orderBy([OrderingTerm.asc(items.equipmentId)]))
            .map((r) => r.readTable(items))
            .get();
    return [
      for (final setId in setIds.toSet())
        (
          setId: setId,
          equipmentIds: [
            for (final r in rows)
              if (r.setId == setId) r.equipmentId,
          ],
        ),
    ];
  }

  /// Adds every item of [setIds] to each dive, expanded as
  /// [bulkAddEquipment] expands, each row tagged with the set it came
  /// through. The tagging is `GearExpander`'s, as everywhere gear goes on:
  /// one expansion per dive, so on overlap the first set wins; a top-level
  /// row already from another set keeps it; a row with no set (added by
  /// hand) takes this one; and a row an added assembly adopts as its part
  /// takes the assembly's set. Writes and bumps only the dives whose rows
  /// change, and returns their ids. No notify/txn.
  Future<List<String>> bulkAddEquipmentSets(
    List<String> diveIds,
    List<String> setIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    final sets = await _setItems(setIds);
    final additions = [
      for (final s in sets)
        for (final id in s.equipmentIds) (equipmentId: id, viaSetId: s.setId),
    ];
    if (additions.isEmpty) return const [];
    final index = await _loadComponentsIndex();
    final active = await _activeIdsAmong({
      for (final a in additions) ...[
        a.equipmentId,
        ...index.descendantsOf(a.equipmentId),
      ],
    });
    return _rewriteGear(
      diveIds,
      (rows) => GearExpander.expand(
        additions: additions,
        index: index,
        existing: rows,
        isActive: active.contains,
      ),
    );
  }

  /// Removes from each dive every row tagged with one of [setIds], with what
  /// is attached through it. A row with no set, or another set, stays, even
  /// when one of [setIds] holds the item; a hand-added row a set later took
  /// on carries that set, and goes with it. Writes and bumps only the dives
  /// whose rows change, and returns their ids. No notify/txn.
  Future<List<String>> bulkRemoveEquipmentSets(
    List<String> diveIds,
    List<String> setIds,
  ) async {
    if (diveIds.isEmpty || setIds.isEmpty) return const [];
    final wanted = setIds.toSet();
    return _rewriteGear(diveIds, (rows) {
      var next = rows;
      for (final r in rows) {
        if (wanted.contains(r.viaSetId)) {
          next = GearExpander.removeSubtree(next, r.equipmentId);
        }
      }
      return next;
    });
  }

  /// Applies [rewrite] to each dive's rows and writes the dives it changes.
  Future<List<String>> _rewriteGear(
    List<String> diveIds,
    List<GearProvenance> Function(List<GearProvenance> rows) rewrite,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = <String>[];
    for (final diveId in diveIds) {
      final rows = await _provenanceOf(diveId);
      final next = rewrite(rows);
      if (_sameGear(rows, next)) continue;
      await _writeGearDiff(diveId, next, now);
      changed.add(diveId);
    }
    if (changed.isNotEmpty) await _bumpDives(changed, now);
    return changed;
  }

  /// Whether [a] and [b] hold the same rows with the same provenance, in
  /// any order: the diff writer ignores order, so this does too.
  static bool _sameGear(List<GearProvenance> a, List<GearProvenance> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}
