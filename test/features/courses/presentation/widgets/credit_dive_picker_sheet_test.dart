import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/credit_dive_picker_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

import '../../../../helpers/test_app.dart';

/// The picker that lets a requirement reach any dive of the logbook (#3792):
/// suggestions near the course lead, every other dive follows, and the shared
/// dive search takes over once the diver types.
void main() {
  RequirementDiveSummary candidate(
    String id, {
    int? number,
    String? site,
    DateTime? when,
  }) => RequirementDiveSummary(
    diveId: id,
    diveNumber: number,
    dateTime: when ?? DateTime.utc(2019, 3, 14, 9, 30),
    siteName: site,
  );

  DiveSummary searchHit(String id, {int? number, String? site}) {
    final at = DateTime.utc(2018, 6, 2, 11);
    return DiveSummary(
      id: id,
      diveNumber: number,
      dateTime: at,
      siteName: site,
      sortTimestamp: at.millisecondsSinceEpoch,
    );
  }

  CourseProgress progressCrediting(List<String> diveIds) {
    final now = DateTime(2019);
    return CourseProgress(
      courseId: 'course-1',
      requirements: [
        CourseRequirementProgress(
          requirement: CourseRequirement(
            id: 'req-1',
            courseId: 'course-1',
            name: 'Deep adventure dive',
            kind: RequirementKind.dive,
            createdAt: now,
            updatedAt: now,
          ),
          linkedDives: [for (final id in diveIds) candidate(id)],
        ),
      ],
    );
  }

  /// Opens the picker from a host button and records what it returned, so a
  /// test can assert on the value handed back rather than on picker internals.
  Future<List<String?>> pumpPicker(
    WidgetTester tester, {
    List<RequirementDiveSummary> suggested = const [],
    List<RequirementDiveSummary> creditable = const [],
    List<String> credited = const [],
    Map<String, List<DiveSummary>> searchResults = const {},
  }) async {
    final returned = <String?>[];

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          courseProgressProvider.overrideWith(
            (ref, courseId) async => progressCrediting(credited),
          ),
          suggestedDivesProvider.overrideWith(
            (ref, courseId) async => suggested,
          ),
          creditableDivesProvider.overrideWith(
            (ref, courseId) async => creditable,
          ),
          diveSearchProvider.overrideWith(
            (ref, query) async => searchResults[query] ?? const <DiveSummary>[],
          ),
        ],
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => returned.add(
              await showCreditDivePickerSheet(context, courseId: 'course-1'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    return returned;
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    // One plain frame first: the debounce timer is armed in didUpdateWidget,
    // so a pump(duration) here would advance the clock before the timer even
    // exists and it would never fire.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('suggestions lead and every other dive follows, once each', (
    tester,
  ) async {
    final near = candidate('near', number: 12, site: 'Blue Hole');
    await pumpPicker(
      tester,
      suggested: [near],
      creditable: [
        candidate('recent', number: 900, site: "Devil's Den"),
        near,
      ],
    );

    double yOf(String text) => tester.getTopLeft(find.text(text)).dy;

    expect(find.text('Choose dive'), findsOneWidget);
    expect(find.text('#12 · Blue Hole'), findsOneWidget);
    expect(yOf('Suggested dives'), lessThan(yOf('#12 · Blue Hole')));
    expect(yOf('#12 · Blue Hole'), lessThan(yOf('All dives')));
    expect(yOf('All dives'), lessThan(yOf("#900 · Devil's Den")));
  });

  testWidgets('a course with no suggestions still lists every dive', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      creditable: [candidate('old', number: 3, site: 'Ginnie Springs')],
    );

    expect(find.text('Suggested dives'), findsNothing);
    expect(find.text('All dives'), findsOneWidget);
    expect(find.text('#3 · Ginnie Springs'), findsOneWidget);
  });

  testWidgets('the whole logbook is reachable by scrolling', (tester) async {
    await pumpPicker(
      tester,
      creditable: [
        for (var i = 200; i > 0; i--) candidate('dive-$i', number: i),
      ],
    );

    expect(find.text('#1'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('#1'),
      400,
      // The search field is a Scrollable too, so name the list.
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );

    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('choosing a dive closes the picker and returns its id', (
    tester,
  ) async {
    final returned = await pumpPicker(
      tester,
      creditable: [candidate('dive-42', number: 42, site: 'Blue Hole')],
    );

    await tester.tap(find.text('#42 · Blue Hole'));
    await tester.pumpAndSettle();

    expect(returned, ['dive-42']);
  });

  testWidgets('dismissing the picker returns nothing', (tester) async {
    final returned = await pumpPicker(
      tester,
      creditable: [candidate('dive-42', number: 42)],
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(returned, [null]);
  });

  testWidgets('a dive with neither number nor site is titled by its date', (
    tester,
  ) async {
    await pumpPicker(tester, creditable: [candidate('bare')]);

    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.textContaining('2019'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('typing replaces the list with search results', (tester) async {
    await pumpPicker(
      tester,
      creditable: [candidate('near', number: 12, site: 'Blue Hole')],
      searchResults: {
        'ginnie': [searchHit('hit', number: 300, site: 'Ginnie Springs')],
      },
    );

    await search(tester, 'ginnie');

    expect(find.text('#300 · Ginnie Springs'), findsOneWidget);
    expect(find.text('#12 · Blue Hole'), findsNothing);
    expect(find.text('All dives'), findsNothing);
  });

  testWidgets('a search hit already credited in this course is not offered', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      credited: ['taken'],
      searchResults: {
        'reef': [
          searchHit('taken', number: 1, site: 'Taken Reef'),
          searchHit('free', number: 2, site: 'Free Reef'),
        ],
      },
    );

    await search(tester, 'reef');

    expect(find.text('#2 · Free Reef'), findsOneWidget);
    expect(find.text('#1 · Taken Reef'), findsNothing);
  });

  testWidgets('a search with only credited hits reads as no results', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      credited: ['taken'],
      searchResults: {
        'reef': [searchHit('taken', number: 1, site: 'Taken Reef')],
      },
    );

    await search(tester, 'reef');

    expect(find.text('No dives match "reef"'), findsOneWidget);
  });

  testWidgets('whitespace keeps the list rather than searching', (
    tester,
  ) async {
    await pumpPicker(tester, creditable: [candidate('near', number: 12)]);

    await search(tester, '   ');

    expect(find.text('#12'), findsOneWidget);
  });

  testWidgets('a logbook with nothing left to credit says so', (tester) async {
    await pumpPicker(tester);

    expect(find.text('No dives to link'), findsOneWidget);
  });
}
