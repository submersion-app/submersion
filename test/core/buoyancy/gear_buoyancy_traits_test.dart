import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';

void main() {
  test('parsePanelsMm handles single and multi-panel designations', () {
    expect(GearBuoyancyTraits.parsePanelsMm('5'), [5.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('5/4'), [5.0, 4.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('8/7/6'), [8.0, 7.0, 6.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('4,3'), [4.0, 3.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('6-3'), [6.0, 3.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('6/5/4mm'), [6.0, 5.0, 4.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('5.5 mm'), [5.5]);
  });

  test('parsePanelsMm skips garbage and empty segments', () {
    expect(GearBuoyancyTraits.parsePanelsMm('thin'), isEmpty);
    expect(GearBuoyancyTraits.parsePanelsMm(''), isEmpty);
    expect(GearBuoyancyTraits.parsePanelsMm('5/x/3'), [5.0, 3.0]);
    expect(GearBuoyancyTraits.parsePanelsMm(' 7 / 5 '), [7.0, 5.0]);
  });

  test('parsePanelsMm drops non-finite (overflowing) values', () {
    // A digit run that overflows the double range parses to Infinity;
    // it must never reach the panel list or it propagates into predictions.
    final overflow = '1${'0' * 400}';
    expect(double.tryParse(overflow)?.isFinite, isFalse);
    expect(GearBuoyancyTraits.parsePanelsMm(overflow), isEmpty);
    expect(GearBuoyancyTraits.parsePanelsMm('5/$overflow/3'), [5.0, 3.0]);
  });

  test('value equality compares panel lists by content, not identity', () {
    // Distinct list instances with equal contents. The lists live in
    // non-const locals so the constructors can't be const-canonicalized,
    // which is what would otherwise mask content-vs-identity equality.
    final aPanels = [5.0, 4.0];
    final bPanels = [5.0, 4.0];
    final cPanels = [5.0, 3.0];
    final a = GearBuoyancyTraits(
      primaryThicknessMm: 5,
      panelThicknessesMm: aPanels,
      suitStyle: 'full',
    );
    final b = GearBuoyancyTraits(
      primaryThicknessMm: 5,
      panelThicknessesMm: bPanels,
      suitStyle: 'full',
    );
    expect(identical(aPanels, bPanels), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    // Differing panel contents make the traits unequal.
    final c = GearBuoyancyTraits(
      primaryThicknessMm: 5,
      panelThicknessesMm: cPanels,
      suitStyle: 'full',
    );
    expect(a, isNot(c));
  });
}
