/// Which quantity the per-cell CCR O2 traces are drawn in.
///
/// A dive that logs a trustworthy calibration carries both: the cell's raw
/// output, and the ppO2 derived from it. They are the same measurement one
/// per-cell constant apart, so the chart draws one of them, not both.
enum O2CellUnit {
  /// Partial pressure in bar. The calibrated, cell-to-cell comparable
  /// reading, and what the loop actually sees.
  ppO2,

  /// The cell's raw output. The only reading available when the logged
  /// calibration cannot be trusted (issue #810).
  millivolts,
}
