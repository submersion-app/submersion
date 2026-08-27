/// Which equation of state converts cylinder pressure to free gas volume.
///
/// Divers computing SAC by hand use the ideal gas law, and so do most training
/// agencies and logbooks: a 12 L cylinder at 200 bar holds 2400 L. Real air is
/// less compressible than that at fill pressures, so the same cylinder actually
/// holds about 2317 L, and every derived number (SAC, gas planning, reserves)
/// shifts by roughly 5% between the two.
///
/// Neither answer is wrong; they answer different questions. This preference
/// lets a diver pick the one that matches how they think about their gas, and
/// applies it consistently everywhere the app converts between pressure and
/// volume so that numbers never round-trip through two different models
/// (issue #828).
enum GasModel {
  /// Ideal gas law: free volume is `tankSize * pressureBar`.
  ///
  /// Matches hand calculation and dive table teaching.
  ideal,

  /// Real gas, corrected by a virial compressibility factor (Z).
  ///
  /// Physically accurate at fill pressures, and what the app used
  /// unconditionally before the preference existed.
  real;

  /// Parse a stored value, falling back to [GasModel.real] for unknown or
  /// missing input so an unreadable setting never silently changes gas math.
  static GasModel fromName(String? name) {
    for (final model in GasModel.values) {
      if (model.name == name) return model;
    }
    return GasModel.real;
  }
}
