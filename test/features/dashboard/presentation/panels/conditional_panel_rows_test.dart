import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dashboard/presentation/panels/conditional_panels.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/download_target_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import 'panel_harness.dart';

/// Each row in a conditional panel opens its own item, as the retired cards'
/// rows did; only the panel's empty space falls back to the panel's action.
void main() {
  Course course(String id, String name) => Course(
    id: id,
    diverId: 'me',
    name: name,
    agency: 'padi',
    startDate: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  testWidgets('a later on-this-day dive opens that dive', (tester) async {
    final nav = await pumpPanel(
      tester,
      const OnThisDayPanel(),
      overrides: [
        onThisDayProvider.overrideWith(
          (ref) async => [
            Dive(
              id: 'old1',
              dateTime: DateTime.utc(2024, 11, 20),
              site: const DiveSite(id: 'a', name: 'Blue Hole'),
            ),
            Dive(
              id: 'old2',
              dateTime: DateTime.utc(2022, 11, 20),
              site: const DiveSite(id: 'b', name: 'Canyon'),
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.text('Canyon'));
    await tester.pumpAndSettle();
    expect(nav.location, '/dives/old2');
  });

  testWidgets('a second course opens that course', (tester) async {
    final nav = await pumpPanel(
      tester,
      const ActiveCoursePanel(),
      overrides: [
        activeCoursesProgressProvider.overrideWith(
          (ref) async => [
            (
              course: course('c1', 'Rescue Diver'),
              progress: const CourseProgress(courseId: 'c1', requirements: []),
            ),
            (
              course: course('c2', 'Nitrox'),
              progress: const CourseProgress(courseId: 'c2', requirements: []),
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.text('Nitrox'));
    await tester.pumpAndSettle();
    expect(nav.location, '/courses/c2');
  });

  testWidgets('a waiting draft opens that dive, not a download', (
    tester,
  ) async {
    final nav = await pumpPanel(
      tester,
      const WaitingForDownloadPanel(),
      overrides: [
        draftDivesProvider.overrideWith(
          (ref) async => [
            Dive(
              id: 'draft1',
              dateTime: DateTime.utc(2026, 11, 8),
              exitTime: DateTime.utc(2026, 11, 8, 11),
              site: const DiveSite(id: 's', name: 'Salt Pier'),
            ),
          ],
        ),
        downloadTargetComputerProvider.overrideWith((ref) async => null),
      ],
    );
    await tester.tap(find.text('Salt Pier'));
    await tester.pumpAndSettle();
    expect(nav.location, '/dives/draft1');
  });

  testWidgets('the trip checklist row opens the trip beside a pre-dive row', (
    tester,
  ) async {
    final trip = Trip(
      id: 't1',
      name: 'Bonaire',
      startDate: DateTime.now().add(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final nav = await pumpPanel(
      tester,
      const PreDivePanel(),
      overrides: [
        preDiveActiveSessionProvider.overrideWith((ref) async => null),
        preDiveSessionsProvider.overrideWith(
          (ref) async => [
            PreDiveSession(
              id: 's1',
              templateName: 'Boat dive',
              startedAt: DateTime(2026),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              status: PreDiveSessionStatus.completed,
            ),
          ],
        ),
        preDiveTemplatesProvider.overrideWith((ref) async => []),
        homeTripChecklistProvider.overrideWith(
          (ref) async => (trip: trip, done: 2, total: 5),
        ),
      ],
    );
    await tester.tap(find.textContaining('Bonaire'));
    await tester.pumpAndSettle();
    expect(nav.location, '/trips/t1');
  });
}
