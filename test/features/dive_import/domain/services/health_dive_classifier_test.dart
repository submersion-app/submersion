import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/health_dive_classifier.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Each Apple Health workout (issue #637) fills a draft, joins a downloaded
/// dive, fills a plan, imports as new, or waits for the diver, in that
/// order of evidence: a draft's taps, then a measured dive, then a plan's
/// day.
void main() {
  ImportedDive workout(String id, DateTime start, {int minutes = 45}) =>
      ImportedDive(
        sourceId: id,
        source: ImportSource.appleWatch,
        startTime: start,
        endTime: start.add(Duration(minutes: minutes)),
        maxDepth: 18,
        profile: const [],
      );
  Dive draft(String id, DateTime entry, DateTime exit) => Dive(
    id: id,
    dateTime: entry,
    entryTime: entry,
    exitTime: exit,
    isDraft: true,
  );
  Dive plan(String id, DateTime start) =>
      Dive(id: id, dateTime: start, entryTime: start, isPlanned: true);
  Dive logged(String id, DateTime start, {double depth = 18}) => Dive(
    id: id,
    dateTime: start,
    entryTime: start,
    exitTime: start.add(const Duration(minutes: 45)),
    runtime: const Duration(minutes: 45),
    maxDepth: depth,
  );

  final ten = DateTime.utc(2026, 7, 17, 10);

  test('one draft that the workout overlaps is filled', () {
    final routes = classifyHealthDives(
      [workout('w', ten.add(const Duration(minutes: 2)))],
      unfilled: [draft('d', ten, ten.add(const Duration(minutes: 50)))],
      loggedNear: const [],
    );
    expect(routes.single, isA<FillDraft>());
    expect((routes.single as FillDraft).diveId, 'd');
  });

  test('two drafts the workout fits wait for the diver', () {
    final routes = classifyHealthDives(
      [workout('w', ten, minutes: 60)],
      unfilled: [
        draft(
          'a',
          ten.subtract(const Duration(minutes: 20)),
          ten.add(const Duration(minutes: 5)),
        ),
        draft(
          'b',
          ten.add(const Duration(minutes: 20)),
          ten.add(const Duration(minutes: 60)),
        ),
      ],
      loggedNear: const [],
    );
    expect(routes.single, isA<NeedsReview>());
    expect(
      (routes.single as NeedsReview).candidateIds,
      unorderedEquals(['a', 'b']),
    );
  });

  test('a strong match with a downloaded dive joins it', () {
    final routes = classifyHealthDives(
      [workout('w', ten)],
      unfilled: const [],
      loggedNear: [logged('l', ten)],
    );
    expect(routes.single, isA<Consolidate>());
    expect((routes.single as Consolidate).diveId, 'l');
  });

  test('a weak match waits for the diver', () {
    final routes = classifyHealthDives(
      [workout('w', ten)],
      unfilled: const [],
      loggedNear: [logged('l', ten.add(const Duration(minutes: 9)), depth: 30)],
    );
    expect(routes.single, isA<NeedsReview>());
  });

  test('nothing near imports as new', () {
    final routes = classifyHealthDives(
      [workout('w', ten)],
      unfilled: const [],
      loggedNear: const [],
    );
    expect(routes.single, isA<ImportNew>());
  });

  test('a draft beats a logged dive the workout also matches', () {
    final routes = classifyHealthDives(
      [workout('w', ten)],
      unfilled: [draft('d', ten, ten.add(const Duration(minutes: 50)))],
      loggedNear: [logged('l', ten)],
    );
    expect((routes.single as FillDraft).diveId, 'd');
  });

  test('a workout on a plan\'s day fills the plan', () {
    final routes = classifyHealthDives(
      [workout('w', ten)],
      unfilled: [plan('p', ten.subtract(const Duration(hours: 1)))],
      loggedNear: const [],
    );
    expect(routes.single, isA<FillPlan>());
    expect((routes.single as FillPlan).diveId, 'p');
  });

  test('a logged dive beats a plan of the same day', () {
    final routes = classifyHealthDives(
      [workout('w', ten)],
      unfilled: [plan('p', ten.subtract(const Duration(hours: 1)))],
      loggedNear: [logged('l', ten)],
    );
    expect(routes.single, isA<Consolidate>());
  });

  test('a draft beats a plan', () {
    final routes = classifyHealthDives(
      [workout('w', ten)],
      unfilled: [
        plan('p', ten.subtract(const Duration(hours: 1))),
        draft('d', ten, ten.add(const Duration(minutes: 50))),
      ],
      loggedNear: const [],
    );
    expect((routes.single as FillDraft).diveId, 'd');
  });

  test('two workouts and two plans of a day pair by the nearest start', () {
    final routes = classifyHealthDives(
      [
        workout('morning', DateTime.utc(2026, 7, 17, 9)),
        workout('afternoon', DateTime.utc(2026, 7, 17, 14)),
      ],
      unfilled: [
        plan('pm', DateTime.utc(2026, 7, 17, 13, 30)),
        plan('am', DateTime.utc(2026, 7, 17, 9, 30)),
      ],
      loggedNear: const [],
    );
    expect((routes[0] as FillPlan).diveId, 'am');
    expect((routes[1] as FillPlan).diveId, 'pm');
  });
}
