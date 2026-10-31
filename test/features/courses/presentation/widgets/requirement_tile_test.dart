import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/requirement_tile.dart';

import '../../../../helpers/test_app.dart';

class _RecordingRepository extends Fake implements CourseRequirementRepository {
  final linked = <(String, String)>[];

  @override
  Future<void> linkDive({
    required String requirementId,
    required String diveId,
  }) async {
    linked.add((requirementId, diveId));
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
  Future<_RecordingRepository> pumpTile(
    WidgetTester tester, {
    required CourseRequirementProgress progress,
    List<RequirementDiveSummary> suggestions = const [],
    List<RequirementDiveSummary> creditable = const [],
  }) async {
    final repository = _RecordingRepository();

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          courseRequirementRepositoryProvider.overrideWithValue(repository),
          suggestedDivesProvider.overrideWith(
            (ref, courseId) async => suggestions,
          ),
          creditableDivesProvider.overrideWith(
            (ref, courseId) async => creditable,
          ),
        ],
        child: SingleChildScrollView(
          child: RequirementTile(progress: progress, suggestions: suggestions),
        ),
      ),
    );
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();

    return repository;
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
}
