import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The old edit addresses (`/dives/<id>/edit`, the pane's `&mode=edit`) open
/// the dive page already unlocked, and neither bar has an Edit button
/// (issue #4527, plan 11).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Finder lock() => find.byTooltip('Unlock to edit');
  Finder saveAction() =>
      find.byWidgetPredicate((w) => w is AppBarTextAction && w.label == 'Save');

  testWidgets('opened unlocked, the page shows Cancel and Save', (
    tester,
  ) async {
    await pumpPage(tester, openUnlocked: true);
    await settle(tester);

    expect(action(tester, 'Save'), isNotNull);
    expect(action(tester, 'Cancel'), isNotNull);
    expect(lock(), findsNothing);
  });

  testWidgets('saved, then rebuilt, it stays locked', (tester) async {
    await pumpPage(tester, openUnlocked: true);
    await settle(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Changed',
    );
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(lock(), findsOneWidget);

    tester.view.physicalSize = const Size(720, 1000);
    addTearDown(tester.view.reset);
    await settle(tester);

    expect(lock(), findsOneWidget);
    expect(saveAction(), findsNothing);
  });

  testWidgets('a dive that cannot be read stays locked and throws nothing', (
    tester,
  ) async {
    await pumpPage(
      tester,
      initialLocation: '/gone',
      routes: [
        GoRoute(
          path: '/gone',
          builder: (context, state) =>
              const DiveDetailPage(diveId: 'gone', openUnlocked: true),
        ),
      ],
      extra: [diveProvider('gone').overrideWith((ref) async => null)],
    );
    await settle(tester);

    expect(find.text('Dive not found'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(saveAction(), findsNothing);
  });

  testWidgets('openUnlocked turning on for a page already showing the dive '
      'unlocks it', (tester) async {
    final open = ValueNotifier(false);
    addTearDown(open.dispose);
    await pumpPage(
      tester,
      initialLocation: '/live',
      routes: [
        GoRoute(
          path: '/live',
          builder: (context, state) => ValueListenableBuilder<bool>(
            valueListenable: open,
            builder: (context, value, _) =>
                DiveDetailPage(diveId: dive.id, openUnlocked: value),
          ),
        ),
      ],
    );
    await settle(tester);
    expect(lock(), findsOneWidget);

    open.value = true;
    await settle(tester);

    expect(saveAction(), findsOneWidget);
  });

  testWidgets('onSittingEnded fires once when Cancel ends the opened sitting', (
    tester,
  ) async {
    var ended = 0;
    await pumpPage(tester, openUnlocked: true, onSittingEnded: () => ended++);
    await settle(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppBarTextAction && w.label == 'Cancel',
      ),
    );
    await settle(tester);
    expect(ended, 1);

    tester.view.physicalSize = const Size(720, 1000);
    addTearDown(tester.view.reset);
    await settle(tester);
    expect(ended, 1);
  });

  testWidgets('neither bar has an Edit button', (tester) async {
    await pumpPage(tester);
    expect(find.byTooltip('Edit dive'), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);

    await pumpPage(tester, embedded: true, size: const Size(900, 1000));
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
  });
}
