import 'package:submersion/core/database/database.dart';

/// Which stored tank row takes each parsed tank index of a computer's
/// reading, for a re-parse or a replace-source re-import of that computer.
///
/// A row's source index wins (a reassignment, issue #1314), so a diver who
/// reordered the cylinders or moved a series to another row keeps that.
/// Rows from before v200 carry no source index and fall back to their
/// order. The source-index match takes only rows of [computerId]; the
/// fallback also takes rows attributed to no computer (legacy and manual
/// rows), never another computer's row on a multi-source dive. A row marked
/// kNoSourceTankIndex takes nothing. Each row takes at most one index,
/// claimed in [parsedIndices] order.
///
/// An index missing from the result has no stored row.
Map<int, DiveTank> matchStoredTanks(
  List<DiveTank> stored,
  Iterable<int> parsedIndices, {
  required String? computerId,
}) {
  final matched = <int, DiveTank>{};
  final claimed = <String>{};

  DiveTank? rowFor(int index) {
    for (final t in stored) {
      if (claimed.contains(t.id)) continue;
      if (t.computerId != computerId) continue;
      if (t.sourceTankIndex == index) return t;
    }
    for (final t in stored) {
      if (claimed.contains(t.id)) continue;
      if (t.computerId != null && t.computerId != computerId) continue;
      if (t.sourceTankIndex == null && t.tankOrder == index) return t;
    }
    return null;
  }

  for (final index in parsedIndices) {
    final row = rowFor(index);
    if (row == null) continue;
    claimed.add(row.id);
    matched[index] = row;
  }
  return matched;
}
