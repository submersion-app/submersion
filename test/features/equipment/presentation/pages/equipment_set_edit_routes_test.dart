import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_router/go_router.dart';

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

  testWidgets('the old edit address keeps the form without the switch', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/equipment/sets/s1/edit',
      routes: [
        GoRoute(
          path: '/equipment/sets/:setId',
          builder: (_, _) => const Text('set page'),
          routes: [
            GoRoute(
              path: 'edit',
              redirect: equipmentSetEditRedirect,
              builder: (_, _) => const Text('set form'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // The build switch is off in tests: the form stays.
    expect(find.text('set form'), findsOneWidget);
    expect(equipmentSetEditLocation('s1'), isNull);
  });
}
