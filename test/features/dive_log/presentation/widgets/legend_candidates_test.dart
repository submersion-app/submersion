import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/legend_candidates.dart';

void main() {
  group('sortTankIdsByOrder', () {
    test('sorts ids by tank order with unknown ids last', () {
      const tanks = [
        DiveTank(id: 't2', gasMix: GasMix(o2: 21), order: 1),
        DiveTank(id: 't1', gasMix: GasMix(o2: 21), order: 0),
      ];
      expect(sortTankIdsByOrder(['unknown', 't2', 't1'], tanks), [
        't1',
        't2',
        'unknown',
      ]);
    });
  });

  group('tankFallbackColor', () {
    test('cycles through the palette', () {
      expect(tankFallbackColor(0), tankFallbackColor(6));
      expect(tankFallbackColor(1), isNot(tankFallbackColor(2)));
    });
  });
}
