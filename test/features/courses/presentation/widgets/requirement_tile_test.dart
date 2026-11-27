import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/editing/course_requirements_sitting.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/credit_dive_picker_sheet.dart';
import 'package:submersion/features/courses/presentation/widgets/requirement_tile.dart';

import '../../../../helpers/test_app.dart';

/// Records the dives the tile credits; the picker opens as the sitting's
/// actions open it ([HeldRequirementActions.credit]).
class _RecordingActions extends Fake implements RequirementActions {
  final linked = <(String, String)>[];

  @override
  Future<void> credit(
    BuildContext context,
    CourseRequirement requirement,
    RequirementDiveSummary? suggestion,
  ) async {
    final dive =
        suggestion ??
        await showCreditDivePickerSheet(
          context,
          courseId: requirement.courseId,
        );
    if (dive != null) linked.add((requirement.id, dive.diveId));
  }
}

void main() {
  const name = 'Deep adventure dive';

  final oldDive = RequirementDiveSummary(
    diveId: 'old',
    diveNumber: 7,
    dateTime: DateTime.utc(2009, 6, 3, 10),
    siteName: 'Blue Hole',
  );

  CourseRequirementProgress progressWith({
    int targetCount = 1,
    List<RequirementDiveSummary> linkedDives = const [],
  }) {
    final now = DateTime(2009);
    return CourseRequirementProgress(
      requirement: CourseRequirement(
        id: 'req-1',
        courseId: 'course-1',
        name: name,
        kind: RequirementKind.dive,
        targetCount: targetCount,
        createdAt: now,
        updatedAt: now,
      ),
      linkedDives: linkedDives,
    );
  }

  /// Pumps the tile and expands it, where its dive actions live.
  Future<_RecordingActions> pumpTile(
    WidgetTester tester, {
    required CourseRequirementProgress progress,
    List<RequirementDiveSummary> suggestions = const [],
    List<RequirementDiveSummary> creditable = const [],
  }) async {
    final actions = _RecordingActions();

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          suggestedDivesProvider.overrideWith(
            (ref, courseId) async => suggestions,
          ),
          creditableDivesProvider.overrideWith(
            (ref, courseId) async => creditable,
          ),
        ],
        child: SingleChildScrollView(
          child: RequirementTile(
            progress: progress,
            suggestions: suggestions,
            actions: actions,
          ),
        ),
      ),
    );
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();

    return actions;
  }

  testWidgets('a requirement with no suggestions can still choose a dive', (
    tester,
  ) async {
    final repository = await pumpTile(
      tester,
      progress: progressWith(),
      creditable: [oldDive],
    );

    expect(find.text('Suggested dives'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Choose dive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#7 · Blue Hole'));
    await tester.pumpAndSettle();

    expect(repository.linked, [('req-1', 'old')]);
  });

  testWidgets('dismissing the picker credits nothing', (tester) async {
    final repository = await pumpTile(
      tester,
      progress: progressWith(),
      creditable: [oldDive],
    );

    await tester.tap(find.widgetWithText(TextButton, 'Choose dive'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(repository.linked, isEmpty);
  });

  testWidgets('a satisfied requirement stops offering dives', (tester) async {
    await pumpTile(
      tester,
      progress: progressWith(linkedDives: [oldDive]),
      suggestions: [oldDive],
    );

    expect(find.text('Choose dive'), findsNothing);
    expect(find.text('Suggested dives'), findsNothing);
  });

  testWidgets('a dive from another year is labelled with its year', (
    tester,
  ) async {
    await pumpTile(
      tester,
      progress: progressWith(targetCount: 2),
      suggestions: [oldDive],
    );

    expect(
      find.descendant(
        of: find.byType(ActionChip),
        matching: find.textContaining('2009'),
      ),
      findsOneWidget,
    );
  });

  group('a requirement counted from the logbook', () {
    CourseRequirementProgress derived(
      RequirementKind kind, {
      required int targetCount,
      required int derivedAmount,
    }) {
      final now = DateTime(2026);
      return CourseRequirementProgress(
        requirement: CourseRequirement(
          id: 'req-derived',
          courseId: 'course-1',
          name: 'Logbook requirement',
          kind: kind,
          targetCount: targetCount,
          createdAt: now,
          updatedAt: now,
        ),
        linkedDives: const [],
        derivedAmount: derivedAmount,
      );
    }

    Future<void> pumpDerived(
      WidgetTester tester,
      CourseRequirementProgress progress, {
      Locale locale = const Locale('en'),
      RequirementActions? actions,
    }) async {
      await tester.pumpWidget(
        testApp(
          locale: locale,
          child: RequirementTile(
            progress: progress,
            suggestions: const [],
            actions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('CCR hours show tenths of an hour and tick once met', (
      tester,
    ) async {
      await pumpDerived(
        tester,
        derived(RequirementKind.ccrHours, targetCount: 2, derivedAmount: 150),
      );

      expect(find.text('2.5 of 2 hours'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('CCR hours just short of the target never round up to it', (
      tester,
    ) async {
      // 119 minutes is 1.98 hours: shown as 1.9, not 2.0, while unmet.
      await pumpDerived(
        tester,
        derived(RequirementKind.ccrHours, targetCount: 2, derivedAmount: 119),
      );

      expect(find.text('1.9 of 2 hours'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('CCR hours use the locale decimal separator', (tester) async {
      await pumpDerived(
        tester,
        derived(RequirementKind.ccrHours, targetCount: 2, derivedAmount: 150),
        locale: const Locale('de'),
      );

      expect(find.text('2,5 von 2 Stunden'), findsOneWidget);
    });

    testWidgets('a dive search counts its matching dives', (tester) async {
      await pumpDerived(
        tester,
        derived(RequirementKind.diveQuery, targetCount: 5, derivedAmount: 3),
      );

      expect(find.text('3 of 5 matching dives'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      // Nothing to credit or tick on a logbook-counted requirement.
      expect(find.text('Choose dive'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('the menu appears only while the card is being edited', (
      tester,
    ) async {
      final progress = derived(
        RequirementKind.diveQuery,
        targetCount: 5,
        derivedAmount: 5,
      );
      await pumpDerived(tester, progress);
      expect(find.byType(RequirementMenuButton), findsNothing);

      await pumpDerived(tester, progress, actions: _RecordingActions());
      expect(find.byType(RequirementMenuButton), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });
}
