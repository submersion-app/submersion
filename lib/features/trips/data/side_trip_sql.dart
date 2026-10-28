/// The side-trip rule in SQL (issue #3658), one place for every query.
///
/// A trip C is a side trip of P only when `C.parent_trip_id = P.id`, P
/// exists, P has no parent of its own, and P is not C. A stored link that
/// fails any of these (a parent deleted on another device, a chain two deep
/// after a sync merge, a link to itself) reads as no parent, so no query can
/// loop or count a dive twice. `side_trips.dart` holds the same rule in Dart.
///
/// Each fragment takes a `tripRef`: a bound parameter such as `?1`, or a
/// column such as `t.id` for a correlated use.
library;

/// The ids of [tripRef]'s valid side trips.
String sideTripIdsSql(String tripRef) =>
    'SELECT c.id FROM trips c JOIN trips p ON p.id = c.parent_trip_id '
    'WHERE c.parent_trip_id = $tripRef AND p.parent_trip_id IS NULL '
    'AND c.id <> p.id';

/// The id of [tripRef]'s valid parent; no row when it has none.
String validParentIdSql(String tripRef) =>
    'SELECT p.id FROM trips c JOIN trips p ON p.id = c.parent_trip_id '
    'WHERE c.id = $tripRef AND p.parent_trip_id IS NULL AND p.id <> c.id';

/// True for a dive (alias [diveAlias]) on [tripRef] or on one of its valid
/// side trips: the dives every per-trip figure counts. For one trip, with
/// [tripRef] a bound parameter; across many trips use [tripDivesJoinSql].
String tripDivesScopeSql(String diveAlias, String tripRef) =>
    '($diveAlias.trip_id = $tripRef OR $diveAlias.trip_id IN '
    '(${sideTripIdsSql(tripRef)}))';

/// Every trip paired with each trip whose dives it counts: itself, and its
/// valid side trips. `owner_id` is the counting trip, `home_id` the dives'.
const String _tripDiveHomesSql =
    '(SELECT id AS owner_id, id AS home_id FROM trips '
    'UNION ALL '
    'SELECT p.id, c.id FROM trips c JOIN trips p ON p.id = c.parent_trip_id '
    'WHERE p.parent_trip_id IS NULL AND c.id <> p.id)';

/// Joins each trip (alias [tripAlias]) to the dives (alias [diveAlias]) its
/// per-trip figures count, for a query over many trips. Through a mapping
/// from each trip to the trips whose dives it counts, so the dives join is
/// an equality on `trip_id` and uses its index: [tripDivesScopeSql] in an
/// ON clause made SQLite walk every dive for every trip. [joinKind] is
/// `LEFT` (trips with no dives kept) or empty for an inner join; [extraOn]
/// adds conditions on the dive, starting with `AND`.
String tripDivesJoinSql({
  required String tripAlias,
  required String diveAlias,
  String joinKind = 'LEFT',
  String extraOn = '',
}) {
  final homes = '${diveAlias}_homes';
  return '$joinKind JOIN $_tripDiveHomesSql $homes '
      'ON $homes.owner_id = $tripAlias.id '
      '$joinKind JOIN dives $diveAlias '
      'ON $diveAlias.trip_id = $homes.home_id$extraOn';
}

/// True for a trip (alias `t`) that is not a valid side trip: the trips a
/// comparison across trips samples, so no dive counts twice.
const String topLevelTripSql =
    'NOT EXISTS (SELECT 1 FROM trips p WHERE p.id = t.parent_trip_id '
    'AND p.parent_trip_id IS NULL AND p.id <> t.id)';

/// The ids of the cylinder slots a dive on [tripRef] may breathe from: the
/// trip's own and, for a side trip, its larger trip's.
String linkableSlotIdsSql(String tripRef) =>
    'SELECT id FROM trip_cylinders WHERE trip_id = $tripRef '
    'OR trip_id IN (${validParentIdSql(tripRef)})';

/// The ids of the slots that account for a tank on a dive [tripRef]'s
/// figures count: the trip's own, its side trips' and its larger trip's. A
/// tank on none of them is a gap in the trip's gas record.
String accountedSlotIdsSql(String tripRef) =>
    'SELECT id FROM trip_cylinders WHERE trip_id = $tripRef '
    'OR trip_id IN (${sideTripIdsSql(tripRef)}) '
    'OR trip_id IN (${validParentIdSql(tripRef)})';
