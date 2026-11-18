import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_banner.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_new_dive_harness.dart';
import 'dive_detail_page_unlock_harness.dart';

/// A new dive opens on the dive page, already unlocked, with the Dive card
/// and the starter set laid out; Cancel leaves without creating anything
/// (issue #4527, plan 8).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> typeNote(WidgetTester tester, String text) async {
    final field = find.descendant(
      of: find.byType(DiveNotesCardEditor),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await settle(tester);
  }

  testWidgets('opens unlocked with the Dive card and the starter set open', (
    tester,
  ) async {
    await pumpNewDivePage(tester);

    expect(find.text('Log Dive'), findsOneWidget);
    expect(action(tester, 'Save').onPressed, isNull);
    expect(newDiveController(tester).openCardIds, {
      diveHeaderCardId,
      DiveDetailSectionId.tanks.name,
      DiveDetailSectionId.buddies.name,
      DiveDetailSectionId.notes.name,
    });
    expect(find.byKey(const ValueKey('addStrip_equipment')), findsOneWidget);
    expect(find.byTooltip('Unlock to edit'), findsNothing);
  });

  testWidgets('typing a note enables Save', (tester) async {
    await pumpNewDivePage(tester);
    await typeNote(tester, 'Wall');
    expect(action(tester, 'Save').onPressed, isNotNull);
  });

  testWidgets('Cancel with nothing entered leaves without asking', (
    tester,
  ) async {
    final page = await pumpNewDivePage(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(location(page.router), '/home');
    expect(page.save.creates, isEmpty);
  });

  testWidgets(
    'Cancel with a note asks; Keep editing keeps it; Discard leaves',
    (tester) async {
      final page = await pumpNewDivePage(tester);
      await typeNote(tester, 'Wall');

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await settle(tester);
      expect(location(page.router), '/home/new');
      expect(find.text('Wall'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await tester.tap(find.text('Discard'));
      await settle(tester);
      expect(location(page.router), '/home');
      expect(page.save.creates, isEmpty);
    },
  );

  testWidgets('Escape cancels as the bar does', (tester) async {
    final page = await pumpNewDivePage(tester, shortcuts: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(location(page.router), '/home');
  });

  testWidgets('Back with a note asks', (tester) async {
    final page = await pumpNewDivePage(tester);
    await typeNote(tester, 'Wall');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(location(page.router), '/home/new');
  });

  testWidgets('another route with a note asks', (tester) async {
    final page = await pumpNewDivePage(tester);
    await typeNote(tester, 'Wall');
    page.router.go('/dives');
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(location(page.router), '/home/new');
  });

  testWidgets('Cmd+S on an untouched new dive stays', (tester) async {
    final page = await pumpNewDivePage(tester, shortcuts: true);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await settle(tester);
    expect(location(page.router), '/home/new');
    expect(newDiveController(tester).isUnlocked, isTrue);
    expect(page.save.creates, isEmpty);
  });

  testWidgets('a starter card the diver hid is laid out', (tester) async {
    await pumpNewDivePage(tester, visible: const {DiveDetailSectionId.tags});
    expect(find.byType(DiveNotesCardEditor), findsOneWidget);
  });

  testWidgets('a planned new dive shows no banner and no number', (
    tester,
  ) async {
    await pumpNewDivePage(
      tester,
      request: const NewDiveRequest(prefill: DivePrefill(isPlanned: true)),
    );
    expect(find.byType(PlannedDiveBanner), findsNothing);
    final working = newDiveController(tester).session!.working;
    expect(working.isPlanned, isTrue);
    expect(working.diveNumber, isNull);
  });

  testWidgets('the bar offers no menu', (tester) async {
    await pumpNewDivePage(tester);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('a scanned note is an entry: Save is on, Cancel asks', (
    tester,
  ) async {
    await pumpNewDivePage(
      tester,
      request: const NewDiveRequest(
        prefill: DivePrefill(notes: 'From the log'),
      ),
    );
    expect(action(tester, 'Save').onPressed, isNotNull);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  group('Save', () {
    testWidgets('creates the dive and opens it', (tester) async {
      final page = await pumpNewDivePage(tester);
      await typeNote(tester, 'First dive');
      await tester.tap(find.text('Save'));
      await settle(tester);

      final made = page.save.creates.single;
      expect(made.dive.notes, 'First dive');
      expect(made.cards, contains(DiveDetailSectionId.notes.name));
      expect(location(page.router), '/dives/${made.dive.id}');
    });

    testWidgets('in the pane, Save hands the new id to onCreated', (
      tester,
    ) async {
      final page = await pumpNewDivePage(tester, embedded: true);
      await typeNote(tester, 'First dive');
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(page.created, [page.save.creates.single.dive.id]);
    });

    testWidgets('in the pane, Cancel tells the pane', (tester) async {
      final page = await pumpNewDivePage(tester, embedded: true);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(page.cancelled, ['cancel']);
    });

    testWidgets('a Save that fails stays unlocked with the note', (
      tester,
    ) async {
      final page = await pumpNewDivePage(tester);
      page.save.failWith = StateError('disk full');
      await typeNote(tester, 'First dive');
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(
        find.text("Couldn't save your changes. Nothing was changed."),
        findsOneWidget,
      );
      expect(location(page.router), '/home/new');
      expect(newDiveController(tester).isUnlocked, isTrue);
      expect(find.text('First dive'), findsOneWidget);
    });
  });
}
