import 'dart:math' as math;

/// Selectable algorithms converting a ppO2 exposure into CNS %/min.
///
/// All methods derive from the NOAA Diving Manual (4th ed.) oxygen exposure
/// limits and differ only in how they read between and beyond the table
/// entries. Method references (no code copied from any of them):
/// - NOAA Diving Manual, 4th edition, oxygen exposure limits; the table and
///   the CNS-clock concept are summarized with worked examples in
///   https://shearwater.com/blogs/community/shearwater-and-the-cns-oxygen-clock
/// - Shearwater, "Shearwater and the CNS Oxygen Clock" (linear interpolation
///   of the NOAA limits; 1% per 4 s above 1.65 bar; 90-min surface half-life):
///   https://shearwater.com/blogs/community/shearwater-and-the-cns-oxygen-clock
/// - Subsurface core/divelist.cpp two-line log fit (Robert C. Helling):
///   https://github.com/subsurface/subsurface/commit/a0912b38bd
/// - R. C. Helling, "Calculating Oxygen CNS toxicity" (derivation behind the
///   Subsurface fit):
///   https://thetheoreticaldiver.org/wordpress/index.php/2019/08/15/calculating-oxygen-cns-toxicity/
/// - Decision record: docs/plans/2026-07-16-cns-calculation-method-setting-design.md
///   and https://github.com/submersion-app/submersion/issues/578
enum CnsCalculationMethod {
  /// Steps: each 0.1-bar band charged at its harsher edge (legacy behavior).
  classic('classic'),

  /// Linear interpolation of the NOAA time limits between entries; flat
  /// 15 %/min above 1.65 bar. Matches Shearwater's documented method.
  shearwater('shearwater'),

  /// Two-line least-squares fit to the log of the NOAA table, as used by
  /// Subsurface since 2019. Continuous and extrapolates above the table.
  subsurface('subsurface');

  final String dbValue;
  const CnsCalculationMethod(this.dbValue);

  static CnsCalculationMethod fromDbValue(String? value) {
    for (final method in CnsCalculationMethod.values) {
      if (method.dbValue == value) return method;
    }
    return CnsCalculationMethod.shearwater;
  }

  /// NOAA Diving Manual (4th ed.) single-exposure limits.
  static const List<double> _noaaPpO2 = [
    0.6,
    0.7,
    0.8,
    0.9,
    1.0,
    1.1,
    1.2,
    1.3,
    1.4,
    1.5,
    1.6,
  ];
  static const List<double> _noaaLimitMinutes = [
    720,
    570,
    450,
    360,
    300,
    240,
    210,
    180,
    150,
    120,
    45,
  ];

  /// CNS accumulation rate in %/min at [ppO2] (bar). Zero at or below 0.5.
  double cnsPerMinute(double ppO2) {
    if (ppO2 <= 0.5) return 0.0;
    switch (this) {
      case CnsCalculationMethod.classic:
        return _classicRate(ppO2);
      case CnsCalculationMethod.shearwater:
        return _shearwaterRate(ppO2);
      case CnsCalculationMethod.subsurface:
        return _subsurfaceRate(ppO2);
    }
  }

  static double _classicRate(double ppO2) {
    for (var i = 0; i < _noaaPpO2.length; i++) {
      if (ppO2 <= _noaaPpO2[i]) return 100.0 / _noaaLimitMinutes[i];
    }
    // Legacy flat rule above 1.6 bar. Known wart: milder than the table's
    // own trend above ~1.76 bar; kept verbatim for reproducibility of
    // historic values (design decision 2, PR #599).
    return 100.0 / 10.0;
  }

  static double _shearwaterRate(double ppO2) {
    if (ppO2 <= _noaaPpO2.first) return 100.0 / _noaaLimitMinutes.first;
    if (ppO2 > 1.65) return 15.0; // 1% per 4 s, per the Shearwater blog.
    if (ppO2 > _noaaPpO2.last) return 100.0 / _noaaLimitMinutes.last;
    for (var i = 1; i < _noaaPpO2.length; i++) {
      if (ppO2 <= _noaaPpO2[i]) {
        final t = (ppO2 - _noaaPpO2[i - 1]) / (_noaaPpO2[i] - _noaaPpO2[i - 1]);
        final limit =
            _noaaLimitMinutes[i - 1] +
            (_noaaLimitMinutes[i] - _noaaLimitMinutes[i - 1]) * t;
        return 100.0 / limit;
      }
    }
    return 100.0 / _noaaLimitMinutes.last;
  }

  static double _subsurfaceRate(double ppO2) {
    final mbar = ppO2 * 1000.0;
    final perSecond = mbar <= 1500.0
        ? math.exp(-11.7853 + 0.00193873 * mbar)
        : math.exp(-23.6349 + 0.00980829 * mbar);
    return perSecond * 100.0 * 60.0;
  }
}
