import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_routes.dart';

/// The sets pane and the old set edit address open the set page unlocked
/// (issue #4527).
void main() {
  testWidgets('the pane edits on the set page, unlocked', (tester) async {
    var cancelled = 0;
    final builder = equipmentSetsPaneEditBuilder();
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
    page.onSittingEnded!();
    expect(cancelled, 1);
  });

  testWidgets('the old edit address opens the set page unlocked', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/equipment/sets/s1/edit',
      routes: [
        GoRoute(
          path: '/equipment/sets/:setId',
          builder: (_, state) => Text('set page ${state.uri}'),
          routes: [GoRoute(path: 'edit', redirect: equipmentSetEditRedirect)],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('set page /equipment/sets/s1?mode=edit'), findsOneWidget);
    expect(equipmentSetEditLocation('s1'), '/equipment/sets/s1?mode=edit');
  });
}
