import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';

void main() {
  test('every unit round trips through its own conversion', () {
    for (final unit in CsvUnit.values) {
      expect(unit.toMetric(unit.fromMetric(12.345)), closeTo(12.345, 1e-9));
    }
  });

  test('conversions match the app formatter constants', () {
    expect(CsvUnit.feet.fromMetric(10), closeTo(32.8084, 1e-9));
    expect(CsvUnit.fahrenheit.fromMetric(20), closeTo(68, 1e-9));
    expect(CsvUnit.psi.fromMetric(200), closeTo(2900.76, 1e-6));
    expect(CsvUnit.pounds.fromMetric(1), closeTo(2.20462, 1e-9));
    expect(CsvUnit.kilometersPerHour.fromMetric(1), closeTo(3.6, 1e-9));
    expect(CsvUnit.knots.fromMetric(1), closeTo(1.94384, 1e-9));
  });

  test('symbols resolve back to their unit', () {
    for (final unit in CsvUnit.values) {
      expect(CsvUnit.fromSymbol(unit.symbol), unit);
    }
    expect(CsvUnit.fromSymbol('FT'), CsvUnit.feet);
    expect(CsvUnit.fromSymbol('furlongs'), isNull);
    expect(CsvUnit.fromSymbol(null), isNull);
  });

  test('metric units per quantity', () {
    expect(CsvUnit.metricFor(CsvQuantity.depth), CsvUnit.meters);
    expect(CsvUnit.metricFor(CsvQuantity.windSpeed), CsvUnit.metersPerSecond);
  });
}
