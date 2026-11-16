import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The Profile card in a sitting: annotations placed, moved and removed in
/// the open card and from the notes, held until Save (issue #4527, plan 6).
void main() {
  final profile = List.generate(41, (i) {
    final t = i * 30;
    final depth = t < 180
        ? 30.0 * t / 180
        : t < 900
        ? 30.0
        : 30.0 * (1200 - t) / 300;
    return DiveProfilePoint(timestamp: t, depth: depth);
  });
  late Dive profiled;

  setUp(() async {
    await setUpTestDatabase();
    profiled = dive.copyWith(
      profile: profile,
      runtime: const Duration(seconds: 1200),
      maxDepth: 30,
    );
    await DiveRepository().createDive(profiled);
  });
  tearDown(tearDownTestDatabase);

  const sections = {DiveDetailSectionId.profile, DiveDetailSectionId.notes};
  const size = Size(1000, 1600);

  Finder pin() => find.byTooltip('Add annotation');

  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('locked and closed: no pin', (tester) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);
    expect(find.byType(DiveDetailProfileSection), findsWidgets);
    expect(pin(), findsNothing);

    await unlock(tester);
    await settleLong(tester);
    expect(pin(), findsNothing);
    expect(find.byTooltip('Edit Dive Profile'), findsOneWidget);
  });

  // The page below the bar moves down by the Add strip's height on a page
  // that fits (plan 4, "Decided while building"); the card itself keeps its
  // size.
  testWidgets('the card does not change height on unlock', (tester) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);
    final card = find.byKey(const ValueKey('diveSection_profile'));
    final before = tester.getSize(card);

    await unlock(tester);
    await settleLong(tester);
    expect(tester.getSize(card), before);
  });

  testWidgets('open: a pin placed is held; Save names Profile and Notes and '
      'writes the row', (tester) async {
    final page = await pumpPage(
      tester,
      stored: profiled,
      visible: sections,
      size: size,
    );
    await settleLong(tester);
    await unlock(tester);
    await tester.tap(find.byTooltip('Edit Dive Profile'));
    await settleLong(tester);

    await tester.tap(pin());
    await settleLong(tester);
    final plot = tester.getRect(find.byType(LineChart).first);
    await tester.tapAt(Offset(plot.left + plot.width * 0.5, plot.center.dy));
    await settleLong(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened'),
      'Octo free-flowed',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settleLong(tester);

    // Held: nothing written yet.
    final repo = AnnotationRepository();
    expect(
      await tester.runAsync(() => repo.annotationsForDive(profiled.id)),
      isEmpty,
    );

    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await settleLong(tester);

    expect(page.save.calls.single.cards, containsAll(['profile', 'notes']));
    final rows = await tester.runAsync(
      () => repo.annotationsForDive(profiled.id),
    );
    expect(rows!.single.description, 'Octo free-flowed');
    expect(page.save.calls.single.merged.notes, contains('Octo free-flowed'));
  });

  testWidgets('a pin from the open Notes editor is offered', (tester) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);
    await unlock(tester);
    await openNotes(tester);

    final field = tester.widget<MarkdownNotesField>(
      find.byType(MarkdownNotesField),
    );
    expect(field.onAnnotate, isNotNull);
  });

  test('DatabaseService has a database for the page', () {
    expect(DatabaseService.instance.databaseOrNull, isNotNull);
  });

  // The spec: what Done leaves is the working copy, on every card that
  // draws it, the closed chart among them.
  testWidgets('a finding dismissed in the open Safety review card leaves '
      'the chart', (tester) async {
    final found = SafetyFinding(
      id: 'f1',
      diveId: dive.id,
      ruleId: SafetyRuleId.rapidAscent,
      severity: SafetySeverity.significant,
      startTimestamp: 1000,
      endTimestamp: 1040,
      value: 14.2,
      engineVersion: 1,
      createdAt: DateTime.utc(2026),
    );
    await pumpPage(
      tester,
      stored: profiled,
      visible: const {
        DiveDetailSectionId.profile,
        DiveDetailSectionId.safetyReview,
      },
      size: size,
      extra: [
        safetyReviewProvider(dive.id).overrideWith(
          (ref) async => SafetyReview(
            diveId: dive.id,
            engineVersion: 1,
            reviewedAt: DateTime.utc(2026),
            findings: [found],
          ),
        ),
      ],
    );
    await settleLong(tester);
    List<String> charted() => [
      for (final f
          in tester
                  .widget<DiveProfileChart>(find.byType(DiveProfileChart).first)
                  .safetyFindings ??
              const <SafetyFinding>[])
        f.id,
    ];
    expect(charted(), ['f1']);

    await unlock(tester);
    final pencil = find.descendant(
      of: find.byKey(const ValueKey('diveSection_safetyReview')),
      matching: find.byType(RecordPencilIcon),
    );
    if (pencil.evaluate().isNotEmpty) {
      await tester.ensureVisible(pencil);
      await tester.tap(pencil);
    } else {
      await tapStripChip(tester, DiveDetailSectionId.safetyReview.name);
    }
    await settleLong(tester);
    await tester.tap(find.text('Dismiss all'));
    await settleLong(tester);
    await tester.tap(find.text('Done'));
    await settleLong(tester);

    expect(charted(), isEmpty);
  });
}
