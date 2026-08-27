import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

Course _makeCourse({
  String id = '',
  String name = 'Open Water',
  required String diverId,
}) {
  final now = DateTime(2024);
  return Course(
    id: id,
    diverId: diverId,
    name: name,
    agency: CertificationAgency.padi,
    startDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

Diver _makeDiver({String name = 'D', bool isDefault = true}) {
  final now = DateTime(2024);
  return Diver(
    id: '',
    name: name,
    isDefault: isDefault,
    createdAt: now,
    updatedAt: now,
  );
}

/// Repository whose [getAllCourses] always throws, to exercise the error/catch
/// branch of the providers. Its change stream is inert so no tick is delivered.
class _ThrowingCourseRepository extends CourseRepository {
  @override
  Stream<void> watchCoursesChanges() => const Stream<void>.empty();

  @override
  Future<List<Course>> getAllCourses({String? diverId}) async {
    throw StateError('boom');
  }
}

void main() {
  late SharedPreferences prefs;
  late CourseRepository courseRepo;
  late DiverRepository diverRepo;
  late DiveRepository diveRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    courseRepo = CourseRepository();
    diverRepo = DiverRepository();
    diveRepo = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  /// Creates a default diver and selects it as current, so diver-scoped
  /// providers resolve a stable validated diver id.
  Future<Diver> seedCurrentDiver() async {
    final diver = await diverRepo.createDiver(_makeDiver());
    await prefs.setString(currentDiverIdKey, diver.id);
    return diver;
  }

  /// Polls [read] until [settled] holds, giving the dives-table tick ->
  /// invalidateSelfWhen -> rebuild round trip a chance to run.
  ///
  /// The budget is derived from [DiveRepository.changeTickDebounce] rather than
  /// hard-coded: `watchDivesChanges()` is debounced, so a budget copied from a
  /// test that watches an undebounced stream would be largely consumed before
  /// the tick even fires. Never settling fails here, naming the round trip that
  /// stalled and the stale contents still held, instead of surfacing as a bare
  /// value mismatch that reads like a wrong query.
  Future<T> pollUntil<T>(
    Future<T> Function() read,
    bool Function(T value) settled, {
    required String awaiting,
    required String provider,
    required String Function(T value) describe,
  }) async {
    const interval = Duration(milliseconds: 20);
    final budget = DiveRepository.changeTickDebounce * 20;
    final deadline = DateTime.now().add(budget);

    var value = await read();
    while (!settled(value) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      value = await read();
    }

    if (!settled(value)) {
      fail(
        'Timed out after ${budget.inMilliseconds}ms waiting for $awaiting. '
        'The dives-table tick -> invalidateSelfWhen -> rebuild round trip '
        'never settled; $provider still holds ${describe(value)}.',
      );
    }
    return value;
  }

  /// Seeds a course owned by [diver] plus two dives linked to it, mirroring the
  /// state the course detail page renders before a merge folds one dive away.
  Future<(Course, Dive, Dive)> seedCourseWithTwoDives(Diver diver) async {
    final course = await courseRepo.createCourse(
      _makeCourse(name: 'Rescue Diver', diverId: diver.id),
    );
    final survivor = await diveRepo.createDive(
      Dive(
        id: '',
        diverId: diver.id,
        dateTime: DateTime(2024, 6, 1),
        courseId: course.id,
      ),
    );
    final loser = await diveRepo.createDive(
      Dive(
        id: '',
        diverId: diver.id,
        dateTime: DateTime(2024, 6, 2),
        courseId: course.id,
      ),
    );
    return (course, survivor, loser);
  }

  group('allCoursesProvider', () {
    test(
      'auto-refreshes after a write to the courses table (sync scenario)',
      () async {
        final diver = await seedCurrentDiver();

        final container = makeContainer();
        addTearDown(container.dispose);

        // An active listener keeps the provider (and its table-change
        // subscription) alive, mirroring a widget watching the list.
        final sub = container.listen(allCoursesProvider, (_, _) {});
        addTearDown(sub.close);

        expect(await container.read(allCoursesProvider.future), isEmpty);

        // A sync applies a remote course straight to the DB, bypassing the list
        // notifier. The tableUpdates tick must invalidate the provider so the
        // UI reflects the new row.
        await courseRepo.createCourse(
          _makeCourse(name: 'Synced Course', diverId: diver.id),
        );

        var names = <String>[];
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          names = (await container.read(
            allCoursesProvider.future,
          )).map((c) => c.name).toList();
          if (names.contains('Synced Course')) break;
        }

        expect(
          names,
          contains('Synced Course'),
          reason:
              'allCoursesProvider should auto-refresh after the table write '
              'without any manual invalidation',
        );
      },
    );

    test('surfaces an AsyncError when the repository getAll throws', () async {
      await seedCurrentDiver();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          courseRepositoryProvider.overrideWithValue(
            _ThrowingCourseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(allCoursesProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(container.read(allCoursesProvider).hasError, isTrue);
    });
  });

  group('courseListNotifierProvider', () {
    test('auto-refreshes the list when a course is written directly to the DB '
        '(sync scenario)', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its table-change subscription)
      // alive, mirroring the on-screen list.
      final sub = container.listen(courseListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(courseListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(courseListNotifierProvider).value, isEmpty);

      // A sync applies a remote course straight to the DB (no notifier mutation
      // call). The watchCoursesChanges tick must silently reload the list via
      // _silentReloadCourses.
      await courseRepo.createCourse(
        _makeCourse(name: 'Synced Course', diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (container.read(courseListNotifierProvider).value ?? [])
            .map((c) => c.name)
            .toList();
        if (names.contains('Synced Course')) break;
      }

      expect(
        names,
        contains('Synced Course'),
        reason:
            'CourseListNotifier should auto-refresh after a direct DB write '
            'without any manual refresh() call',
      );
    });

    test('reports AsyncError when the initial load throws', () async {
      await seedCurrentDiver();

      // A repository that always throws makes the notifier's initial load
      // (_loadCourses) fail, exercising its error catch branch. No table-change
      // tick is involved here.
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          courseRepositoryProvider.overrideWithValue(
            _ThrowingCourseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(courseListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (container.read(courseListNotifierProvider).hasError) break;
      }

      expect(container.read(courseListNotifierProvider).hasError, isTrue);
    });
  });

  group('courseDivesProvider', () {
    test('auto-refreshes after a course dive is deleted directly from the DB '
        '(dive merge/consolidate scenario)', () async {
      final diver = await seedCurrentDiver();
      final (course, survivor, loser) = await seedCourseWithTwoDives(diver);

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the provider (and its dives-table subscription)
      // alive, mirroring the course detail page watching the dive list.
      final sub = container.listen(courseDivesProvider(course.id), (_, _) {});
      addTearDown(sub.close);

      final initial = await container.read(
        courseDivesProvider(course.id).future,
      );
      expect(initial.map((d) => d.id), containsAll([survivor.id, loser.id]));

      // A merge or consolidate deletes the losing dive through bulkDeleteDives
      // (dive_merge_service.dart, dive_consolidation_service.dart), bypassing
      // CourseListNotifier entirely -- the same primitive a sync pull uses when
      // applying a remote deletion. The provider has to notice on its own.
      await diveRepo.bulkDeleteDives([loser.id]);

      final dives = await pollUntil(
        () => container.read(courseDivesProvider(course.id).future),
        (d) => !d.any((dive) => dive.id == loser.id),
        awaiting: 'the merged-away dive to leave the course dive list',
        provider: 'courseDivesProvider',
        describe: (d) => d.map((dive) => dive.id).toList().toString(),
      );

      expect(
        dives.map((d) => d.id).toList(),
        equals([survivor.id]),
        reason:
            'courseDivesProvider should auto-refresh after a dive delete, the '
            'same way courseProgressProvider already does for the requirements '
            'section on the same page',
      );
    });
  });

  group('courseDiveCountProvider', () {
    test('auto-refreshes after a course dive is deleted directly from the DB '
        '(dive merge/consolidate scenario)', () async {
      final diver = await seedCurrentDiver();
      final (course, _, loser) = await seedCourseWithTwoDives(diver);

      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        courseDiveCountProvider(course.id),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(courseDiveCountProvider(course.id).future),
        2,
      );

      await diveRepo.bulkDeleteDives([loser.id]);

      final count = await pollUntil(
        () => container.read(courseDiveCountProvider(course.id).future),
        (c) => c == 1,
        awaiting: 'the course dive count to drop the merged-away dive',
        provider: 'courseDiveCountProvider',
        describe: (c) => '$c',
      );

      expect(count, 1);
    });
  });
}
