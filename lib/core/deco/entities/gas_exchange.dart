/// Which way one inert gas moves between a tissue compartment and the gas
/// being breathed at that instant.
///
/// Gas always moves toward the inspired partial pressure, so a compartment
/// below it takes gas up and one above it releases gas.
enum GasExchange {
  /// The compartment is taking the gas up.
  ongassing,

  /// The compartment is releasing the gas.
  offgassing,

  /// The compartment holds the gas at (practically) the inspired pressure.
  equilibrium,
}
