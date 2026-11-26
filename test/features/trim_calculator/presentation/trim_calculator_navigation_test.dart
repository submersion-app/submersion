import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trim_calculator/presentation/trim_calculator_navigation.dart';

/// Where the trim calculator lives (issue #5028).
void main() {
  test('without a dive, the bare tool path', () {
    expect(trimCalculatorLocation(), '/planning/trim-calculator');
  });

  test('a dive rides in ?dive=, encoded', () {
    final uri = Uri.parse(trimCalculatorLocation(diveId: 'a b&c'));
    expect(uri.path, '/planning/trim-calculator');
    expect(uri.queryParameters[kTrimCalculatorDiveParam], 'a b&c');
  });
}
