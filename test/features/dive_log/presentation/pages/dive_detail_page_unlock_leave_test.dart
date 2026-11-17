import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// Leaving a sitting with unsaved changes asks first, by every way out:
/// another tab, Back (issue #4527, plan 7).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> change(WidgetTester tester) async {
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(find.byType(TextField).first, 'Choppy');
    await settle(tester);
  }

  testWidgets('another tab with unsaved changes asks; Keep editing stays on '
      'the dive', (tester) async {
    final page = await pumpPage(tester);
    await change(tester);

    page.router.go('/home');
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);

    expect(location(page.router), '/home/dive');
    expect(action(tester, 'Save').onPressed, isNotNull);
  });

  testWidgets('Discard leaves', (tester) async {
    final page = await pumpPage(tester);
    await change(tester);

    page.router.go('/home');
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(location(page.router), '/home');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('another tab with no changes leaves at once', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);

    page.router.go('/home');
    await settle(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(location(page.router), '/home');
  });

  testWidgets('Back from a page pushed above leaves the sitting below alone', (
    tester,
  ) async {
    // As Open full page from the list pane: the pushed page is left, the
    // page beneath it stays, so its unsaved changes are not in question.
    final page = await pumpPage(tester);
    await change(tester);
    unawaited(page.router.push('/home/dive'));
    await settle(tester);
    expect(find.text('Discard changes?'), findsNothing);

    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(location(page.router), '/home/dive');
    expect(action(tester, 'Save').onPressed, isNotNull);
  });

  testWidgets('Back on the full page asks once, not twice', (tester) async {
    final page = await pumpPage(tester);
    await change(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(location(page.router), '/home');
  });
}
