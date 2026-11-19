import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'fake_note_record.dart';

/// A record page with tabs (a trip's six) keeps one sitting across them
/// (issue #4527, phase 3): the strip offers the tab in view, open cards and
/// what is typed in them survive a visit to another tab, and a card asked
/// to show itself brings its tab forward.
void main() {
  final l = AppLocalizationsEn();

  Future<FakeNoteProbe> pump(
    WidgetTester tester, {
    String noteId = 'n1',
    FakeTabDisposals? disposals,
  }) => pumpFakeNotes(
    tester,
    FakeTabbedPage(noteId: noteId, disposals: disposals ?? FakeTabDisposals()),
  );

  FakeTabbedPageState page(WidgetTester tester) =>
      tester.state(find.byType(FakeTabbedPage));

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  /// A focused text field keeps its tab alive by itself; the diver has
  /// usually left the field before changing tab, so the tests do too.
  Future<void> showTab(WidgetTester tester, String name) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Finder inStrip(String label) =>
      find.descendant(of: find.byType(AddStrip), matching: find.text(label));

  Future<void> typeText(WidgetTester tester, String text) async {
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('checkedEditor')), text);
    await tester.pumpAndSettle();
  }

  testWidgets('the strip offers the tab in view', (tester) async {
    await pump(tester, noteId: 'n2');
    await unlock(tester);

    expect(inStrip('Text'), findsOneWidget);
    expect(inStrip('Extra'), findsNothing);
    await showTab(tester, 'Two');
    expect(inStrip('Extra'), findsOneWidget);
    expect(inStrip('Text'), findsNothing);
  });

  testWidgets('an open card survives a visit to the other tab', (tester) async {
    await pump(tester);
    await unlock(tester);
    await typeText(tester, 'half');

    await showTab(tester, 'Two');
    await showTab(tester, 'One');

    expect(find.byKey(const ValueKey('checkedEditor')), findsOneWidget);
    expect(find.text('half'), findsOneWidget);
  });

  testWidgets('unreadable input survives a visit to the other tab', (
    tester,
  ) async {
    await pump(tester);
    await unlock(tester);
    // A readable change first, so the sitting has something to save.
    await typeText(tester, 'half');
    await tester.enterText(find.byKey(const ValueKey('checkedEditor')), '12a');
    await tester.pumpAndSettle();

    await showTab(tester, 'Two');
    await showTab(tester, 'One');

    expect(find.text('12a'), findsOneWidget);
    expect(page(tester).editController.invalidCardIds, {'text'});
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
    expect(page(tester).isSittingOpen, isTrue);
    expect(page(tester).editController.refusedForInvalidInput, isTrue);
  });

  testWidgets('Save refused for a card on the other tab shows that tab', (
    tester,
  ) async {
    final probe = await pump(tester);
    await unlock(tester);
    page(tester).editController.session!.set(fakeExtraField, 'bad');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(probe.saves, isEmpty);
    expect(page(tester).tabs.index, 1);
    expect(find.byKey(const ValueKey('extraEditor')), findsOneWidget);
    // The tab view rests on that tab, not part way: the card's scroll into
    // view must not move the pages.
    final pages = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      pages.position.pixels,
      tester.getSize(find.byType(TabBarView)).width,
    );
  });

  testWidgets('Save refused for unreadable input on the other tab shows it', (
    tester,
  ) async {
    await pump(tester);
    await unlock(tester);
    await typeText(tester, 'half');
    await tester.enterText(find.byKey(const ValueKey('checkedEditor')), '12a');
    await tester.pumpAndSettle();
    await showTab(tester, 'Two');

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(page(tester).tabs.index, 0);
    expect(find.byKey(const ValueKey('checkedEditor')), findsOneWidget);
    expect(find.text('12a'), findsOneWidget);
  });

  testWidgets('locked, an off-screen tab is not kept', (tester) async {
    final disposals = FakeTabDisposals();
    await pump(tester, disposals: disposals);

    await showTab(tester, 'Two');

    expect(disposals.count, 1);
  });

  testWidgets('a page handed another sitting still moves to its card', (
    tester,
  ) async {
    final probe = await pump(tester);
    // The page's own sitting serves a first request on the second tab.
    await unlock(tester);
    page(tester).editController.session!.set(fakeExtraField, 'bad');
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
    expect(page(tester).tabs.index, 1);
    await showTab(tester, 'One');
    // Then it joins another sitting, whose own first request is also its
    // first.
    final other = RecordEditController<FakeNote>(
      onSave: (_) async {},
      invalidCards: (session) => [
        if (session.valueOf(fakeExtraField) == 'bad') 'extra',
      ],
    );
    addTearDown(other.dispose);
    other.unlock(probe.notes['n1']!);
    await tester.pumpWidget(
      fakeNotesApp(
        probe,
        FakeTabbedPage(disposals: FakeTabDisposals(), joined: other),
      ),
    );
    await tester.pumpAndSettle();
    expect(page(tester).tabs.index, 0);

    other.session!.set(fakeExtraField, 'bad');
    await other.save();
    await tester.pumpAndSettle();

    expect(page(tester).tabs.index, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
