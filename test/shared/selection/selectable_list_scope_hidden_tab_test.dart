import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';

/// A list selecting in a tab the diver cannot see must not swallow Back:
/// Back would end a selection nobody can see, and nothing visible happens
/// (#3437).
void main() {
  Future<SelectionController> pumpSelectingRoute(
    WidgetTester tester, {
    required bool visible,
  }) async {
    final controller = SelectionController();
    addTearDown(controller.dispose);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: TabVisibility(
            visible: visible,
            child: SelectableListScope(
              controller: controller,
              selectableIds: const ['a', 'b'],
              child: const Text('list'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.enterImplicit('a');
    await tester.pump();
    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('a hidden tab lets Back leave the page', (tester) async {
    await pumpSelectingRoute(tester, visible: false);

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a shown tab still ends its selection on Back', (tester) async {
    final controller = await pumpSelectingRoute(tester, visible: true);

    expect(find.text('list'), findsOneWidget);
    expect(controller.value.isActive, isFalse);
  });
}
