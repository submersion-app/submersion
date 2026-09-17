import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';

/// How far one assembly on a dive trails its template: the direct parts it
/// holds on the dive now, and how many it would hold after an update.
typedef AssemblyShortfall = ({int partsOnDive, int partsAvailable});

/// Compares the parts an assembly carries on a dive with its current
/// template (issue #1988).
///
/// A dive keeps the rows written when the assembly was attached, so a part
/// added to the template afterwards, with "from now on" chosen in the
/// history dialog, never reaches it. Both methods define "missing" as
/// exactly what [GearExpander] would write if the assembly were attached
/// again, so the indicator and the update action cannot disagree: a retired
/// or lost part is not missing, a loose row of a part is adopted, and a
/// part hanging under some other assembly stays where it is.
abstract final class AssemblySnapshot {
  /// [rows] with [assemblyId] expanded again from [index]. The rows already
  /// there keep their place and provenance; missing parts follow them,
  /// tagged with the assembly's own set. Returns [rows] itself when the
  /// assembly is not on the dive.
  static List<GearProvenance> refreshed(
    List<GearProvenance> rows,
    String assemblyId, {
    required ComponentsIndex index,
    required bool Function(String equipmentId) isActive,
  }) {
    GearProvenance? row;
    for (final r in rows) {
      if (r.equipmentId == assemblyId) {
        row = r;
        break;
      }
    }
    if (row == null) return rows;
    return GearExpander.expand(
      additions: [(equipmentId: assemblyId, viaSetId: row.viaSetId)],
      index: index,
      existing: rows,
      isActive: isActive,
    );
  }

  /// Every assembly on the dive that an update would change, keyed by id.
  /// An outer assembly is listed when only a nested one is behind, with
  /// equal counts, so its collapsed row can still offer the update.
  static Map<String, AssemblyShortfall> shortfalls(
    List<GearProvenance> rows, {
    required ComponentsIndex index,
    required bool Function(String equipmentId) isActive,
  }) {
    final before = GearTree.partCounts(rows);
    final result = <String, AssemblyShortfall>{};
    for (final row in rows) {
      final id = row.equipmentId;
      if (!index.isAssembly(id)) continue;
      final after = refreshed(rows, id, index: index, isActive: isActive);
      if (_sameRows(rows, after)) continue;
      result[id] = (
        partsOnDive: before[id] ?? 0,
        partsAvailable: GearTree.partCounts(after)[id] ?? 0,
      );
    }
    return result;
  }

  static bool _sameRows(List<GearProvenance> a, List<GearProvenance> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
