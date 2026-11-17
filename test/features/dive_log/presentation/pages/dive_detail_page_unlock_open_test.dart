import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/app/app_exit_guard.dart';

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

  // A delete ends the sitting (the dive is gone) and leaves the page: the
  // pane goes back to the list, and must not be sent back to the deleted
  // dive by the sitting's end.
  testWidgets('a dive deleted from a page opened unlocked reports no '
      'sitting end', (tester) async {
    var ended = 0;
    var deleted = 0;
    await pumpPage(
      tester,
      initialLocation: '/pane-edit',
      // The read after the delete fails, which ends the sitting, as a read
      // of a dive that is gone does.
      reloadError: () => StateError('dive gone'),
      routes: [
        GoRoute(
          path: '/pane-edit',
          builder: (context, state) => Scaffold(
            body: DiveDetailPage(
              diveId: dive.id,
              embedded: true,
              openUnlocked: true,
              onSittingEnded: () => ended++,
              onDeleted: () => deleted++,
            ),
          ),
        ),
      ],
      extra: [
        paginatedDiveListProvider.overrideWith(
          (ref) => _SpyList(ref.watch(diveRepositoryProvider), ref),
        ),
      ],
    );
    await settle(tester);
    expect(saveAction(), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate((w) => w is PopupMenuButton<String>).last,
    );
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    await settle(tester);

    expect(deleted, 1);
    expect(ended, 0);
  });

  // A leave that asks first (another row, a tab) ends the sitting and then
  // navigates. The pane is moving on, and must not be sent back to the
  // dive: no report, however late the router applies the leave.
  testWidgets('a sitting discarded by a leave that asked reports nothing', (
    tester,
  ) async {
    var ended = 0;
    final page = await pumpPage(
      tester,
      openUnlocked: true,
      onSittingEnded: () => ended++,
    );
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

    final guard = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).read(appExitGuardProvider);
    final leaving = guard.mayLeave();
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(await leaving, isTrue);
    page.router.go('/home');
    await settle(tester);

    expect(ended, 0);
  });
  // On a desktop window a root visit moves into the list pane: an edit
  // address must arrive there still asking for edit mode, or the dive
  // opens locked.
  testWidgets('a desktop deep link moves into the pane in edit mode', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      openUnlocked: true,
      size: const Size(1400, 1000),
      initialLocation: '/root-dive',
    );
    await settle(tester);

    final landed = page.router.routerDelegate.currentConfiguration.uri;
    expect(landed.path, '/dives');
    expect(landed.queryParameters['selected'], dive.id);
    expect(landed.queryParameters['mode'], 'edit');
  });

  // The edit the address asked for is over once its sitting ends: a window
  // widened afterwards moves the dive into the pane as it is, locked.
  testWidgets('widened after its sitting ended, the page moves into the '
      'pane without edit mode', (tester) async {
    final page = await pumpPage(
      tester,
      openUnlocked: true,
      size: const Size(700, 1000),
      initialLocation: '/root-dive',
    );
    await settle(tester);
    expect(saveAction(), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppBarTextAction && w.label == 'Cancel',
      ),
    );
    await settle(tester);

    tester.view.physicalSize = const Size(1400, 1000);
    await settle(tester);

    final landed = page.router.routerDelegate.currentConfiguration.uri;
    expect(landed.path, '/dives');
    expect(landed.queryParameters['selected'], dive.id);
    expect(landed.queryParameters.containsKey('mode'), isFalse);
  });

  // A leave that discards a sitting the diver unlocked by hand ends no
  // sitting the page opened, so it must not swallow the end of the next one.
  testWidgets('a leave after a hand-made sitting does not hide the next '
      "opened sitting's end", (tester) async {
    var ended = 0;
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
            builder: (context, value, _) => DiveDetailPage(
              diveId: dive.id,
              openUnlocked: value,
              onSittingEnded: () => ended++,
            ),
          ),
        ),
      ],
    );
    await settle(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Changed',
    );
    await settle(tester);
    final guard = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).read(appExitGuardProvider);
    final leaving = guard.mayLeave();
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(await leaving, isTrue);
    expect(lock(), findsOneWidget);

    open.value = true;
    await settle(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppBarTextAction && w.label == 'Cancel',
      ),
    );
    await settle(tester);

    expect(ended, 1);
  });

  // The address dropping mode=edit on the same page (Android Back's shell
  // fallback strips it) locks a sitting with nothing to lose.
  for (final changed in [false, true]) {
    testWidgets(
      'openUnlocked turning off ${changed ? 'keeps a sitting with '
                'changes' : 'locks a clean sitting'}',
      (tester) async {
        final open = ValueNotifier(true);
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
        expect(saveAction(), findsOneWidget);
        if (changed) {
          await openNotes(tester);
          await tester.enterText(
            find.descendant(
              of: find.byType(MarkdownNotesField),
              matching: find.byType(TextField),
            ),
            'Changed',
          );
          await settle(tester);
        }

        open.value = false;
        await settle(tester);

        expect(saveAction(), changed ? findsOneWidget : findsNothing);
        expect(lock(), changed ? findsNothing : findsOneWidget);
      },
    );
  }

  testWidgets('neither bar has an Edit button', (tester) async {
    await pumpPage(tester);
    expect(find.byTooltip('Edit dive'), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);

    await pumpPage(tester, embedded: true, size: const Size(900, 1000));
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
  });
}

/// Deletes nothing, so the stored dive stays readable for the page.
class _SpyList extends PaginatedDiveListNotifier {
  _SpyList(super.repository, super.ref);

  @override
  Future<void> deleteDive(String id) async {}
}
