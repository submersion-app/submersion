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
  /// takes the assembly's set. A member or part another profile owns and
  /// has not shared with the dive's diver stays off that dive, as when the
  /// set is used on one dive (#2046). Writes and bumps only the dives whose
  /// rows change, and returns their ids. No notify/txn.
  Future<List<String>> bulkAddEquipmentSets(
    List<String> diveIds,
    List<String> setIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    final sets = await _setItems(setIds);
    if (sets.every((s) => s.equipmentIds.isEmpty)) return const [];
    final index = await _loadComponentsIndex();
    final candidates = {
      for (final s in sets)
        for (final id in s.equipmentIds) ...[id, ...index.descendantsOf(id)],
    };
    final active = await _activeIdsAmong(candidates);
    final visibility = EquipmentVisibilityQueries(_db);
    final diverOf = await visibility.diversOfDives(diveIds);
    final byDiver = <String?, List<String>>{};
    for (final id in diveIds) {
      // A dive that has gone has no gear to change.
      if (diverOf.containsKey(id)) (byDiver[diverOf[id]] ??= []).add(id);
    }
    final changed = <String>[];
    for (final MapEntry(key: diverId, value: dives) in byDiver.entries) {
      final usable = diverId == null
          ? candidates
          : (await visibility.usableSetMemberIds(
              candidates.toList(),
              diverId,
            )).toSet();
      final additions = [
        for (final s in sets)
          for (final id in s.equipmentIds)
            if (usable.contains(id)) (equipmentId: id, viaSetId: s.setId),
      ];
      if (additions.isEmpty) continue;
      changed.addAll(
        await _rewriteGear(
          dives,
          (rows) => GearExpander.expand(
            additions: additions,
            index: index,
            existing: rows,
            isActive: (id) => active.contains(id) && usable.contains(id),
          ),
        ),
      );
    }
    return changed;
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
  /// The rows are read for every dive up front, a query per chunk rather
  /// than per dive, since most dives of a rule re-run change nothing. The
  /// expander and the removals keep row order, so an unchanged dive
  /// compares equal row by row.
  Future<List<String>> _rewriteGear(
    List<String> diveIds,
    List<GearProvenance> Function(List<GearProvenance> rows) rewrite,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rowsByDive = await _provenanceOfDives(diveIds);
    final changed = <String>[];
    for (final diveId in diveIds) {
      final rows = rowsByDive[diveId] ?? const <GearProvenance>[];
      final next = rewrite(rows);
      if (DiveRepository._sameRows(rows, next)) continue;
      await _writeGearDiff(diveId, next, now);
      changed.add(diveId);
    }
    if (changed.isNotEmpty) await _bumpDives(changed, now);
    return changed;
  }

  /// Each of [diveIds]' gear rows, as [_provenanceOf] reads one dive's, in
  /// one query per chunk. A dive with no rows is absent.
  Future<Map<String, List<GearProvenance>>> _provenanceOfDives(
    List<String> diveIds,
  ) async {
    final out = <String, List<GearProvenance>>{};
    for (final chunk in seriesIdChunks(diveIds.toSet().toList())) {
      final rows = await (_db.select(
        _db.diveEquipment,
      )..where((t) => t.diveId.isIn(chunk))).get();
      for (final r in rows) {
        (out[r.diveId] ??= []).add(
          GearProvenance(
            equipmentId: r.equipmentId,
            viaEquipmentId: r.viaEquipmentId,
            viaSetId: r.viaSetId,
          ),
        );
      }
    }
    return out;
  }
}
