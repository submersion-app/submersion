/// The current location id of the item whose id is [equipmentIdExpr] (a
/// column such as `e.id`, or a query-language `{r}.id` token), or NULL for
/// no moves, a cleared location, or a place since deleted.
///
/// The one place the newest-move order lives in SQL: moved_at, then
/// created_at, then id, each descending, mirroring
/// `compareMovesNewestFirst`. The list, the filter and the detail card all
/// read through it, so they never disagree about where an item is.
String currentLocationIdSql(String equipmentIdExpr) =>
    '(SELECT m.location_id FROM equipment_location_moves m '
    'WHERE m.equipment_id = $equipmentIdExpr '
    'ORDER BY m.moved_at DESC, m.created_at DESC, m.id DESC LIMIT 1)';
