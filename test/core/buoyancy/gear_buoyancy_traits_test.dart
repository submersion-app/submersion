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

  test('value equality', () {
    const a = GearBuoyancyTraits(
      primaryThicknessMm: 5,
      panelThicknessesMm: [5, 4],
      suitStyle: 'full',
    );
    const b = GearBuoyancyTraits(
      primaryThicknessMm: 5,
      panelThicknessesMm: [5, 4],
      suitStyle: 'full',
    );
    expect(a, b);
  });
}
