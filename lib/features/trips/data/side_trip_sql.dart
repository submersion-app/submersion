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
/// side trips: the dives every per-trip figure counts.
String tripDivesScopeSql(String diveAlias, String tripRef) =>
    '($diveAlias.trip_id = $tripRef OR $diveAlias.trip_id IN '
    '(${sideTripIdsSql(tripRef)}))';

/// True for a trip (alias `t`) that is not a valid side trip: the trips a
/// comparison across trips samples, so no dive counts twice.
const String topLevelTripSql =
    'NOT EXISTS (SELECT 1 FROM trips p WHERE p.id = t.parent_trip_id '
    'AND p.parent_trip_id IS NULL AND p.id <> t.id)';
