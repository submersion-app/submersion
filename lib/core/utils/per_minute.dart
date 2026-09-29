/// Spells a per-minute rate unit: "bar/min", "psi/min", "m/min".
///
/// The one place a rate unit is written, so every surface reads the same.
/// It imports nothing, so the query language can use it without pulling in
/// the settings layer that `UnitFormatter` depends on.
String perMinute(String unitSymbol) => '$unitSymbol/min';
