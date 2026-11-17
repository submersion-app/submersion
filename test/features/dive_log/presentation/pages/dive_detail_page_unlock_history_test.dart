import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_hero_section.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// History is not a whole-record operation: it opens during a sitting, as
/// the unlocked menu's first item, and the page it pushes comes back to the
/// same sitting with its changes (issue #4527, plan 7).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  // Stands in for the change log, which History pushes.
  final history = GoRoute(
    path: '/settings/change-log',
    builder: (context, state) => Scaffold(
      body: Text(
        'HISTORY ${state.uri.queryParameters['rootTable']} '
        '${state.uri.queryParameters['rootId']}',
      ),
    ),
  );

  RecordEditController<Dive> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Dive>(
        tester.element(find.byType(DiveDetailHeroSection)),
      )!;

  for (final (name, embedded, size) in [
    ('the full page', false, const Size(700, 1000)),
    ('the list pane', true, const Size(1200, 1000)),
  ]) {
    testWidgets('$name: History pushed during a sitting comes back to the '
        'same sitting', (tester) async {
      final page = await pumpPage(
        tester,
        embedded: embedded,
        size: size,
        routes: [history],
      );
      await unlock(tester);
      await openNotes(tester);
      await tester.enterText(find.byType(TextField).first, 'Choppy');
      await settle(tester);
      final before = controllerOf(tester).session;

      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuButton<String>).last,
      );
      await settle(tester);
      await tester.tap(find.text('History'));
      await settle(tester);

      expect(find.text('HISTORY dives ${dive.id}'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);

      page.router.pop();
      await settle(tester);

      expect(location(page.router), '/home/dive');
      final controller = controllerOf(tester);
      expect(controller.session, same(before));
      expect(controller.session!.working.notes, 'Choppy');
      expect(action(tester, 'Save').onPressed, isNotNull);
      expect(page.save.calls, isEmpty);
    });
  }
}
