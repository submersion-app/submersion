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
    return GearExpander.expand(
      additions: [(equipmentId: itemId, viaSetId: setId)],
      index: index,
      existing: rows,
      // The parts it brings pass the same filter, as applying the set does.
      isActive: (id) => isActive(id) && isUsable(id),
    );
  }

  @override
  List<Object?> get props => [itemId];
}

/// An item left the set. It goes with the parts hanging under it, except a
/// part that is still a member of the set in its own right: that one stays,
/// with its own parts, and moves to the top level, as applying the set
/// fresh would put it.
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
    final kept = <String>{
      for (final id in subtree)
        if (id != itemId && isMember(id)) ...GearExpander.subtreeIds(rows, id),
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
