import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// The rules for a set of per-dive roles (issue #1221): one canonical order,
/// Solo exclusivity, the read rule that reconciles the junction tables with
/// the scalar primary-role columns older app versions still write, and the
/// merges the importers and the dive merge use.
///
/// Canonical order needs no database: built-in ids in [DiveRole.builtInIds]
/// order, then every other id ascending, with the generic Buddy role last of
/// all. Every device therefore agrees on a set's primary role, which is what
/// the scalar columns hold, and a set that names anything more specific than
/// Buddy keeps that as the role older app versions display.
abstract final class DiveRoleSet {
  static int _rank(String id) {
    if (id == DiveRole.buddyId) return DiveRole.builtInIds.length + 1;
    final index = DiveRole.builtInIds.indexOf(id);
    return index < 0 ? DiveRole.builtInIds.length : index;
  }

  static int compare(String a, String b) {
    final byRank = _rank(a).compareTo(_rank(b));
    return byRank != 0 ? byRank : a.compareTo(b);
  }

  /// [ids] deduped, blanks dropped, in canonical order, with Solo dropped
  /// when it sits beside any other role.
  static List<String> normalize(Iterable<String> ids) {
    final sorted = ids.where((id) => id.isNotEmpty).toSet().toList()
      ..sort(compare);
    if (sorted.length > 1 && sorted.contains(DiveRole.soloId)) {
      return List.unmodifiable([
        for (final id in sorted)
          if (id != DiveRole.soloId) id,
      ]);
    }
    return List.unmodifiable(sorted);
  }

  /// [normalize] for a buddy link, which always carries a role.
  static List<String> normalizeBuddy(Iterable<String> ids) {
    final normalized = normalize(ids);
    return normalized.isEmpty ? const [DiveRole.buddyId] : normalized;
  }

  /// The primary role of [ids]: what the scalar column holds.
  static String? primary(Iterable<String> ids) {
    final normalized = normalize(ids);
    return normalized.isEmpty ? null : normalized.first;
  }

  /// The roles a person holds, from the scalar column and the junction rows.
  ///
  /// The junction is current only when its own primary role is [scalar]:
  /// every write keeps the two in step, so any other combination means an
  /// older app version changed the scalar after the junction was written,
  /// and the scalar is the newer truth. A null scalar means no role.
  static List<String> resolve({
    required String? scalar,
    required Iterable<String> junction,
  }) {
    if (scalar == null || scalar.isEmpty) return const [];
    final set = normalize(junction);
    if (set.isNotEmpty && set.first == scalar) return set;
    return List.unmodifiable([scalar]);
  }

  /// [resolve] for a buddy link, never empty.
  static List<String> resolveBuddy({
    required String? scalar,
    required Iterable<String> junction,
  }) {
    final resolved = resolve(scalar: scalar, junction: junction);
    return resolved.isEmpty ? const [DiveRole.buddyId] : resolved;
  }

  /// Every role of every set in [sets], normalized.
  static List<String> union(Iterable<Iterable<String>> sets) =>
      normalize(sets.expand((s) => s));

  /// The importer rule: roles inferred from separate fields of a file are
  /// added up, and the generic Buddy role stays only when nothing more
  /// specific was found.
  static List<String> accumulate(Iterable<String> ids) {
    final normalized = normalize(ids);
    if (normalized.isEmpty) return const [DiveRole.buddyId];
    if (normalized.length > 1 && normalized.contains(DiveRole.buddyId)) {
      return List.unmodifiable([
        for (final id in normalized)
          if (id != DiveRole.buddyId) id,
      ]);
    }
    return normalized;
  }

  /// The picker rule: [id] flips in [current]; ticking Solo clears every
  /// other role and ticking anything else clears Solo.
  static List<String> toggle(Iterable<String> current, String id) {
    final set = current.toSet();
    if (set.contains(id)) {
      set.remove(id);
    } else if (id == DiveRole.soloId) {
      set
        ..clear()
        ..add(id);
    } else {
      set
        ..remove(DiveRole.soloId)
        ..add(id);
    }
    return normalize(set);
  }
}
