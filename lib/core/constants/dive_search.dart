/// Maximum number of dive search matches surfaced to the UI.
///
/// This is the display bound: `searchDiveSummaries` enforces it as the SQL
/// row limit, while the search provider over-fetches by one so the UI can
/// tell a truncated result (more than this many matches) from an exact one
/// and show the "showing first N" notice only when results were actually cut.
///
/// Lives in core rather than on the repository so the presentation layer can
/// reference it without importing data-layer implementation details.
const int kDiveSearchResultLimit = 100;
