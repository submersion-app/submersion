/// The oxygen-cell linearity check CCR divers run on every build (issue
/// #986).
///
/// A galvanic cell's output is proportional to the ppO2 at its face, so a
/// reading taken in air predicts what the cell should produce in pure
/// oxygen. A cell that cannot reach that figure is current limited: it reads
/// plausibly at the surface and under-reports at depth, which is exactly
/// where under-reporting is dangerous.
///
/// The ambient pressure term cancels in the ratio, because both readings are
/// taken in the same place seconds apart, so this needs no altitude or
/// barometric input and must never acquire one.
class CellLinearity {
  const CellLinearity._();

  /// Fraction of oxygen in air, the divisor the check is built on.
  static const double airOxygenFraction = 0.209;

  /// Millivolts the cell should produce at a ppO2 of 1.0, or null when
  /// [airMillivolts] is absent or not positive.
  ///
  /// A zero or negative air reading is a broken or disconnected cell, not a
  /// number to divide by, so it yields null rather than an infinity.
  static double? expectedO2Millivolts(double? airMillivolts) {
    if (airMillivolts == null || airMillivolts <= 0) return null;
    return airMillivolts / airOxygenFraction;
  }

  /// Measured output over expected output, as a percentage, or null when
  /// either input is missing or the expectation cannot be computed.
  ///
  /// Derived from the exact expected value, never from a rounded one:
  /// rounding is presentation, applied once at the point of display.
  static double? percent({double? airMillivolts, double? o2Millivolts}) {
    final expected = expectedO2Millivolts(airMillivolts);
    if (expected == null || o2Millivolts == null) return null;
    return o2Millivolts / expected * 100;
  }
}
