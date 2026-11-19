import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_routes.dart';

/// The sets pane and the old set edit address open the set page unlocked
/// behind phase 3's switch (issue #4527), and keep the form without it.
void main() {
  testWidgets('with the switch the pane edits on the set page, unlocked', (
    tester,
  ) async {
    var cancelled = 0;
    final builder = equipmentSetsPaneEditBuilder(unlockEditing: true)!;
    late Widget pane;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          pane = builder(context, 's1', (_) {}, () => cancelled++);
          return const SizedBox();
        },
      ),
    );

    expect(pane, isA<EquipmentSetDetailPage>());
    final page = pane as EquipmentSetDetailPage;
    expect(page.setId, 's1');
    expect(page.openUnlocked, isTrue);
    expect(page.unlockEditing, isTrue);
    page.onSittingEnded!();
    expect(cancelled, 1);
  });

  test('with the switch off the pane has no edit mode', () {
    expect(equipmentSetsPaneEditBuilder(unlockEditing: false), isNull);
  });
}
