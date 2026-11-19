import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_routes.dart';

/// The gear item's edit addresses and panes behind phase 3's switch (issue
/// #4527, plan 6).
void main() {
  test('the edit address redirects with the switch on, not off', () {
    expect(
      gearItemEditLocation('g1', unlockEditing: true),
      '/equipment/g1?mode=edit',
    );
    expect(gearItemEditLocation('g1', unlockEditing: false), isNull);
  });

  test('on a wide screen, mode=edit moves into the pane unlocked', () {
    expect(
      gearItemPaneLocation('g1', openUnlocked: true),
      '/equipment?selected=g1&mode=edit',
    );
    expect(gearItemPaneLocation('g1'), '/equipment?selected=g1');
  });

  testWidgets('the pane is the item page, unlocked, with the switch on', (
    tester,
  ) async {
    late Widget pane;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          pane = gearItemEditPane(
            context,
            'g1',
            (_) {},
            () {},
            unlockEditing: true,
          );
          return const SizedBox();
        },
      ),
    );

    expect(pane, isA<EquipmentDetailPage>());
    final page = pane as EquipmentDetailPage;
    expect(page.openUnlocked, isTrue);
    expect(page.embedded, isTrue);
  });

  testWidgets('with the switch off the pane opens the form', (tester) async {
    late Widget pane;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          pane = gearItemEditPane(
            context,
            'g1',
            (_) {},
            () {},
            unlockEditing: false,
          );
          return const SizedBox();
        },
      ),
    );

    expect(pane, isA<EquipmentEditPage>());
  });
}
