import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';

DiveProfilePoint pt(int t, double d) =>
    DiveProfilePoint(timestamp: t, depth: d);

DiveDataSource source(
  String id, {
  required bool primary,
  required String model,
}) => DiveDataSource(
  id: id,
  diveId: 'd1',
  isPrimary: primary,
  computerModel: model,
  importedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
);

SourceProfile sp(String id, List<DiveProfilePoint> points) => SourceProfile(
  sourceId: id,
  computerId: null,
  isEdited: false,
  points: points,
);

/// Answers the reads a dive comparison makes and records which dives it
/// hydrated. Any other call fails the test, so a comparison that reaches for
/// `getDiveById` cannot pass.
class _ComparisonRepository extends Fake implements DiveRepository {
  _ComparisonRepository(
    this.profiles, {
    Map<String, int>? sampleCounts,
    this.summaries = const [],
    this.firstLoadGate,
  }) : sampleCounts =
           sampleCounts ??
           {
             for (final MapEntry(key: id, value: bySource) in profiles.entries)
               id: bySource.values.firstOrNull?.points.length ?? 0,
           };

  final Map<String, Map<String, SourceProfile>> profiles;
  final Map<String, int> sampleCounts;
  List<DiveSummary> summaries;
  final Completer<void>? firstLoadGate;

  final StreamController<void> ticks = StreamController<void>.broadcast();
  final List<String> hydrated = [];

  @override
  Stream<void> watchTables(Set<String> tableNames) => ticks.stream;

  @override
  Future<Map<String, int>> getPrimarySourceSampleCounts(
    List<String> diveIds,
  ) async => {
    for (final id in diveIds)
      if (sampleCounts.containsKey(id)) id: sampleCounts[id]!,
  };

  @override
  Future<Map<String, SourceProfile>> getProfilesByDataSource(
    String diveId,
  ) async {
    hydrated.add(diveId);
    if (hydrated.length == 1) await firstLoadGate?.future;
    return profiles[diveId] ?? const {};
  }

  @override
  Future<List<DiveSummary>> getSummariesByIds(List<String> ids) async => [
    for (final summary in summaries)
      if (ids.contains(summary.id)) summary,
  ];
}

Map<String, SourceProfile> usable(String sourceId) => {
  sourceId: sp(sourceId, [pt(0, 0), pt(60, 20), pt(120, 0)]),
};

DiveSummary summary(String id, {int? diveNumber, String? siteName}) =>
    DiveSummary(
      id: id,
      diveNumber: diveNumber,
      siteName: siteName,
      dateTime: DateTime.utc(2026),
      sortTimestamp: 0,
    );

