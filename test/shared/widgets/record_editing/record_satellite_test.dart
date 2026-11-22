import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_pane_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import 'fake_note_record.dart';

/// A satellite page (a passport, the cylinder board) is a page of its
/// record holding some of its cards (issue #4527, phase 3). Pushed during
/// the record's sitting it joins it; otherwise it has a lock of its own.
void main() {
  final l = AppLocalizationsEn();

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openSatellite(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('openSatellite')));
    await tester.pumpAndSettle();
  }

  Future<void> editExtra(WidgetTester tester, String extra) async {
    await tester.tap(find.text('Extra'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('extraEditor')), extra);
    await tester.pumpAndSettle();
  }

  /// The bar's Done, not an open card's.
  Finder barDone() => find.descendant(
    of: find.byType(RecordSatelliteBar),
    matching: find.text(l.common_action_done),
  );

  FakeNotePageState parent(WidgetTester tester) =>
      tester.state(find.byType(FakeNotePage, skipOffstage: false));

  // A satellite's route is not a page, so its exit blocker answers for the
  // record page it was pushed from: leaving that page asks about a sitting
  // the satellite holds on its own.
  testWidgets('a satellite is on the page of the record it was pushed '
      'from', (tester) async {
    Object? satellitePage;
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onDidRemovePage: (_) {},
          pages: [
            MaterialPage<void>(
              key: const ValueKey('record'),
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => pushRecordSatellite<FakeNote, void>(
                    context,
                    rootNavigator: false,
                    builder: (_) => Builder(
                      builder: (context) {
                        satellitePage = recordSittingPageOf(context);
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(satellitePage, const ValueKey('record'));
  });

  testWidgets("pushed during the parent's sitting it joins it", (tester) async {
    final probe = await pumpFakeNotes(tester, const FakeNotePage());
    await unlock(tester);
    await openSatellite(tester);

    expect(find.byType(RecordSatelliteBar), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await editExtra(tester, 'Half');
    await tester.tap(barDone());
    await tester.pumpAndSettle();

    expect(find.byType(FakeSatellitePage), findsNothing);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(parent(tester).editController.isDirty, isTrue);
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
    expect(probe.saves, [
      {'extra'},
    ]);
    expect(probe.notes['n1']!.extra, 'Half');
  });

  testWidgets('Done with a card that fails its check stays', (tester) async {
    await pumpFakeNotes(tester, const FakeNotePage());
    await unlock(tester);
    await openSatellite(tester);
    await editExtra(tester, 'bad');

    await tester.tap(barDone());
    await tester.pumpAndSettle();

    expect(find.byType(FakeSatellitePage), findsOneWidget);
    expect(find.text(l.recordEdit_fixInvalid), findsOneWidget);
    expect(parent(tester).isSittingOpen, isTrue);
  });

  testWidgets('leaving a joined satellite asks nothing', (tester) async {
    await pumpFakeNotes(tester, const FakeNotePage());
    await unlock(tester);
    await openSatellite(tester);
    await editExtra(tester, 'Half');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(FakeSatellitePage), findsNothing);
    expect(
      parent(tester).editController.session!.valueOf(fakeExtraField),
      'Half',
    );
  });

  testWidgets("the parent's sitting stays open while the satellite is on top", (
    tester,
  ) async {
    await pumpFakeNotes(tester, const FakeNotePage());
    await unlock(tester);
    await openSatellite(tester);
    expect(parent(tester).isSittingOpen, isTrue);

    await editExtra(tester, 'Half');

    expect(parent(tester).isSittingOpen, isTrue);
    expect(parent(tester).editController.openCardIds, contains('extra'));
  });

  testWidgets('pushed from a locked parent it has its own lock', (
    tester,
  ) async {
    final probe = await pumpFakeNotes(tester, const FakeNotePage());
    await openSatellite(tester);

    expect(find.byType(RecordSatelliteBar), findsNothing);
    await unlock(tester);
    expect(find.byType(RecordEditBar), findsOneWidget);
    await editExtra(tester, 'Half');
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(probe.saves, [
      {'extra'},
    ]);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(parent(tester).isSittingOpen, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('parentExtra')), findsOneWidget);
    expect(find.text('Half'), findsOneWidget);
  });

  testWidgets('opened alone it opens locked', (tester) async {
    final probe = await pumpFakeNotes(tester, const FakeSatellitePage());

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.tap(find.text('Extra'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('extraEditor')), findsNothing);
    expect(probe.saves, isEmpty);
  });

  testWidgets(
    'a joined sitting locked underneath leaves the satellite reading only',
    (tester) async {
      await pumpFakeNotes(tester, const FakeNotePage());
      await unlock(tester);
      await openSatellite(tester);

      parent(tester).editController.lock();
      await tester.pumpAndSettle();

      expect(barDone(), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    },
  );

  /// A sitting made here, unlocked on the stored note, as a record page's
  /// would be; disposed after the page has gone.
  RecordEditController<FakeNote> sittingOn(
    WidgetTester tester,
    FakeNoteProbe probe, {
    bool unlocked = true,
  }) {
    final controller = RecordEditController<FakeNote>(onSave: (_) async {});
    if (unlocked) controller.unlock(probe.notes['n1']!);
    addTearDown(controller.dispose);
    return controller;
  }

  testWidgets('Done leaves open the cards the record page had open', (
    tester,
  ) async {
    await pumpFakeNotes(tester, const FakeNotePage());
    await unlock(tester);
    parent(tester).editController.openCard('extra');
    await tester.pumpAndSettle();
    await openSatellite(tester);

    await tester.tap(barDone());
    await tester.pumpAndSettle();

    expect(find.byType(FakeSatellitePage), findsNothing);
    expect(parent(tester).editController.openCardIds, contains('extra'));
  });

  testWidgets('a satellite handed another sitting follows it', (tester) async {
    final probe = await pumpFakeNotes(tester, const SizedBox.shrink());
    final first = sittingOn(tester, probe, unlocked: false);
    final second = sittingOn(tester, probe);
    late StateSetter swap;
    var joined = first;
    await tester.pumpWidget(
      fakeNotesApp(
        probe,
        StatefulBuilder(
          builder: (context, setState) {
            swap = setState;
            return FakeSatellitePage(joined: joined);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecordSatelliteBar), findsNothing);

    swap(() => joined = second);
    await tester.pumpAndSettle();
    expect(find.byType(RecordSatelliteBar), findsOneWidget);
    second.lock();
    await tester.pumpAndSettle();

    expect(find.byType(RecordSatelliteBar), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Done waits while the sitting is busy', (tester) async {
    await pumpFakeNotes(tester, const FakeNotePage());
    await unlock(tester);
    await openSatellite(tester);
    await tester.tap(find.text('Extra'));
    await tester.pumpAndSettle();
    final gate = Completer<bool>();
    unawaited(parent(tester).editController.runOperation(() => gate.future));
    await tester.pump();

    await tester.tap(barDone());
    await tester.pump();

    expect(find.text(l.recordEdit_fixInvalid), findsNothing);
    expect(find.byType(FakeSatellitePage), findsOneWidget);
    gate.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('a joined satellite in a pane shows Done and asks nothing', (
    tester,
  ) async {
    final probe = await pumpFakeNotes(tester, const SizedBox.shrink());
    final sitting = sittingOn(tester, probe);
    await tester.pumpWidget(
      fakeNotesApp(
        probe,
        Scaffold(body: FakeSatellitePage(joined: sitting, embedded: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RecordSatelliteBar), findsOneWidget);
    expect(find.byType(RecordEditPaneHeader), findsNothing);
    expect(find.byType(RecordEditLeaveGuard<FakeNote>), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the editing keys finish a joined satellite', (tester) async {
    await pumpFakeNotes(tester, const FakeNotePage());
    await unlock(tester);
    await openSatellite(tester);
    final targets = ProviderScope.containerOf(
      tester.element(find.byType(FakeSatellitePage)),
    ).read(recordEditShortcutTargetsProvider);

    final target = targets.current;
    expect(target, isNotNull);
    expect(target!.controller, same(parent(tester).editController));
    target.cancel();
    await tester.pumpAndSettle();

    expect(find.byType(FakeSatellitePage), findsNothing);
    expect(parent(tester).isSittingOpen, isTrue);
  });

  testWidgets('the satellite bar looks like the edit bar', (tester) async {
    await pumpFakeNotes(
      tester,
      Scaffold(
        appBar: RecordEditBar(
          title: 'Edit',
          canSave: false,
          isSaving: false,
          onCancel: () {},
          onSave: () {},
        ),
        body: RecordSatelliteBar(title: 'Satellite', onDone: () {}),
      ),
    );
    final bars = tester.widgetList<AppBar>(find.byType(AppBar)).toList();

    expect(bars, hasLength(2));
    expect(bars[1].backgroundColor, bars[0].backgroundColor);
    expect(bars[1].foregroundColor, bars[0].foregroundColor);
    expect(bars[1].shape, bars[0].shape);
  });

  testWidgets("opened from the page's own bar it joins the sitting", (
    tester,
  ) async {
    await pumpFakeNotes(tester, const FakeNotePage());
    await unlock(tester);

    await tester.tap(find.byKey(const ValueKey('barSatellite')));
    await tester.pumpAndSettle();

    expect(find.byType(RecordSatelliteBar), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('a page that starts joining a sitting ends its own', (
    tester,
  ) async {
    final probe = await pumpFakeNotes(tester, const SizedBox.shrink());
    final sitting = sittingOn(tester, probe);
    late StateSetter swap;
    RecordEditController<FakeNote>? joined;
    await tester.pumpWidget(
      fakeNotesApp(
        probe,
        StatefulBuilder(
          builder: (context, setState) {
            swap = setState;
            return FakeSatellitePage(joined: joined);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await unlock(tester);
    await editExtra(tester, 'Half');

    swap(() => joined = sitting);
    await tester.pumpAndSettle();

    expect(find.byType(RecordSatelliteBar), findsOneWidget);
    final guard = ProviderScope.containerOf(
      tester.element(find.byType(FakeSatellitePage)),
    ).read(appExitGuardProvider);
    expect(await guard.mayLeave(), isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a joined satellite handed another record stops joining', (
    tester,
  ) async {
    final probe = await pumpFakeNotes(tester, const SizedBox.shrink());
    final sitting = sittingOn(tester, probe);
    late StateSetter swap;
    var noteId = 'n1';
    await tester.pumpWidget(
      fakeNotesApp(
        probe,
        StatefulBuilder(
          builder: (context, setState) {
            swap = setState;
            return FakeSatellitePage(noteId: noteId, joined: sitting);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecordSatelliteBar), findsOneWidget);

    swap(() => noteId = 'n2');
    await tester.pumpAndSettle();

    // The sitting is n1's: the page shows n2 locked, on a lock of its own.
    final state = tester.state<FakeSatellitePageState>(
      find.byType(FakeSatellitePage),
    );
    expect(find.byType(RecordSatelliteBar), findsNothing);
    expect(state.maybeEditController, isNot(same(sitting)));
    expect(state.isSittingOpen, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a satellite whose ended sitting was another record has a lock', (
    tester,
  ) async {
    final probe = await pumpFakeNotes(tester, const SizedBox.shrink());
    final sitting = sittingOn(tester, probe);
    late StateSetter swap;
    var noteId = 'n1';
    await tester.pumpWidget(
      fakeNotesApp(
        probe,
        StatefulBuilder(
          builder: (context, setState) {
            swap = setState;
            return FakeSatellitePage(noteId: noteId, joined: sitting);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The record's page ends its sitting, then the page shows another.
    sitting.lock();
    await tester.pumpAndSettle();

    swap(() => noteId = 'n2');
    await tester.pumpAndSettle();

    final state = tester.state<FakeSatellitePageState>(
      find.byType(FakeSatellitePage),
    );
    expect(state.maybeEditController, isNot(same(sitting)));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
