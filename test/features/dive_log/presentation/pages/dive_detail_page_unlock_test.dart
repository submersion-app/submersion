import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// A dive list whose refresh after a write fails.
class _FailingRefreshList extends PaginatedDiveListNotifier {
  _FailingRefreshList(super.repository, super.ref);

  @override
  Future<void> refreshAfterWrite({
    required Dive? before,
    required Dive after,
  }) async => throw StateError('the list could not be refreshed');
}

/// A site list that cannot be read again.
class _FailingSites extends SiteListNotifier {
  _FailingSites(super.repository, super.ref);

  @override
  Future<void> refresh() async =>
      throw StateError('the sites could not be read again');
}

/// The dive page unlocked for editing in place (issue #4527), behind the
/// build switch.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);
  testWidgets('in the list pane the page has the lock too', (tester) async {
    await pumpPage(tester, embedded: true, size: const Size(1200, 900));

    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
  });

  testWidgets('unlock swaps the bar and moves nothing in the page', (
    tester,
  ) async {
    // Short, so the page scrolls; it is looked at part of the way down.
    await pumpPage(tester, size: const Size(700, 260));
    final page = tester
        .state<ScrollableState>(
          find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        )
        .position;
    page.jumpTo(page.maxScrollExtent / 2);
    await settle(tester);
    double notesTop() => tester.getTopLeft(find.text('Calm')).dy;
    final before = notesTop();
    expect(find.byType(DiveNavButtons), findsOneWidget);

    await unlock(tester);

    expect(find.text('Cancel'), findsOneWidget);
    expect(action(tester, 'Save').onPressed, isNull);
    expect(find.byTooltip('Unlock to edit'), findsNothing);
    expect(find.byType(DiveNavButtons), findsNothing);
    expect(find.byTooltip('Edit Notes'), findsOneWidget);
    // The Add strip arrived above the page and offers Tags.
    expect(find.byKey(const ValueKey('addStrip_tags')), findsOneWidget);
    expect(notesTop(), before);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(notesTop(), before);
  });

  testWidgets('the strip offers Tags for a dive with none', (tester) async {
    await pumpPage(tester);
    expect(find.byKey(const ValueKey('addStrip_tags')), findsNothing);

    await unlock(tester);

    expect(find.byKey(const ValueKey('addStrip_tags')), findsOneWidget);
    expect(find.byKey(const ValueKey('addStrip_notes')), findsNothing);
  });

  testWidgets('a note edit is saved and the page locks', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Calm, then current',
    );
    await settle(tester);
    expect(action(tester, 'Save').onPressed, isNotNull);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(page.save.calls.single.merged.notes, 'Calm, then current');
    expect(page.save.calls.single.cards, ['notes']);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(find.text('Calm, then current'), findsOneWidget);
  });

  group('a write the sitting holds for another record', () {
    Future<void> typeNote(WidgetTester tester) async {
      await unlock(tester);
      await openNotes(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(MarkdownNotesField),
          matching: find.byType(TextField),
        ),
        'Calm, then current',
      );
      await settle(tester);
    }

    RecordEditController<Dive> controller(WidgetTester tester) => tester
        .widget<RecordEditScope<Dive>>(find.byType(RecordEditScope<Dive>))
        .notifier!;

    testWidgets('is run by the save, and the site list is read again', (
      tester,
    ) async {
      SpySites? sites;
      final page = await pumpPage(
        tester,
        extra: [
          siteListNotifierProvider.overrideWith(
            (ref) => sites = SpySites(ref.watch(siteRepositoryProvider), ref),
          ),
        ],
      );
      await typeNote(tester);
      var ran = 0;
      controller(tester).session!.holdWrite('site', () async => ran++);

      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(page.save.calls, hasLength(1));
      expect(ran, 1);
      expect(sites?.refreshes, 1);
    });

    testWidgets('is dropped when the sitting is cancelled', (tester) async {
      await pumpPage(tester);
      await typeNote(tester);
      var ran = 0;
      controller(tester).session!.holdWrite('site', () async => ran++);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await tester.tap(find.text('Discard'));
      await settle(tester);

      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
      expect(ran, 0);
    });

    testWidgets('a sitting that holds none leaves the site list alone', (
      tester,
    ) async {
      SpySites? sites;
      await pumpPage(
        tester,
        extra: [
          siteListNotifierProvider.overrideWith(
            (ref) => sites = SpySites(ref.watch(siteRepositoryProvider), ref),
          ),
        ],
      );
      await typeNote(tester);

      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
      expect(sites, isNull);
    });

    // As with the dive list: the dive and the held write are both committed
    // by then, so this is not a save that failed.
    testWidgets('a site list that cannot be read again is not a failed save', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        extra: [
          siteListNotifierProvider.overrideWith(
            (ref) => _FailingSites(ref.watch(siteRepositoryProvider), ref),
          ),
        ],
      );
      await typeNote(tester);
      var ran = 0;
      controller(tester).session!.holdWrite('site', () async => ran++);

      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(ran, 1);
      expect(
        find.text("Couldn't save your changes. Nothing was changed."),
        findsNothing,
      );
      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
      expect(page.save.calls, hasLength(1));
    });
  });

  testWidgets('typing a change and typing it back disables Save again', (
    tester,
  ) async {
    await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    final field = find.descendant(
      of: find.byType(MarkdownNotesField),
      matching: find.byType(TextField),
    );

    await tester.enterText(field, 'Calm!');
    await settle(tester);
    expect(action(tester, 'Save').onPressed, isNotNull);

    await tester.enterText(field, 'Calm');
    await settle(tester);

    expect(action(tester, 'Save').onPressed, isNull);
  });

  testWidgets('Cancel with changes asks, and Discard leaves the dive alone', (
    tester,
  ) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Something else',
    );
    await settle(tester);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(page.save.calls, isEmpty);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Something else'), findsNothing);
  });

  testWidgets('Cancel with no changes locks at once', (tester) async {
    await pumpPage(tester);
    await unlock(tester);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
  });

  testWidgets('a card added from the strip and cancelled leaves no trace', (
    tester,
  ) async {
    final page = await pumpPage(tester);
    await unlock(tester);

    await tapStripChip(tester, 'tags');
    await settle(tester);
    expect(find.byType(TagFormBlock), findsOneWidget);
    expect(find.byKey(const ValueKey('addStrip_tags')), findsNothing);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.byType(TagFormBlock), findsNothing);
    expect(page.save.calls, isEmpty);

    await unlock(tester);
    expect(find.byKey(const ValueKey('addStrip_tags')), findsOneWidget);
  });

  testWidgets('back with changes asks before leaving', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Something else',
    );
    await settle(tester);

    // The system back gesture.
    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(location(page.router), '/home/dive');

    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(find.text('Something else'), findsOneWidget);
  });

  testWidgets('a failed save stays unlocked and says so', (tester) async {
    final semantics = tester.ensureSemantics();
    final page = await pumpPage(tester);
    page.save.failWith = StateError('gone');
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Something else',
    );
    await settle(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Something else'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Unsaved changes')), findsOneWidget);
    expect(action(tester, 'Save').onPressed, isNotNull);

    semantics.dispose();
  });

  testWidgets('a stored change mid-sitting reaches an untouched card', (
    tester,
  ) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await tapStripChip(tester, 'tags');
    await settle(tester);

    // A sync changes the notes underneath while the diver is on Tags.
    page.save.stored = dive.copyWith(notes: 'From another device');
    ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).invalidate(diveProvider(dive.id));
    await settle(tester);

    expect(find.text('From another device'), findsOneWidget);
    expect(find.text('Calm'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget, reason: 'still unlocked');
    expect(find.byType(TagFormBlock), findsOneWidget, reason: 'card kept');

    // The diver's own change is kept, and the save writes only that card
    // on top of the dive as it is stored now.
    final night = Tag(
      id: 'night',
      name: 'Night',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    tester.widget<TagFormBlock>(find.byType(TagFormBlock)).onTagsChanged([
      night,
    ]);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final call = page.save.calls.single;
    expect(call.cards, ['tags']);
    expect(call.merged.notes, 'From another device');
    expect(call.merged.tags.map((tag) => tag.id), ['night']);
  });

  Finder notesField() => find.descendant(
    of: find.byType(MarkdownNotesField),
    matching: find.byType(TextField),
  );

  // The page binds the arrow keys to the previous and next dive. Inside an
  // editor they belong to the text.
  testWidgets('the arrow keys move the caret inside an editor', (tester) async {
    await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.tap(notesField());
    await settle(tester);
    final text = tester.widget<TextField>(notesField()).controller!;
    text.selection = const TextSelection.collapsed(offset: 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);

    expect(text.selection.baseOffset, 2);
  });

  testWidgets('saved values show at once, before the dive is read back', (
    tester,
  ) async {
    final gate = Completer<void>();
    await pumpPage(tester, reloadGate: gate);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(notesField(), 'Calm, then current');
    await settle(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    // Locked again, and the reload is still waiting.
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(find.text('Calm, then current'), findsOneWidget);
    expect(find.text('Calm'), findsNothing);

    gate.complete();
    await settle(tester);
    expect(find.text('Calm, then current'), findsOneWidget);
  });

  // Between a save and the dive being read back, the page shows the dive
  // as it was just saved. A sitting started then must start from that too,
  // or its editors open on values the diver has just replaced.
  testWidgets('unlocking again before the reload starts from what was saved', (
    tester,
  ) async {
    final gate = Completer<void>();
    final page = await pumpPage(tester, reloadGate: gate);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(notesField(), 'Saved once');
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    await unlock(tester);
    await openNotes(tester);

    expect(
      tester.widget<TextField>(notesField()).controller!.text,
      'Saved once',
    );
    expect(action(tester, 'Save').onPressed, isNull, reason: 'nothing changed');

    gate.complete();
    await settle(tester);
    expect(
      tester.widget<TextField>(notesField()).controller!.text,
      'Saved once',
    );
    expect(page.save.calls, hasLength(1));
  });

  // The same page can be handed another dive (the list pane does this with
  // its detail). What belongs to the first dive must not follow it there.
  group('handed another dive', () {
    testWidgets('the page does not show the first dive\'s saved values', (
      tester,
    ) async {
      final gate = Completer<void>();
      final shown = ValueNotifier(dive.id);
      addTearDown(shown.dispose);
      await pumpPage(tester, reloadGate: gate, shownDiveId: shown);
      await unlock(tester);
      await openNotes(tester);
      await tester.enterText(notesField(), 'Saved once');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Saved once'), findsOneWidget);
      // The other dive is already loaded, as it is after visiting it: the
      // page then hears nothing new when it is switched to it.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      );
      final keepLoaded = container.listen(
        diveProvider(otherDive.id),
        (_, _) {},
      );
      addTearDown(keepLoaded.close);
      await settle(tester);

      // The first dive's reload is still waiting.
      shown.value = otherDive.id;
      await settle(tester);

      expect(find.text('Other notes'), findsOneWidget);
      expect(find.text('Saved once'), findsNothing);
      gate.complete();
      await settle(tester);
    });

    testWidgets('a sitting ends, and is never saved onto the other dive', (
      tester,
    ) async {
      final shown = ValueNotifier(dive.id);
      addTearDown(shown.dispose);
      final page = await pumpPage(tester, shownDiveId: shown);
      await unlock(tester);
      await openNotes(tester);
      await tester.enterText(notesField(), 'Meant for the first dive');
      await settle(tester);

      shown.value = otherDive.id;
      await settle(tester);

      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
      expect(find.text('Other notes'), findsOneWidget);
      expect(find.text('Meant for the first dive'), findsNothing);
      expect(page.save.calls, isEmpty);
    });

    // Locking is refused while a write is running. A write that then fails
    // must not leave the first dive's sitting open on the other dive's page.
    testWidgets('a sitting whose save fails after the switch ends too', (
      tester,
    ) async {
      final shown = ValueNotifier(dive.id);
      addTearDown(shown.dispose);
      final page = await pumpPage(tester, shownDiveId: shown);
      page.save
        ..hold = Completer<void>()
        ..failWith = StateError('gone');
      await unlock(tester);
      await openNotes(tester);
      await tester.enterText(notesField(), 'Meant for the first dive');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await tester.pump();

      shown.value = otherDive.id;
      await settle(tester);
      page.save.hold!.complete();
      await settle(tester);

      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Other notes'), findsOneWidget);
      expect(find.text('Meant for the first dive'), findsNothing);
      expect(
        find.text("Couldn't save your changes. Nothing was changed."),
        findsOneWidget,
      );
    });

    testWidgets('a save is for the dive its sitting was opened on', (
      tester,
    ) async {
      final page = await pumpPage(tester);
      await unlock(tester);
      await openNotes(tester);
      await tester.enterText(notesField(), 'Calm, then current');
      await settle(tester);

      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(page.save.calls.single.diveId, dive.id);
    });
  });

  // The write is committed by then. Saying it failed would be untrue, and
  // would hand the diver a sitting to save a second time.
  testWidgets(
    'a list refresh that fails after the write is not a failed save',
    (tester) async {
      final page = await pumpPage(
        tester,
        extra: [
          paginatedDiveListProvider.overrideWith(
            (ref) =>
                _FailingRefreshList(ref.watch(diveRepositoryProvider), ref),
          ),
        ],
      );
      await unlock(tester);
      await openNotes(tester);
      await tester.enterText(notesField(), 'Saved all the same');
      await settle(tester);

      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(
        find.text("Couldn't save your changes. Nothing was changed."),
        findsNothing,
      );
      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
      expect(find.text('Saved all the same'), findsOneWidget);
      expect(page.save.calls, hasLength(1));
    },
  );

  testWidgets('a hidden card emptied and closed is offered again', (
    tester,
  ) async {
    final wreck = Tag(
      id: 'wreck',
      name: 'Wreck',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    await pumpPage(
      tester,
      stored: dive.copyWith(tags: [wreck]),
      visible: const {DiveDetailSectionId.notes},
    );
    await unlock(tester);
    await tapStripChip(tester, 'tags');
    await settle(tester);

    tester
        .widget<TagFormBlock>(find.byType(TagFormBlock))
        .onTagsChanged(const []);
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(find.byType(TagFormBlock), findsNothing);
    expect(
      find.byKey(const ValueKey('addStrip_tags')),
      findsOneWidget,
      reason: 'the card shows nothing now, so the strip must reach it',
    );
    expect(action(tester, 'Save').onPressed, isNotNull);
  });

  // A dive opened as a root page moves into the list pane when the window
  // is wide enough. Mid-sitting that would drop the changes unasked.
  testWidgets('widening the window does not end a sitting', (tester) async {
    final page = await pumpPage(tester, initialLocation: '/root-dive');
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(notesField(), 'Something else');
    await settle(tester);

    // The harness restores the view too; said here because this is where
    // the size is changed again.
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1400, 1000);
    await settle(tester);

    expect(location(page.router), '/root-dive');
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Something else'), findsOneWidget);
  });

  // A card takes its place in the page's order, which on a short screen is
  // below the fold. Without a scroll the chip would vanish and nothing else
  // would seem to happen.
  testWidgets('a card added from the strip is scrolled into view', (
    tester,
  ) async {
    const height = 360.0;
    await pumpPage(tester, size: const Size(700, height));
    await unlock(tester);

    await tapStripChip(tester, 'tags');
    await tester.pumpAndSettle();

    final editor = tester.getRect(find.byType(TagFormBlock));
    expect(editor.top, lessThan(height));
    expect(editor.bottom, lessThanOrEqualTo(height));
  });

  testWidgets('the arrow keys change dive only while locked', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(location(page.router), '/home/dive');

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);

    expect(location(page.router), '/dives/dive-2');
  });
}
