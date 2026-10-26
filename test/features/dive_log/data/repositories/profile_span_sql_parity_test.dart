import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #3537: Insights reads a dive's profile span in SQL
/// ([profileSpanSecondsSql]), while the trip story's day rhythm bar reads it
/// from the hydrated `Dive.profile`, which is the merged read
/// (`getMergedProfile`). For a dive with a profile but no runtime, no exit
/// time and no bottom time, that span is the dive's duration, so the two
/// must agree or the bar and Time patterns classify the dive differently.
///
/// The merged read hides two kinds of series: inactive child revisions, and
/// the superseded originals of a saved edit. Each case here builds one of
/// those states and checks that the SQL span, the times-only projection and
/// the trip story's dives all land on the same exit.
void main() {
  late AppDatabase db;
  late DiveRepository repository;
  late ProfileSeriesRepository series;

  final entry = DateTime.utc(2026, 3, 1, 18, 20);

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    series = ProfileSeriesRepository();
  });
  tearDown(tearDownTestDatabase);

  List<domain.DiveProfilePoint> points(int endSeconds) => [
    const domain.DiveProfilePoint(timestamp: 0, depth: 0),
    domain.DiveProfilePoint(timestamp: endSeconds ~/ 2, depth: 12),
    domain.DiveProfilePoint(timestamp: endSeconds, depth: 0),
  ];

  List<ProfileSample> samples(int endSeconds) => [
    const ProfileSample(timestamp: 0, depth: 0),
    ProfileSample(timestamp: endSeconds ~/ 2, depth: 12),
    ProfileSample(timestamp: endSeconds, depth: 0),
  ];

  /// A dive with no duration of its own: only its profile can measure it.
  Future<void> createBareDive(
    String id, {
    List<domain.DiveProfilePoint> profile = const [],
  }) async {
    await repository.createDive(
      domain.Dive(id: id, dateTime: entry, entryTime: entry, profile: profile),
    );
    await db.customStatement(
      'UPDATE dives SET runtime = NULL, bottom_time = NULL, '
      'exit_time = NULL WHERE id = ?',
      [id],
    );
  }

  Future<void> createComputer(String id) async {
    final now = DateTime.utc(2026, 3, 1).millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: id,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> createSource(
    String id, {
    required String diveId,
    required String computerId,
    required bool isPrimary,
    required DateTime createdAt,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            importedAt: createdAt,
            createdAt: createdAt,
          ),
        );
  }

  Future<int?> sqlSpan(String id) async {
    final row = await db
        .customSelect(
          "SELECT ${profileSpanSecondsSql('d')} AS span "
          'FROM dives d WHERE d.id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingle();
    return row.readNullable<int>('span');
  }

  Future<int?> sqlExitMillis(String id) async {
    final row = await db
        .customSelect(
          "SELECT ${diveExitMillisSql('d')} AS exit_ms "
          'FROM dives d WHERE d.id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingle();
    return row.readNullable<int>('exit_ms');
  }

  /// Every reader of the dive's duration agrees on [expectedSeconds].
  Future<void> expectSpan(String id, int expectedSeconds) async {
    final merged = domain.Dive(
      id: id,
      dateTime: entry,
      profile: await repository.getMergedProfile(id),
    ).calculateRuntimeFromProfile();
    expect(merged, Duration(seconds: expectedSeconds), reason: 'merged read');

    expect(await sqlSpan(id), expectedSeconds, reason: 'profileSpanSecondsSql');

    // The trip story's dives, which the day rhythm bar lays out.
    final tripDive = (await repository.getDivesByIds([id])).single;
    expect(tripDive.effectiveRuntime, Duration(seconds: expectedSeconds));
    expect(
      await sqlExitMillis(id),
      entry.add(tripDive.effectiveRuntime!).millisecondsSinceEpoch,
      reason: 'Time patterns exit vs day rhythm bar exit',
    );

    final times = await repository.getDiveTimes(id);
    expect(times!.effectiveRuntime, Duration(seconds: expectedSeconds));
  }

  test('a profile-only dive reads the same span everywhere', () async {
    await createBareDive('plain', profile: points(3000));
    await expectSpan('plain', 3000);
  });

  test('a saved edit that trims the profile supersedes the original '
      'span', () async {
    await createBareDive('trimmed', profile: points(3000));
    await repository.saveEditedProfile('trimmed', points(2400));
    await expectSpan('trimmed', 2400);
  });

  test('a second edit hides the first one, even when it ran longer', () async {
    await createBareDive('twice', profile: points(3000));
    await repository.saveEditedProfile('twice', points(3300));
    await repository.saveEditedProfile('twice', points(2400));
    await expectSpan('twice', 2400);
  });

  test('re-activating a computer-owned original hides the inactive '
      'edit', () async {
    await createComputer('comp-1');
    await createBareDive('reactivated');
    final originalId = await series.insertSeries(
      diveId: 'reactivated',
      computerId: 'comp-1',
      samples: samples(3000),
    );
    await repository.saveEditedProfile('reactivated', points(3600));
    await series.activateSeriesForDive(
      diveId: 'reactivated',
      seriesId: originalId,
    );
    await expectSpan('reactivated', 3000);
  });

  test("an edit keeps a secondary computer's recording in the span", () async {
    await createComputer('comp-1');
    await createComputer('comp-2');
    await createBareDive('two-computers');
    await createSource(
      'source-1',
      diveId: 'two-computers',
      computerId: 'comp-1',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
    );
    await createSource(
      'source-2',
      diveId: 'two-computers',
      computerId: 'comp-2',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
    );
    await series.insertSeries(
      diveId: 'two-computers',
      computerId: 'comp-1',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'two-computers',
      computerId: 'comp-2',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3300),
    );
    await repository.saveEditedProfile('two-computers', points(2400));
    // The primary computer's original is superseded; the other computer's
    // recording is not part of the edited family and still counts.
    await expectSpan('two-computers', 3300);
  });
}
