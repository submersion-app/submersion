import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/tank_source_index.dart';

void main() {
  test('an explicit index wins', () {
    expect(
      effectiveSourceTankIndex(
        sourceTankIndex: 2,
        tankOrder: 0,
        hasSeries: true,
      ),
      2,
    );
  });

  test('a legacy row with a series resolves to its order', () {
    expect(
      effectiveSourceTankIndex(
        sourceTankIndex: null,
        tankOrder: 1,
        hasSeries: true,
      ),
      1,
    );
  });

  test('a legacy row without a series takes no parsed tank', () {
    expect(
      effectiveSourceTankIndex(
        sourceTankIndex: null,
        tankOrder: 1,
        hasSeries: false,
      ),
      kNoSourceTankIndex,
    );
  });
}
