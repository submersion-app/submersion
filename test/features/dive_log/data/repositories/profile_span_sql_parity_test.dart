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
/// from `Dive.profile`, which is the merged read (`getMergedProfile`) on a dive
/// routed for its samples. For a dive with a profile but no runtime, no exit
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
    required String? computerId,
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
    final tripDive = (await repository.getDivesByIdsWithoutSamples([
      id,
    ])).single;
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

  // Issue #4960: the computer's recording activated over an older copy of its
  // own source that has no computer, each a root revision.
  test('activating the computer recording hides a computer-less copy of its '
      'source', () async {
    await createComputer('comp-1');
    await createBareDive('recording');
    await createSource(
      'source-1',
      diveId: 'recording',
      computerId: 'comp-1',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
    );
    await series.insertSeries(
      diveId: 'recording',
      sourceId: 'source-1',
      samples: samples(3600),
    );
    final recordingId = await series.insertSeries(
      diveId: 'recording',
      computerId: 'comp-1',
      sourceId: 'source-1',
      isPrimary: false,
      samples: samples(3000),
    );
    await repository.setActiveProfileSeries('recording', recordingId);
    await expectSpan('recording', 3000);
  });

  test('an edit keeps a second source recorded with no computer in the '
      'span', () async {
    await createComputer('comp-1');
    await createBareDive('file-second');
    await createSource(
      'source-1',
      diveId: 'file-second',
      computerId: 'comp-1',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
    );
    await createSource(
      'source-2',
      diveId: 'file-second',
      computerId: null,
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
    );
    await series.insertSeries(
      diveId: 'file-second',
      computerId: 'comp-1',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'file-second',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3300),
    );
    await repository.saveEditedProfile('file-second', points(2400));
    // The file reading is its own source, not the edited family.
    await expectSpan('file-second', 3300);
  });

  test('with no data sources a second computer keeps its span beside the '
      'active one', () async {
    await createComputer('comp-1');
    await createComputer('comp-2');
    await createBareDive('no-sources');
    await series.insertSeries(
      diveId: 'no-sources',
      computerId: 'comp-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'no-sources',
      computerId: 'comp-2',
      isPrimary: false,
      samples: samples(3300),
    );
    await expectSpan('no-sources', 3300);
  });

  test('a second source row on the primary computer is the primary '
      'family', () async {
    await createComputer('comp-1');
    await createBareDive('same-computer');
    await createSource(
      'source-1',
      diveId: 'same-computer',
      computerId: 'comp-1',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
    );
    // Same computer, so it shows in the primary's chip.
    await createSource(
      'source-1b',
      diveId: 'same-computer',
      computerId: 'comp-1',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
    );
    await series.insertSeries(
      diveId: 'same-computer',
      computerId: 'comp-1',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'same-computer',
      computerId: 'comp-1',
      sourceId: 'source-1b',
      isPrimary: false,
      samples: samples(3300),
    );
    await expectSpan('same-computer', 3000);
  });

  test('an active recording keeps an unfiled computer-less series when the '
      'dive has another source', () async {
    await createComputer('comp-1');
    await createBareDive('unfiled-two');
    await createSource(
      'source-1',
      diveId: 'unfiled-two',
      computerId: 'comp-1',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
    );
    await createSource(
      'source-2',
      diveId: 'unfiled-two',
      computerId: null,
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
    );
    await series.insertSeries(
      diveId: 'unfiled-two',
      computerId: 'comp-1',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    // Written before v154: no source_id ties it to either row.
    await series.insertSeries(
      diveId: 'unfiled-two',
      isPrimary: false,
      samples: samples(3300),
    );
    await expectSpan('unfiled-two', 3300);
  });

  test('an active recording hides an unfiled computer-less copy on a '
      'single-source dive', () async {
    await createComputer('comp-1');
    await createBareDive('unfiled-one');
    await createSource(
      'source-1',
      diveId: 'unfiled-one',
      computerId: 'comp-1',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
    );
    await series.insertSeries(
      diveId: 'unfiled-one',
      computerId: 'comp-1',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'unfiled-one',
      isPrimary: false,
      samples: samples(3300),
    );
    await expectSpan('unfiled-one', 3000);
  });

  // Issue #3654: one download stored twice by two import paths, with no
  // registered computer to tie the rows; they show as one source.
  Future<void> createLooseSource(
    String id, {
    required String diveId,
    required bool isPrimary,
    required DateTime createdAt,
    required String model,
    String? serial,
    String? fileName,
    DateTime? entryTime,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            isPrimary: Value(isPrimary),
            computerModel: Value(model),
            computerSerial: Value(serial),
            sourceFileName: Value(fileName),
            entryTime: Value(entryTime ?? entry),
            duration: const Value(3000),
            maxDepth: const Value(12.0),
            importedAt: createdAt,
            createdAt: createdAt,
          ),
        );
  }

  test('an edit hides the copy a second import path stored of the same '
      'recording', () async {
    await createBareDive('stored-twice');
    await createLooseSource(
      'source-1',
      diveId: 'stored-twice',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
      model: 'Shearwater Perdix 2',
    );
    await createLooseSource(
      'source-2',
      diveId: 'stored-twice',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
      model: 'Perdix 2',
      serial: '0a1b2c3d',
    );
    await series.insertSeries(
      diveId: 'stored-twice',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'stored-twice',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3000),
    );
    await repository.saveEditedProfile('stored-twice', points(2400));
    await expectSpan('stored-twice', 2400);
  });

  test('one recording stored twice collapses when the starts differ '
      'within a second', () async {
    // Dart compares the starts to the second; the column stores whole
    // seconds, so the SQL `=` on the stored value agrees with it.
    await createBareDive('sub-second');
    await createLooseSource(
      'source-1',
      diveId: 'sub-second',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
      model: 'Perdix 2',
      entryTime: entry.add(const Duration(milliseconds: 100)),
    );
    await createLooseSource(
      'source-2',
      diveId: 'sub-second',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
      model: 'Perdix 2',
      entryTime: entry.add(const Duration(milliseconds: 900)),
    );
    await series.insertSeries(
      diveId: 'sub-second',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'sub-second',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3300),
    );
    await repository.saveEditedProfile('sub-second', points(2400));
    await expectSpan('sub-second', 2400);
  });

  test('two computers of one model stay apart when their recordings '
      'differ', () async {
    await createBareDive('two-units');
    await createLooseSource(
      'source-1',
      diveId: 'two-units',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
      model: 'Perdix 2',
      serial: '0a1b2c3d',
    );
    await createLooseSource(
      'source-2',
      diveId: 'two-units',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
      model: 'Perdix 2',
      serial: '0f0f0f0f',
    );
    await series.insertSeries(
      diveId: 'two-units',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'two-units',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3300),
    );
    await repository.saveEditedProfile('two-units', points(2400));
    await expectSpan('two-units', 3300);
  });

  test("an edit keeps a second computer's unfiled recording when the primary "
      'source has no computer', () async {
    await createComputer('comp-2');
    await createBareDive('file-primary');
    await createSource(
      'source-1',
      diveId: 'file-primary',
      computerId: null,
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
    );
    await createSource(
      'source-2',
      diveId: 'file-primary',
      computerId: 'comp-2',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
    );
    await series.insertSeries(
      diveId: 'file-primary',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    // Written before v154: on its computer, but naming no source row.
    await series.insertSeries(
      diveId: 'file-primary',
      computerId: 'comp-2',
      isPrimary: false,
      samples: samples(3300),
    );
    await repository.saveEditedProfile('file-primary', points(2400));
    await expectSpan('file-primary', 3300);
  });

  test('one recording stored twice collapses when only one copy names its '
      'file', () async {
    // Written in the same second, so only the file names tell the imports
    // apart, and one of them has none.
    final written = DateTime.utc(2026, 3, 1, 20);
    await createBareDive('one-named');
    await createLooseSource(
      'source-1',
      diveId: 'one-named',
      isPrimary: true,
      createdAt: written,
      model: 'Shearwater Perdix 2',
    );
    await createLooseSource(
      'source-2',
      diveId: 'one-named',
      isPrimary: false,
      createdAt: written,
      model: 'Perdix 2',
      serial: '0a1b2c3d',
      fileName: 'perdix.xml',
    );
    await series.insertSeries(
      diveId: 'one-named',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'one-named',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3000),
    );
    await repository.saveEditedProfile('one-named', points(2400));
    await expectSpan('one-named', 2400);
  });

  test('one recording stored twice collapses when one model carries a '
      'trailing newline', () async {
    await createBareDive('newline-model');
    await createLooseSource(
      'source-1',
      diveId: 'newline-model',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
      model: 'Shearwater Perdix 2',
    );
    await createLooseSource(
      'source-2',
      diveId: 'newline-model',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
      model: 'Perdix 2\n',
    );
    await series.insertSeries(
      diveId: 'newline-model',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'newline-model',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3000),
    );
    await repository.saveEditedProfile('newline-model', points(2400));
    await expectSpan('newline-model', 2400);
  });

  test('one recording stored twice collapses when a model has inner runs '
      'of whitespace', () async {
    await createBareDive('inner-space-model');
    await createLooseSource(
      'source-1',
      diveId: 'inner-space-model',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
      model: 'Shearwater  Perdix\t2',
    );
    await createLooseSource(
      'source-2',
      diveId: 'inner-space-model',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
      model: 'perdix \r\n  2',
    );
    await series.insertSeries(
      diveId: 'inner-space-model',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'inner-space-model',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3000),
    );
    await repository.saveEditedProfile('inner-space-model', points(2400));
    await expectSpan('inner-space-model', 2400);
  });

  test('one recording stored twice collapses when one copy carries the '
      'Shearwater serial in hex and the other in decimal', () async {
    await createBareDive('hex-decimal-serial');
    await createLooseSource(
      'source-1',
      diveId: 'hex-decimal-serial',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
      model: 'Shearwater Perdix 2',
      serial: '0A1B2C3D',
    );
    await createLooseSource(
      'source-2',
      diveId: 'hex-decimal-serial',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
      model: 'Perdix 2',
      serial: '169552957',
    );
    await series.insertSeries(
      diveId: 'hex-decimal-serial',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'hex-decimal-serial',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3000),
    );
    await repository.saveEditedProfile('hex-decimal-serial', points(2400));
    await expectSpan('hex-decimal-serial', 2400);
  });

  test('one recording stored twice collapses when a model is padded with a '
      'non-breaking space', () async {
    await createBareDive('nbsp-model');
    await createLooseSource(
      'source-1',
      diveId: 'nbsp-model',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 3, 1, 20),
      model: 'Perdix\u00a02',
    );
    await createLooseSource(
      'source-2',
      diveId: 'nbsp-model',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 3, 1, 21),
      model: 'Perdix 2\u00a0',
    );
    await series.insertSeries(
      diveId: 'nbsp-model',
      sourceId: 'source-1',
      samples: samples(3000),
    );
    await series.insertSeries(
      diveId: 'nbsp-model',
      sourceId: 'source-2',
      isPrimary: false,
      samples: samples(3000),
    );
    await repository.saveEditedProfile('nbsp-model', points(2400));
    await expectSpan('nbsp-model', 2400);
  });
}
