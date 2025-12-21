/// Measurement units used throughout the application
enum DepthUnit {
  meters('m'),
  feet('ft');

  final String symbol;
  const DepthUnit(this.symbol);

  double convert(double value, DepthUnit to) {
    if (this == to) return value;
    if (this == meters && to == feet) return value * 3.28084;
    if (this == feet && to == meters) return value / 3.28084;
    return value;
  }
}

enum TemperatureUnit {
  celsius('C'),
  fahrenheit('F');

  final String symbol;
  const TemperatureUnit(this.symbol);

  double convert(double value, TemperatureUnit to) {
    if (this == to) return value;
    if (this == celsius && to == fahrenheit) return (value * 9 / 5) + 32;
    if (this == fahrenheit && to == celsius) return (value - 32) * 5 / 9;
    return value;
  }
}

enum PressureUnit {
  bar('bar'),
  psi('psi');

  final String symbol;
  const PressureUnit(this.symbol);

  double convert(double value, PressureUnit to) {
    if (this == to) return value;
    if (this == bar && to == psi) return value * 14.5038;
    if (this == psi && to == bar) return value / 14.5038;
    return value;
  }
}

enum VolumeUnit {
  liters('L'),
  cubicFeet('cuft');

  final String symbol;
  const VolumeUnit(this.symbol);

  double convert(double value, VolumeUnit to) {
    if (this == to) return value;
    if (this == liters && to == cubicFeet) return value * 0.0353147;
    if (this == cubicFeet && to == liters) return value / 0.0353147;
    return value;
  }
}

enum WeightUnit {
  kilograms('kg'),
  pounds('lbs');

  final String symbol;
  const WeightUnit(this.symbol);

  double convert(double value, WeightUnit to) {
    if (this == to) return value;
    if (this == kilograms && to == pounds) return value * 2.20462;
    if (this == pounds && to == kilograms) return value / 2.20462;
    return value;
  }
}

/// SAC (Surface Air Consumption) calculation method
enum SacUnit {
  /// L/min - requires tank volume, calculates actual gas consumption
  litersPerMin('L/min'),

  /// pressure/min - uses pressure drop only (bar or psi depending on pressure unit)
  pressurePerMin('pressure/min');

  final String symbol;
  const SacUnit(this.symbol);
}