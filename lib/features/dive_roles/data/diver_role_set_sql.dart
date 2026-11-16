import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// The canonical rank of a role id expression in SQL, as
/// `DiveRoleSet.compare` ranks it: built-in ids in [DiveRole.builtInIds]
/// order, every other id after them, and the generic Buddy role last.
String _rankSql(String id) {
  final cases = StringBuffer();
  for (final (index, builtIn) in DiveRole.builtInIds.indexed) {
    final rank = builtIn == DiveRole.buddyId
        ? DiveRole.builtInIds.length + 1
        : index;
    cases.write(" WHEN '$builtIn' THEN $rank");
  }
  return '(CASE $id$cases ELSE ${DiveRole.builtInIds.length} END)';
}

/// Whether the dive's [scalar] `diver_role` expression holds no role: null
/// or blank, as `DiveRoleSet.resolve` reads it. The one spelling of the
/// rule, so the My role card's Not set bar, its drill-in (`role:none`) and
/// [diverRoleIdsOfDiveSql] can never disagree (#4409).
String diverRoleUnsetSql(String scalar) => "($scalar IS NULL OR $scalar = '')";

/// A `SELECT` of the diver's own role ids on one dive (issue #4409), read by
/// the same rule as `DiveRoleSet.resolve`: a null or blank [scalar] is no
/// role; the `dive_diver_roles` rows count only when their normalized
/// primary role is [scalar]; otherwise the set is [scalar] alone.
///
/// [diveId] and [scalar] are SQL expressions for the dive's id and its
/// `diver_role` column (`'{from}.id'` and `'{from}.diver_role'` inside a
/// query relation, `'d.id'` and `'d.diver_role'` in a hand-written query).
/// The result has one column, `role_id`, and binds no parameters.
String diverRoleIdsOfDiveSql({required String diveId, required String scalar}) {
  const solo = DiveRole.soloId;
  final rows = 'FROM dive_diver_roles j WHERE j.dive_id = $diveId';
  // A row normalize keeps beside another role: Solo is dropped there.
  const kept = "j.role_id NOT IN ('', '$solo')";
  final hasRole = 'NOT ${diverRoleUnsetSql(scalar)}';
  final ranksBefore =
      '(${_rankSql('j.role_id')} < ${_rankSql(scalar)} OR '
      '(${_rankSql('j.role_id')} = ${_rankSql(scalar)} AND '
      'j.role_id < $scalar))';
  // The junction's normalized primary is the scalar: the scalar is a row,
  // Solo is the primary only when no other role sits beside it, and no
  // kept row ranks ahead of the scalar.
  final current =
      '(EXISTS (SELECT 1 $rows AND j.role_id = $scalar) '
      "AND ($scalar <> '$solo' OR NOT EXISTS (SELECT 1 $rows AND $kept)) "
      'AND NOT EXISTS (SELECT 1 $rows AND $kept AND $ranksBefore))';
  return 'SELECT $scalar AS role_id WHERE $hasRole AND NOT $current '
      'UNION SELECT j.role_id AS role_id $rows AND $hasRole AND $current '
      "AND j.role_id <> '' AND (j.role_id <> '$solo' OR $scalar = '$solo')";
}

/// Whether the `dive_roles` row [role] (a table alias) is one a dive owned
/// by [diveDiverId] can hold, by the rule `resolveDiveRole` reads: a
/// built-in or ownerless role, or the dive owner's own custom role. Another
/// diver's custom role is not borrowed (#1806), so neither the `myRole`
/// relation nor the My role card counts it (#4409).
String diveRoleVisibleSql({
  required String role,
  required String diveDiverId,
}) =>
    '($role.is_built_in = 1 OR $role.diver_id IS NULL '
    'OR $diveDiverId IS NULL OR $role.diver_id = $diveDiverId)';
