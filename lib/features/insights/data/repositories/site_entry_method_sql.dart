/// A site's entry method as a dive's fallback, only when the site lists
/// exactly one (issue #2054). Site methods are stored comma-joined, and a
/// list says nothing about which one a given dive used, so it yields NULL.
/// Shared by the entry-method distribution and the Focus factor rows so the
/// two can never disagree.
String singleSiteEntryMethodSql(String column) =>
    "CASE WHEN instr($column, ',') = 0 THEN NULLIF($column, '') END";
