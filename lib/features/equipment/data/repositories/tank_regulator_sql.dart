/// SQL for "the regulators on a dive tank" (issue #3375): the first in
/// `dive_tanks.regulator_equipment_id`, the rest as a JSON array in
/// `dive_tanks.extra_regulator_ids`. Every raw-SQL reader that asks which
/// regulators a tank or dive has goes through here, so the counts, the gear
/// filters and the service clocks cannot disagree.
///
/// Arguments are SQL expressions (a table alias, `?1`, `{from}.id`), never
/// user input.
library;

/// The tank's extras as JSON `json_each` can read, or NULL unless the stored
/// text is a JSON array: `json_each` fails the whole statement on malformed
/// JSON, and one bad row from a peer must not break every equipment page.
/// A JSON scalar or object is valid but is no list (decodeExtraRegulatorIds
/// reads it as none), so SQL reads it as none too. Nested so json_type never
/// sees invalid text. A reader that emits the ids keeps only text elements
/// (`typeof(value) = 'text'`), as the decoder drops non-strings; a reader
/// that compares them to an id needs no filter, since no number or null
/// equals one.
String tankExtraRegulatorsJson(String tank) =>
    'CASE WHEN json_valid($tank.extra_regulator_ids) THEN '
    "CASE WHEN json_type($tank.extra_regulator_ids) = 'array' "
    'THEN $tank.extra_regulator_ids END END';

/// True when [tank] names any id in [inList] (the inside of an `IN (...)`).
/// The list appears twice, so anonymous `?` markers in it are bound twice.
String tankNamesAnyRegulatorSql(String tank, String inList) =>
    '($tank.regulator_equipment_id IN ($inList) OR EXISTS (SELECT 1 FROM '
    'json_each(${tankExtraRegulatorsJson(tank)}) WHERE value IN ($inList)))';

/// A `SELECT dive_id` of every dive with a tank naming [id]. Two branches,
/// so the first regulator reads its index and the extras the partial index
/// over tanks that have any; safe to correlate per item.
String tankRegulatorDiveIdsSql(String id) =>
    'SELECT rt.dive_id FROM dive_tanks rt '
    'WHERE rt.regulator_equipment_id = $id '
    'UNION ALL SELECT dive_id FROM ($tankExtraRegulatorRowsSql) '
    'WHERE regulator_id = $id';

/// A `SELECT` of every regulator id on the tanks of dive [diveId].
String tankRegulatorIdsOfDiveSql(String diveId) =>
    'SELECT rt.regulator_equipment_id FROM dive_tanks rt '
    'WHERE rt.dive_id = $diveId AND rt.regulator_equipment_id IS NOT NULL '
    'UNION SELECT rj.value FROM dive_tanks rt, '
    'json_each(${tankExtraRegulatorsJson('rt')}) rj '
    "WHERE rt.dive_id = $diveId AND typeof(rj.value) = 'text'";

/// One row per extra regulator on a tank: `dive_id`, `o2_percent` and
/// `regulator_id`. Read as its own UNION branch rather than an OR inside a
/// join, so the first regulator keeps its index on `regulator_equipment_id`
/// and this branch reads only the tanks the partial index on
/// `extra_regulator_ids` holds.
final String tankExtraRegulatorRowsSql =
    'SELECT xt.dive_id, xt.o2_percent, xj.value AS regulator_id '
    'FROM dive_tanks xt, json_each(${tankExtraRegulatorsJson('xt')}) xj '
    "WHERE xt.extra_regulator_ids IS NOT NULL AND typeof(xj.value) = 'text'";

/// A `SELECT dive_id, equipment_id` of every (dive, regulator) pair on the
/// tanks, first and extra, for the gear unions that rank items by dives.
final String tankRegulatorPairsSql =
    'SELECT dive_id, regulator_equipment_id AS equipment_id FROM dive_tanks '
    'WHERE regulator_equipment_id IS NOT NULL '
    'UNION SELECT dive_id, regulator_id FROM ($tankExtraRegulatorRowsSql)';