void main() {
  ProviderContainer containerFor(DiveRepository repository) {
    final container = ProviderContainer(
      overrides: [diveRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Reads the comparison of [key] while a subscription holds it, as the
  /// page does: it is released when nothing watches it.
  Future<DiveComparison> compare(
    ProviderContainer container,
    DiveIdSet key,
  ) async {
    final subscription = container.listen(
      diveComparisonProfilesProvider(key),
      (_, _) {},
    );
    addTearDown(subscription.close);
    return container.read(diveComparisonProfilesProvider(key).future);
  }

  test('builds one profile per source, primary as reference index 0', () async {
    final container = ProviderContainer(
      overrides: [
        diveDataSourcesProvider('d1').overrideWith(
          (ref) async => [
            source('srcSecondary', primary: false, model: 'Teric'),
            source('srcPrimary', primary: true, model: 'Perdix'),
          ],
        ),
        sourceProfilesProvider('d1').overrideWith(
          (ref) async => {
            'srcPrimary': sp('srcPrimary', [pt(0, 0), pt(60, 30), pt(120, 0)]),
            'srcSecondary': sp('srcSecondary', [
              pt(0, 0),
              pt(60, 31),
              pt(120, 0),
            ]),
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final profiles = await container.read(
      computerComparisonProfilesProvider('d1').future,
    );

    expect(profiles, hasLength(2));
    // Primary first -> reference index 0.
    expect(profiles.first.id, 'srcPrimary');
    expect(profiles.first.label, 'Perdix');
    expect(profiles.first.color, sourceColorAt(0));
    expect(profiles.first.times, [0, 60, 120]);
    expect(profiles.first.depths, [0, 30, 0]);
    expect(profiles[1].id, 'srcSecondary');
  });

  test('skips sources without a usable profile', () async {
    final container = ProviderContainer(
      overrides: [
        diveDataSourcesProvider('d1').overrideWith(
          (ref) async => [
            source('srcPrimary', primary: true, model: 'Perdix'),
            source('srcMeta', primary: false, model: 'MetaOnly'),
          ],
        ),
        sourceProfilesProvider('d1').overrideWith(
          (ref) async => {
            'srcPrimary': sp('srcPrimary', [pt(0, 0), pt(60, 30)]),
            'srcMeta': sp('srcMeta', [pt(0, 0)]), // < 2 points
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final profiles = await container.read(
      computerComparisonProfilesProvider('d1').future,
    );
    expect(profiles, hasLength(1));
    expect(profiles.single.id, 'srcPrimary');
  });

  test('DiveIdSet equality is by ordered contents', () {
    expect(DiveIdSet(['a', 'b']), DiveIdSet(['a', 'b']));
    expect(DiveIdSet(['a', 'b']).hashCode, DiveIdSet(['a', 'b']).hashCode);
    expect(DiveIdSet(['a', 'b']) == DiveIdSet(['b', 'a']), isFalse);
  });

  group('diveComparisonProfilesProvider', () {
    test('first dive is reference; no-profile dives skipped', () async {
      final repository = _ComparisonRepository({
        'a': usable('s1'),
        'b': usable('s2'),
        'c': {
          's3': sp('s3', [pt(0, 0)]),
        }, // < 2 -> skipped
      });

      final comparison = await compare(
        containerFor(repository),
        DiveIdSet(['a', 'b', 'c']),
      );

      expect(comparison.profiles.map((p) => p.id), ['a', 'b']);
      expect(comparison.profiles.first.color, sourceColorAt(0));
      expect(comparison.comparableCount, 2);
    });

    test(
      'hydrates only the dives it shows, however many are selected',
      () async {
        final ids = [for (var i = 0; i < 800; i++) 'd$i'];
        final repository = _ComparisonRepository({
          for (final id in ids) id: usable('s-$id'),
        });

        final comparison = await compare(
          containerFor(repository),
          DiveIdSet(ids),
        );

        expect(comparison.profiles, hasLength(kMaxComparisonProfiles));
        expect(repository.hydrated, ids.take(kMaxComparisonProfiles));
        // The note still counts every comparable dive, not just the shown ones.
        expect(comparison.comparableCount, 800);
      },
    );

    test('keeps the first usable dives in selection order', () async {
      // Selection order, deliberately neither sorted nor all usable.
      final ids = ['z', 'manual', 'y', 'empty', 'x'];
      final repository = _ComparisonRepository(
        {
          'z': usable('s1'),
          'manual': const {},
          'y': usable('s2'),
          'empty': usable('s3'),
          'x': usable('s4'),
        },
        sampleCounts: {'z': 3, 'y': 3, 'x': 3},
      );

      final comparison = await compare(
        containerFor(repository),
        DiveIdSet(ids),
      );

      expect(comparison.profiles.map((p) => p.id), ['z', 'y', 'x']);
      expect(comparison.profiles.map((p) => p.color), [
        sourceColorAt(0),
        sourceColorAt(1),
        sourceColorAt(2),
      ]);
      expect(repository.hydrated, ['z', 'y', 'x']);
      expect(comparison.comparableCount, 3);
    });

    test(
      'a dive whose samples turn out unreadable gives way to the next',
      () async {
        // Its stored count says usable, but the blob did not decode.
        final ids = [for (var i = 0; i < 10; i++) 'd$i'];
        final repository = _ComparisonRepository(
          {for (final id in ids) id: id == 'd2' ? const {} : usable('s-$id')},
          sampleCounts: {for (final id in ids) id: 3},
        );

        final comparison = await compare(
          containerFor(repository),
          DiveIdSet(ids),
        );

        expect(comparison.profiles.map((p) => p.id), [
          'd0',
          'd1',
          'd3',
          'd4',
          'd5',
          'd6',
          'd7',
          'd8',
        ]);
        expect(repository.hydrated, hasLength(9));
        // Truthful: d2 cannot be compared, so it is not in the total either.
        expect(comparison.comparableCount, 9);
      },
    );

    test('labels by site, then dive number, then id', () async {
      final repository = _ComparisonRepository(
        {'a': usable('s1'), 'b': usable('s2'), 'c': usable('s3')},
        summaries: [
          summary('a', siteName: 'Blue Hole', diveNumber: 7),
          summary('b', diveNumber: 42),
        ],
      );

      final comparison = await compare(
        containerFor(repository),
        DiveIdSet(['a', 'b', 'c']),
      );

      expect(comparison.profiles.map((p) => p.label), [
        'Blue Hole',
        '#42',
        'c',
      ]);
    });

    test('releases the selection once nothing watches it', () async {
      final repository = _ComparisonRepository({
        'a': usable('s1'),
        'b': usable('s2'),
      });
      final container = containerFor(repository);
      final key = DiveIdSet(['a', 'b']);
      final subscription = container.listen(
        diveComparisonProfilesProvider(key),
        (_, _) {},
      );
      await container.read(diveComparisonProfilesProvider(key).future);
      expect(container.exists(diveComparisonProfilesProvider(key)), isTrue);

      subscription.close();
      await pumpEventQueue();

      expect(container.exists(diveComparisonProfilesProvider(key)), isFalse);
    });

    test('stops hydrating once the comparison is left', () async {
      final gate = Completer<void>();
      final ids = [for (var i = 0; i < 12; i++) 'd$i'];
      final repository = _ComparisonRepository({
        for (final id in ids) id: usable('s-$id'),
      }, firstLoadGate: gate);
      final container = containerFor(repository);
      final subscription = container.listen(
        diveComparisonProfilesProvider(DiveIdSet(ids)),
        (_, _) {},
      );
      await pumpEventQueue();
      expect(repository.hydrated, ['d0']);

      subscription.close();
      await pumpEventQueue();
      gate.complete();
      await pumpEventQueue();

      expect(repository.hydrated, ['d0']);
    });

    test('reloads when a table it reads changes', () async {
      final repository = _ComparisonRepository(
        {'a': usable('s1'), 'b': usable('s2')},
        summaries: [summary('a', siteName: 'Old name')],
      );
      final container = containerFor(repository);
      final key = DiveIdSet(['a', 'b']);
      final first = await compare(container, key);
      expect(first.profiles.first.label, 'Old name');

      repository.summaries = [summary('a', siteName: 'New name')];
      repository.ticks.add(null);
      await pumpEventQueue();

      final second = await container.read(
        diveComparisonProfilesProvider(key).future,
      );
      expect(second.profiles.first.label, 'New name');
    });
  });
}
