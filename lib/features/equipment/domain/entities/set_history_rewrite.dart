import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';

/// One change to an equipment set's members, replayed on a dive's rows
/// (issue #4283, "also update N dives"). Pure, like [GearHistoryRewrite]:
/// [applyTo] takes the dive's provenance rows and returns them after the
/// change, so the repository is a loop and the rules live here.
///
/// Every variant leaves a dive that does not carry the set unchanged, and
/// touches only rows the set put on the dive, or a loose row added by hand
/// that an added member adopts.
sealed class SetHistoryRewrite extends Equatable {
  const SetHistoryRewrite();

  /// [isActive] skips retired, sold, lost and wanted gear, as expanding an
  /// assembly does. [isUsable] is the filter applying a set already uses
  /// for the dive's diver: no other profile's unshared gear, for an added
  /// item and the parts it brings. [isMember] names the set's members after
  /// the change, which a removal leaves on the dive.
  List<GearProvenance> applyTo(
    List<GearProvenance> rows,
    String setId, {
    required ComponentsIndex index,
    required bool Function(String equipmentId) isActive,
    required bool Function(String equipmentId) isUsable,
    bool Function(String equipmentId) isMember = _noMember,
  });

  static bool _noMember(String equipmentId) => false;

  static bool _carries(List<GearProvenance> rows, String setId) =>
      rows.any((r) => r.viaSetId == setId);

  static GearProvenance? _rowFor(List<GearProvenance> rows, String id) {
    for (final r in rows) {
      if (r.equipmentId == id) return r;
    }
    return null;
  }
}

/// An item joined the set.
class SetItemAdded extends SetHistoryRewrite {
  final String itemId;
  const SetItemAdded(this.itemId);

  @override
  List<GearProvenance> applyTo(
    List<GearProvenance> rows,
    String setId, {
    required ComponentsIndex index,
    required bool Function(String equipmentId) isActive,
    required bool Function(String equipmentId) isUsable,
    bool Function(String equipmentId) isMember = SetHistoryRewrite._noMember,
  }) {
    if (!SetHistoryRewrite._carries(rows, setId)) return rows;
    if (!isActive(itemId) || !isUsable(itemId)) return rows;
    final current = SetHistoryRewrite._rowFor(rows, itemId);
    // A row under an assembly is that assembly's, and one another set put
    // there is that set's: the dive is left as it is rather than quietly
    // restructured. A loose hand-added row is adopted below.
    if (current != null &&
        (!current.isTopLevel ||
            (current.viaSetId != null && current.viaSetId != setId))) {
      return rows;
    }
    // A part another set put on the dive is that set's, as the item itself
    // is above: the walk neither re-tags it nor goes below it, so removing
    // this member later cannot take it off the dive.
    final foreign = {
      for (final r in rows)
        if (r.viaSetId != null && r.viaSetId != setId) r.equipmentId,
    };
    return GearExpander.expand(
      additions: [(equipmentId: itemId, viaSetId: setId)],
      index: index,
      existing: rows,
      // The parts it brings pass the same filter, as applying the set does.
      isActive: (id) => isActive(id) && isUsable(id) && !foreign.contains(id),
    );
  }

  @override
  List<Object?> get props => [itemId];
}

/// An item left the set. It goes with the parts the set hung under it. A
/// row under it that the set did not put there (added by hand, or by
/// another set), or a part still a member of the set in its own right,
/// stays with its own parts and moves to the top level.
class SetItemRemoved extends SetHistoryRewrite {
  final String itemId;
  const SetItemRemoved(this.itemId);

  @override
  List<GearProvenance> applyTo(
    List<GearProvenance> rows,
    String setId, {
    required ComponentsIndex index,
    required bool Function(String equipmentId) isActive,
    required bool Function(String equipmentId) isUsable,
    bool Function(String equipmentId) isMember = SetHistoryRewrite._noMember,
  }) {
    final current = SetHistoryRewrite._rowFor(rows, itemId);
    if (current == null || !current.isTopLevel || current.viaSetId != setId) {
      return rows;
    }
    final subtree = GearExpander.subtreeIds(rows, itemId);
    // What the set did not put there stays: a row added by hand under the
    // assembly, or one another set brought, as does a part still a member.
    final kept = <String>{
      for (final r in rows)
        if (r.equipmentId != itemId &&
            subtree.contains(r.equipmentId) &&
            (r.viaSetId != setId || isMember(r.equipmentId)))
          ...GearExpander.subtreeIds(rows, r.equipmentId),
    };
    return [
      for (final r in rows)
        if (!subtree.contains(r.equipmentId))
          r
        else if (kept.contains(r.equipmentId))
          // A kept member whose parent goes becomes a top-level row.
          kept.contains(r.viaEquipmentId)
              ? r
              : r.copyWith(clearViaEquipmentId: true),
    ];
  }

  @override
  List<Object?> get props => [itemId];
}
