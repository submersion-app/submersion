/// A site's entry method as a dive's fallback, only when the site lists
/// exactly one (issue #2054). Site methods are stored comma-joined, and a
/// list says nothing about which one a given dive used, so it yields NULL.
/// Shared by the entry-method distribution, the Focus factor rows and the
/// dive query's `entryMethod` field so they can never disagree.
String singleSiteEntryMethodSql(String column) =>
    "CASE WHEN instr($column, ',') = 0 THEN NULLIF($column, '') END";
