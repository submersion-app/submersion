/// A free-text dive column whose earlier values the dive editor offers as
/// suggestions (#3229).
///
/// The SQL column name lives here, never in the caller, so the suggestions
/// query interpolates only these four fixed names.
enum DiveTextSuggestionField {
  diveOperator('dive_operator'),
  boatName('boat_name'),
  boatCaptain('boat_captain'),
  surfaceConditions('surface_conditions');

  const DiveTextSuggestionField(this.column);

  /// The `dives` column the values are read from.
  final String column;
}
