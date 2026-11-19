import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite_bar.dart';

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
}
