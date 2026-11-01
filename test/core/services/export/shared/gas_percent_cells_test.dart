import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/shared/gas_percent_cells.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  test('a whole mix keeps its whole numbers', () {
    expect(gasPercentCells(32, 0), (o2: '32', he: '0'));
    expect(gasPercentCells(18, 45), (o2: '18', he: '45'));
    expect(gasPercentCells(100, 0), (o2: '100', he: '0'));
  });

  test('a fractional mix keeps one decimal', () {
    expect(gasPercentCells(10.5, 89.5), (o2: '10.5', he: '89.5'));
    expect(gasPercentCells(32.6, 17.4), (o2: '32.6', he: '17.4'));
  });

  test('helium gives way when both round up past 100', () {
    // Both are exact ties in binary, and a tie rounds up: 10.3 and 89.8.
    expect(gasPercentCells(10.25, 89.75), (o2: '10.3', he: '89.7'));
  });

  test('helium gives way completely when oxygen rounds up to 100', () {
    expect(gasPercentCells(99.96, 0.04), (o2: '100', he: '0'));
    expect(gasPercentCells(99.95, 0.05), (o2: '100', he: '0'));
  });

  test('every valid mix at two decimals stays within 100', () {
    for (var o2 = 0; o2 <= 10000; o2 += 5) {
      final cells = gasPercentCells(o2 / 100, (10000 - o2) / 100);
      final total = double.parse(cells.o2) + double.parse(cells.he);
      expect(total, lessThanOrEqualTo(100), reason: '$cells');
    }
  });

  test('a value that is not a number writes a cell, not a crash', () {
    expect(gasPercentCells(double.nan, 0), (o2: 'NaN', he: 'NaN'));
    expect(gasPercentCells(21, double.infinity), (o2: '21', he: '79'));
    expect(gasPercentCells(double.infinity, 5), (o2: 'Infinity', he: '0'));
  });

  test('no mix means no cells', () {
    expect(gasMixCells(null), isNull);
    expect(gasMixCells(const GasMix(o2: 18, he: 45)), (o2: '18', he: '45'));
  });

  test('a mix already over 100 cannot leave the file that way', () {
    expect(gasPercentCells(60, 50), (o2: '60', he: '40'));
    expect(gasPercentCells(110, 5), (o2: '110', he: '0'));
  });
}
