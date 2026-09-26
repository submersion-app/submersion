import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_revision.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

import '../../../weather/data/repositories/weather_repository_test.mocks.dart';

void main() {
  ProfileSeriesRevision revision({
    required String id,
    required int createdAt,
    required bool isActive,
  }) => ProfileSeriesRevision(
    seriesId: id,
    diveId: 'dive-1',
    parentSeriesId: null,
    rootSeriesId: id,
    contentHash: 'hash-$id',
    revisionKind: 'create',
    createdAt: createdAt,
    isActive: isActive,
  );

  test('loads revisions from repository', () async {
    final changes = StreamController<void>.broadcast();
    final mockRepo = MockDiveRepository();
    when(
      mockRepo.watchAnalysisInputChanges(),
    ).thenAnswer((_) => changes.stream);
    when(mockRepo.getProfileHistory('dive-1')).thenAnswer(
      (_) async => [revision(id: 'series-1', createdAt: 1000, isActive: true)],
    );

    final container = ProviderContainer(
      overrides: [diveRepositoryProvider.overrideWithValue(mockRepo)],
    );
    addTearDown(changes.close);
    addTearDown(container.dispose);

    final result = await container.read(
      profileSeriesHistoryProvider('dive-1').future,
    );

    expect(result, hasLength(1));
    expect(result.single.seriesId, 'series-1');
    expect(result.single.isActive, isTrue);
    verify(mockRepo.getProfileHistory('dive-1')).called(1);
  });

  test('reloads when analysis input change stream emits', () async {
    final changes = StreamController<void>.broadcast();
    final mockRepo = MockDiveRepository();
    when(
      mockRepo.watchAnalysisInputChanges(),
    ).thenAnswer((_) => changes.stream);

    var fetchCount = 0;
    when(mockRepo.getProfileHistory('dive-1')).thenAnswer((_) async {
      fetchCount++;
      return [
        revision(
          id: 'series-$fetchCount',
          createdAt: 1000 + fetchCount,
          isActive: true,
        ),
      ];
    });

    final container = ProviderContainer(
      overrides: [diveRepositoryProvider.overrideWithValue(mockRepo)],
    );
    addTearDown(changes.close);
    addTearDown(container.dispose);

    final provider = profileSeriesHistoryProvider('dive-1');
    final sub = container.listen<AsyncValue<List<ProfileSeriesRevision>>>(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final first = await container.read(provider.future);
    expect(first.single.seriesId, 'series-1');

    changes.add(null);
    for (var i = 0; i < 20 && fetchCount < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    final second = await container.read(provider.future);
    expect(second.single.seriesId, 'series-2');
    expect(fetchCount, greaterThanOrEqualTo(2));
  });
}
