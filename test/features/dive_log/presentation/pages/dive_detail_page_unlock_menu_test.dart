import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

class _PreDiveRepo extends Fake implements PreDiveSessionRepository {
  final unlinked = <String>[];

  @override
  Future<void> unlinkFromDive(String sessionId) async =>
      unlinked.add(sessionId);
}

class _SpyList extends PaginatedDiveListNotifier {
  _SpyList(super.repository, super.ref);

  final deleted = <String>[];

  @override
  Future<void> deleteDive(String id) async => deleted.add(id);
}

class _FailingList extends PaginatedDiveListNotifier {
  _FailingList(super.repository, super.ref);

  @override
  Future<void> deleteDive(String id) async => throw StateError('disk full');
}

final _linked = PreDiveSession(
  id: 'pre-1',
  templateName: 'Boat',
  diveId: dive.id,
  startedAt: DateTime(2023, 1, 1, 8),
  createdAt: DateTime(2023, 1, 1, 8),
  updatedAt: DateTime(2023, 1, 1, 8),
);

RecordEditController<Dive> _controller(WidgetTester tester) => tester
    .widget<RecordEditScope<Dive>>(
      find.byWidgetPredicate((w) => w is RecordEditScope<Dive>).first,
    )
    .notifier!;

Finder get _menuButton =>
    find.byWidgetPredicate((w) => w is PopupMenuButton<String>);

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(_menuButton.last);
  await settle(tester);
}

bool _enabled(WidgetTester tester, String label) => tester
    .widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem<String>),
      ),
    )
    .enabled;

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('locked: operations disabled under the caption', (tester) async {
    await pumpPage(tester);
    await _openMenu(tester);

    expect(find.text('Unlock to use these'), findsOneWidget);
    expect(_enabled(tester, 'Delete'), isFalse);
    expect(_enabled(tester, 'Export'), isTrue);
  });

  testWidgets('History beside the lock leaves it out of the menu', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byTooltip('History'), findsOneWidget);
    await _openMenu(tester);
    expect(find.text('History'), findsNothing);
  });

  testWidgets('History is the menu\'s first item at phone width', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(560, 1000));
    expect(find.byTooltip('History'), findsNothing);
    await _openMenu(tester);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('the unlocked bar carries the menu between the title and Save', (
    tester,
  ) async {
    await pumpPage(tester);
    await unlock(tester);

    final bar = find.byType(RecordEditBar);
    final menu = find.descendant(of: bar, matching: _menuButton);
    expect(menu, findsOneWidget);
    final save = find.descendant(of: bar, matching: find.text('Save'));
    expect(tester.getCenter(menu).dx, lessThan(tester.getCenter(save).dx));
    await tester.tap(menu);
    await settle(tester);
    expect(find.text('History'), findsOneWidget);
    expect(_enabled(tester, 'Delete'), isTrue);
    expect(find.byKey(const ValueKey('recordOperationCaption')), findsNothing);
  });

  testWidgets('with a change the unlocked menu says save or cancel first', (
    tester,
  ) async {
    await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(find.byType(TextField).first, 'Choppy');
    await settle(tester);

    await _openMenu(tester);

    expect(find.text('Save or cancel your changes first'), findsOneWidget);
    expect(_enabled(tester, 'Delete'), isFalse);
  });

  testWidgets('the bar does not change height on unlock', (tester) async {
    await pumpPage(tester);
    final locked = tester.getSize(find.byType(AppBar)).height;
    await unlock(tester);
    expect(tester.getSize(find.byType(AppBar)).height, locked);
  });

  testWidgets('unlinking the pre-dive checklist from the unlocked menu runs, '
      'and the sitting starts again', (tester) async {
    final repo = _PreDiveRepo();
    await pumpPage(
      tester,
      extra: [
        preDiveSessionForDiveProvider(
          dive.id,
        ).overrideWith((ref) async => _linked),
        preDiveSessionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await unlock(tester);
    final before = _controller(tester).session;

    await _openMenu(tester);
    await tester.tap(find.text('Unlink pre-dive checklist'));
    await settle(tester);
    await settle(tester);

    expect(repo.unlinked, ['pre-1']);
    final controller = _controller(tester);
    expect(controller.isUnlocked, isTrue);
    expect(controller.session, isNot(same(before)));
    expect(controller.isDirty, isFalse);
  });

  testWidgets('deleting from a sitting deletes and leaves without asking', (
    tester,
  ) async {
    late _SpyList list;
    final page = await pumpPage(
      tester,
      extra: [
        paginatedDiveListProvider.overrideWith(
          (ref) => list = _SpyList(ref.watch(diveRepositoryProvider), ref),
        ),
      ],
    );
    await unlock(tester);

    await _openMenu(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    await settle(tester);

    expect(list.deleted, [dive.id]);
    expect(find.text('Discard changes?'), findsNothing);
    expect(location(page.router), '/home');
  });

  // The dive is read again after an operation writes; after a delete that
  // read failing must not keep the page on a dive that is gone.
  testWidgets('a delete whose read back fails still leaves the page', (
    tester,
  ) async {
    late _SpyList list;
    final page = await pumpPage(
      tester,
      reloadError: () => StateError('database closed'),
      extra: [
        paginatedDiveListProvider.overrideWith(
          (ref) => list = _SpyList(ref.watch(diveRepositoryProvider), ref),
        ),
      ],
    );
    await unlock(tester);

    await _openMenu(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(list.deleted, [dive.id]);
    expect(find.text('Discard changes?'), findsNothing);
    expect(location(page.router), '/home');
  });

  testWidgets('a delete that fails stays on the page, and nothing is thrown', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      extra: [
        paginatedDiveListProvider.overrideWith(
          (ref) => _FailingList(ref.watch(diveRepositoryProvider), ref),
        ),
      ],
    );
    await unlock(tester);

    await _openMenu(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(location(page.router), '/home/dive');
    final controller = _controller(tester);
    expect(controller.isUnlocked, isTrue);
    expect(controller.isBusy, isFalse);
  });
}
