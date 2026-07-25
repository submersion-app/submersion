import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Dive _diveWithEntryTime(DateTime entryTime) => Dive(
  id: 'test-${entryTime.millisecondsSinceEpoch}',
  dateTime: entryTime,
  entryTime: entryTime,
  tanks: const [],
  profile: const [],
  equipment: const [],
  notes: '',
  photoIds: const [],
  sightings: const [],
  weights: const [],
  tags: const [],
);

void main() {
  group('daysSinceLastDiveProvider', () {
    test('returns 0 for a dive that occurred earlier today', () async {
      final now = DateTime.now();
      final todayDive = _diveWithEntryTime(
        DateTime(now.year, now.month, now.day, 8, 0),
      );
      final container = ProviderContainer(
        overrides: [
          recentDivesProvider.overrideWith((ref) async => [todayDive]),
        ],
      );
      addTearDown(container.dispose);

      final days = await container.read(daysSinceLastDiveProvider.future);
      expect(days, 0);
    });

    test(
      'returns 1 for a dive at 11:55 pm yesterday (issue #263 regression)',
      () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final lateDive = _diveWithEntryTime(
          DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 55),
        );
        final container = ProviderContainer(
          overrides: [
            recentDivesProvider.overrideWith((ref) async => [lateDive]),
          ],
        );
        addTearDown(container.dispose);

        final days = await container.read(daysSinceLastDiveProvider.future);
        expect(days, 1);
      },
    );

    test('returns 2 for a dive two calendar days ago', () async {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final oldDive = _diveWithEntryTime(
        DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 12, 0),
      );
      final container = ProviderContainer(
        overrides: [
          recentDivesProvider.overrideWith((ref) async => [oldDive]),
        ],
      );
      addTearDown(container.dispose);

      final days = await container.read(daysSinceLastDiveProvider.future);
      expect(days, 2);
    });

    test('returns null when there are no dives', () async {
      final container = ProviderContainer(
        overrides: [recentDivesProvider.overrideWith((ref) async => [])],
      );
      addTearDown(container.dispose);

      final days = await container.read(daysSinceLastDiveProvider.future);
      expect(days, isNull);
    });
  });

  group('onThisDayProvider', () {
    late DiveRepository repository;
    late ProviderContainer container;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
      container = ProviderContainer(
        overrides: [
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);
    });
    tearDown(() async => tearDownTestDatabase());

    test('hydrates dives from this date in prior years', () async {
      final now = DateTime.now();
      await repository.createDive(
        Dive(
          id: 'two-years-ago',
          dateTime: DateTime(now.year - 2, now.month, now.day, 10),
        ),
      );
      await repository.createDive(
        Dive(
          id: 'last-year',
          dateTime: DateTime(now.year - 1, now.month, now.day, 10),
        ),
      );
      await repository.createDive(
        Dive(
          id: 'this-year',
          dateTime: DateTime(now.year, now.month, now.day, 8),
        ),
      );

      final dives = await container.read(onThisDayProvider.future);
      expect(dives.map((d) => d.id), ['last-year', 'two-years-ago']);
    });

    test('is empty when no prior-year dive shares the date', () async {
      final now = DateTime.now();
      await repository.createDive(
        Dive(
          id: 'other-day',
          dateTime: DateTime(
            now.year - 1,
            now.month,
            now.day,
            10,
          ).add(const Duration(days: 3)),
        ),
      );

      final dives = await container.read(onThisDayProvider.future);
      expect(dives, isEmpty);
    });
  });

  group('yearInReviewProvider', () {
    late DiveRepository repository;
    late ProviderContainer container;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
      container = ProviderContainer(
        overrides: [
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);
    });
    tearDown(() async => tearDownTestDatabase());

    test('returns null when neither year has dives', () async {
      expect(await container.read(yearInReviewProvider.future), isNull);
    });

    test('compares this year against last year', () async {
      final year = DateTime.now().year;
      await repository.createDive(
        Dive(
          id: 'now-1',
          dateTime: DateTime(year, 2, 1, 10),
          bottomTime: const Duration(minutes: 40),
          maxDepth: 28,
        ),
      );
      await repository.createDive(
        Dive(
          id: 'prev-1',
          dateTime: DateTime(year - 1, 2, 1, 10),
          bottomTime: const Duration(minutes: 30),
          maxDepth: 18,
        ),
      );

      final review = await container.read(yearInReviewProvider.future);
      expect(review, isNotNull);
      expect(review!.year, year);
      expect(review.current.diveCount, 1);
      expect(review.current.totalSeconds, 40 * 60);
      expect(review.current.maxDepth, 28);
      expect(review.previous.diveCount, 1);
      expect(review.previous.maxDepth, 18);
    });
  });
}
