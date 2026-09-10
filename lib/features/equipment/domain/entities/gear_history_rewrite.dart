import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';

/// One change to an assembly's template, replayed on a past dive's rows
/// (issue #1487, "also update N past dives"). Pure: [applyTo] takes the
/// dive's provenance rows and returns the rows after the change, so the
/// repository is a loop and the rules live in one tested place.
///
/// Every variant leaves a dive that does not carry the assembly unchanged,
/// and never touches a row that hangs under some other parent.
sealed class GearHistoryRewrite extends Equatable {
  const GearHistoryRewrite();

  List<GearProvenance> applyTo(List<GearProvenance> rows, String assemblyId);

  static GearProvenance? _rowFor(List<GearProvenance> rows, String id) {
    for (final r in rows) {
      if (r.equipmentId == id) return r;
    }
    return null;
  }

  static GearProvenance? _rowUnder(
    List<GearProvenance> rows,
    String id,
    String parentId,
  ) {
    for (final r in rows) {
      if (r.equipmentId == id && r.viaEquipmentId == parentId) return r;
    }
    return null;
  }
}

/// A part was added to the template.
class GearPartAdded extends GearHistoryRewrite {
  final String partId;
  const GearPartAdded(this.partId);

  @override
  List<GearProvenance> applyTo(List<GearProvenance> rows, String assemblyId) {
    final assembly = GearHistoryRewrite._rowFor(rows, assemblyId);
    if (assembly == null) return rows;
    final current = GearHistoryRewrite._rowFor(rows, partId);
    if (current == null) {
      return [
        ...rows,
        GearProvenance(
          equipmentId: partId,
          viaEquipmentId: assemblyId,
          viaSetId: assembly.viaSetId,
        ),
      ];
    }
    // A row the diver added by hand adopts the assembly; one that already
    // hangs under another parent is that parent's business.
    if (!current.isTopLevel) return rows;
    return [
      for (final r in rows)
        if (r.equipmentId == partId)
          r.copyWith(
            viaEquipmentId: assemblyId,
            viaSetId: r.viaSetId ?? assembly.viaSetId,
          )
        else
          r,
    ];
  }

  @override
  List<Object?> get props => [partId];
}

/// A part was removed from the template.
class GearPartRemoved extends GearHistoryRewrite {
  final String partId;
  const GearPartRemoved(this.partId);

  @override
  List<GearProvenance> applyTo(List<GearProvenance> rows, String assemblyId) {
    if (GearHistoryRewrite._rowUnder(rows, partId, assemblyId) == null) {
      return rows;
    }
    return GearExpander.removeSubtree(rows, partId);
  }

  @override
  List<Object?> get props => [partId];
}

/// One part was swapped for another on the template.
class GearPartReplaced extends GearHistoryRewrite {
  final String oldPartId;
  final String newPartId;
  const GearPartReplaced({required this.oldPartId, required this.newPartId});

  @override
  List<GearProvenance> applyTo(List<GearProvenance> rows, String assemblyId) {
    final old = GearHistoryRewrite._rowUnder(rows, oldPartId, assemblyId);
    if (old == null) return rows;
    final existing = GearHistoryRewrite._rowFor(rows, newPartId);
    if (existing != null) {
      // The new part is already on the dive, and one item sits in one
      // place: a loose row adopts the assembly, but a row hanging under
      // some other parent is that assembly's, so the dive is left as it
      // is rather than quietly restructured. Same rule as an add.
      if (!existing.isTopLevel) return rows;
      // Adopting, the old row goes with its subtree so the composite key
      // holds.
      final adopted = [
        for (final r in rows)
          if (r.equipmentId == newPartId)
            r.copyWith(
              viaEquipmentId: assemblyId,
              viaSetId: old.viaSetId ?? r.viaSetId,
            )
          else
            r,
      ];
      return GearExpander.removeSubtree(adopted, oldPartId);
    }
    // Re-key in place: the row keeps its provenance and its children move
    // with it.
    return [
      for (final r in rows)
        if (r.equipmentId == oldPartId)
          GearProvenance(
            equipmentId: newPartId,
            viaEquipmentId: assemblyId,
            viaSetId: r.viaSetId,
          )
        else if (r.viaEquipmentId == oldPartId)
          r.copyWith(viaEquipmentId: newPartId)
        else
          r,
    ];
  }

  @override
  List<Object?> get props => [oldPartId, newPartId];
}
