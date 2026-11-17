import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/legend_candidates.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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

  group('tankFallbackTitle (#4657)', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('an Avelo Hydrotank is named by its role', () {
      const hydrotank = DiveTank(id: 'h', role: TankRole.hydrotank);
      expect(tankFallbackTitle(l10n, hydrotank, 1), 'Hydrotank');
    });

    test('any other tank, or none, by its number', () {
      expect(tankFallbackTitle(l10n, const DiveTank(id: 'b'), 2), 'Tank 2');
      expect(tankFallbackTitle(l10n, null, 1), 'Tank 1');
    });
  });
}
