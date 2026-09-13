import 'package:submersion/core/constants/units.dart';

/// What a unit-bearing CSV column measures.
enum CsvQuantity { depth, temperature, pressure, volume, weight, windSpeed }

/// A unit a Submersion CSV column can carry: the symbol written in its
/// header, the quantity it measures, and its conversion to and from the
/// canonical metric value the database stores. Conversions reuse the app's
/// unit enums (and the wind constants of `UnitFormatter`) so the CSV can
/// never disagree with what the app displays.
enum CsvUnit {
  meters('m', CsvQuantity.depth),
  feet('ft', CsvQuantity.depth),
  celsius('°C', CsvQuantity.temperature),
  fahrenheit('°F', CsvQuantity.temperature),
  bar('bar', CsvQuantity.pressure),
  psi('psi', CsvQuantity.pressure),
  liters('L', CsvQuantity.volume),
  cubicFeet('cuft', CsvQuantity.volume),
  kilograms('kg', CsvQuantity.weight),
  pounds('lbs', CsvQuantity.weight),
  metersPerSecond('m/s', CsvQuantity.windSpeed),
  kilometersPerHour('km/h', CsvQuantity.windSpeed),
  knots('kts', CsvQuantity.windSpeed);

  const CsvUnit(this.symbol, this.quantity);

  final String symbol;
  final CsvQuantity quantity;

  static const _msToKmh = 3.6;
  static const _msToKnots = 1.94384;

  static CsvUnit metricFor(CsvQuantity quantity) => switch (quantity) {
    CsvQuantity.depth => meters,
    CsvQuantity.temperature => celsius,
    CsvQuantity.pressure => bar,
    CsvQuantity.volume => liters,
    CsvQuantity.weight => kilograms,
    CsvQuantity.windSpeed => metersPerSecond,
  };

  /// Decimals a My units value is written with. Chosen so no value is
  /// rounded more coarsely than the Metric export rounds its counterpart.
  int get myUnitsDecimals => switch (this) {
    meters || feet => 1,
    celsius || fahrenheit => 0,
    bar => 1,
    psi => 0,
    liters || cubicFeet => 1,
    kilograms || pounds => 2,
    metersPerSecond || kilometersPerHour || knots => 1,
  };

  double fromMetric(double value) => switch (this) {
    meters || celsius || bar || liters || kilograms || metersPerSecond => value,
    feet => DepthUnit.meters.convert(value, DepthUnit.feet),
    fahrenheit => TemperatureUnit.celsius.convert(
      value,
      TemperatureUnit.fahrenheit,
    ),
    psi => PressureUnit.bar.convert(value, PressureUnit.psi),
    cubicFeet => VolumeUnit.liters.convert(value, VolumeUnit.cubicFeet),
    pounds => WeightUnit.kilograms.convert(value, WeightUnit.pounds),
    kilometersPerHour => value * _msToKmh,
    knots => value * _msToKnots,
  };

  double toMetric(double value) => switch (this) {
    meters || celsius || bar || liters || kilograms || metersPerSecond => value,
    feet => DepthUnit.feet.convert(value, DepthUnit.meters),
    fahrenheit => TemperatureUnit.fahrenheit.convert(
      value,
      TemperatureUnit.celsius,
    ),
    psi => PressureUnit.psi.convert(value, PressureUnit.bar),
    cubicFeet => VolumeUnit.cubicFeet.convert(value, VolumeUnit.liters),
    pounds => WeightUnit.pounds.convert(value, WeightUnit.kilograms),
    kilometersPerHour => value / _msToKmh,
    knots => value / _msToKnots,
  };

  /// The unit whose header symbol is [symbol], ignoring case, or null.
  static CsvUnit? fromSymbol(String? symbol) {
    final wanted = symbol?.trim().toLowerCase();
    if (wanted == null || wanted.isEmpty) return null;
    for (final unit in values) {
      if (unit.symbol.toLowerCase() == wanted) return unit;
    }
    return null;
  }
}
