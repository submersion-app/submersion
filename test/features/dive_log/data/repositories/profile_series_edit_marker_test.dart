import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_import/data/services/dive_reimport_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #4386: `dive_profile_series.is_edit` says a series is the diver's
/// manual edit, so a re-parse, a file resync and a computer relink can keep
/// it once it is demoted. Before it, an edit was read off its shape (live,
/// no computer, a generation of its source demoted beneath), which the
/// revision picker reverses when the diver re-activates the original.
void main() {
  late AppDatabase db;
  late ProfileSeriesRepository series;

  setUp(() async {
    db = await setUpTestDatabase();
    series = ProfileSeriesRepository();
  });

  tearDown(tearDownTestDatabase);

  const diveId = 'dive-1';

  Future<void> seedDive() => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: diveId,
          diveDateTime: 1000,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );

  Future<void> seedComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion.insert(
          id: id,
          name: 'Comp $id',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );

  Future<void> seedSource(
    String id, {
    bool isPrimary = true,
    String sourceFormat = 'dive_computer',
    bool withRawData = false,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: diveId,
          isPrimary: Value(isPrimary),
          sourceFormat: Value(sourceFormat),
          rawData: Value(withRawData ? Uint8List.fromList([1, 2, 3]) : null),
          importedAt: DateTime.fromMillisecondsSinceEpoch(0),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );

  /// The parse a download wrote for [sourceId], with no computer.
  Future<String> seedParse(String sourceId, {bool? isEdit = false}) =>
      series.insertSeries(
        diveId: diveId,
        sourceId: sourceId,
        isEdit: isEdit,
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 60, depth: 30.0),
        ],
        now: 1000,
      );

  /// Saves a manual edit through the profile editor's path and returns it.
  Future<String> saveEdit() async {
    await DiveRepository().saveEditedProfile(diveId, const [
      domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
      domain.DiveProfilePoint(timestamp: 60, depth: 17.0),
      domain.DiveProfilePoint(timestamp: 120, depth: 16.0),
    ]);
    return (await series.primarySeriesIdForDive(diveId))!;
  }

  Future<Map<String, DiveProfileSeriesRow>> rowsById() async => {
    for (final r in await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.diveId.equals(diveId))).get())
      r.id: r,
  };

  group('writers', () {
    test('saveEditedProfile marks the edit', () async {
      await seedDive();
      await seedSource('comp-a');
      final parse = await seedParse('comp-a');

      final edit = await saveEdit();

      final rows = await rowsById();
      expect(rows[edit]!.isEdit, isTrue);
      expect(rows[parse]!.isEdit, isFalse);
    });

    test('a series written without a marker is unknown, not a parse', () async {
      await seedDive();
      await seedSource('comp-a');
      final id = await seedParse('comp-a', isEdit: null);

      expect((await rowsById())[id]!.isEdit, isNull);
    });

    test('the domain entity carries the marker', () async {
      await seedDive();
      await seedSource('comp-a');
      await seedParse('comp-a');
      final edit = await saveEdit();

      final read = await series.getSeriesById(edit);
      expect(read!.isEdit, isTrue);
    });
  });

  group('liveEditIdsOf', () {
    ({
      String id,
      String? computerId,
      String? sourceId,
      bool isPrimary,
      bool? isEdit,
    })
    row(
      String id, {
      String? sourceId = 'src',
      required bool isPrimary,
      bool? isEdit,
    }) => (
      id: id,
      computerId: null,
      sourceId: sourceId,
      isPrimary: isPrimary,
      isEdit: isEdit,
    );

    test('a live parse over a demoted edit of its source is no edit', () {
      // The shape a re-activated original leaves: before the marker it read
      // as the edit, and the edit beneath it as an old generation.
      final ids = ProfileSeriesRepository.liveEditIdsOf([
        row('original', isPrimary: true, isEdit: false),
        row('edit', isPrimary: false, isEdit: true),
      ]);
      expect(ids, isEmpty);
    });

    test('a live marked edit is one with nothing beneath it', () {
      final ids = ProfileSeriesRepository.liveEditIdsOf([
        row('edit', isPrimary: true, isEdit: true),
      ]);
      expect(ids, {'edit'});
    });

    test('an unmarked series keeps the shape rule', () {
      final ids = ProfileSeriesRepository.liveEditIdsOf([
        row('legacy-edit', isPrimary: true),
        row('legacy-parse', isPrimary: false),
      ]);
      expect(ids, {'legacy-edit'});
    });

    test('an unmarked original over a demoted marked edit is no edit', () {
      // A series a writer left unmarked, re-activated over the edit made
      // from it: the edit beneath is not a generation it superseded.
      final ids = ProfileSeriesRepository.liveEditIdsOf([
        row('original', isPrimary: true),
        row('edit', isPrimary: false, isEdit: true),
      ]);
      expect(ids, isEmpty);
    });

    test('an unmarked edit over an unmarked parse and a marked edit is '
        'still one', () {
      final ids = ProfileSeriesRepository.liveEditIdsOf([
        row('legacy-edit', isPrimary: true),
        row('older-edit', isPrimary: false, isEdit: true),
        row('parse', isPrimary: false),
      ]);
      expect(ids, {'legacy-edit'});
    });
  });

  group('hasLiveEdit', () {
    test('a live series marked as a parse is no edit', () async {
      await seedDive();
      await seedSource('comp-a');
      await seedParse('comp-a');

      expect(await series.hasLiveEdit(diveId, sourceId: 'comp-a'), isFalse);
    });

    test('a live marked edit is one', () async {
      await seedDive();
      await seedSource('comp-a');
      await seedParse('comp-a');
      await saveEdit();

      expect(await series.hasLiveEdit(diveId, sourceId: 'comp-a'), isTrue);
    });
  });

  test('createDive marks its profile as no edit', () async {
    final created = await DiveRepository().createDive(
      domain.Dive(
        id: 'created',
        dateTime: DateTime.utc(2026, 1, 15, 10),
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
          domain.DiveProfilePoint(timestamp: 60, depth: 12.0),
        ],
      ),
    );

    final rows = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.diveId.equals(created.id))).get();
    expect(rows.single.isEdit, isFalse);
  });

  group('a re-activated original over a demoted edit', () {
    pigeon.ParsedDive parsedDive() => pigeon.ParsedDive(
      fingerprint: 'fp',
      dateTimeYear: 2026,
      dateTimeMonth: 1,
      dateTimeDay: 15,
      dateTimeHour: 10,
      dateTimeMinute: 0,
      dateTimeSecond: 0,
      maxDepthMeters: 12.0,
      avgDepthMeters: 8.0,
      durationSeconds: 3000,
      samples: [
        pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
        pigeon.ProfileSample(timeSeconds: 30, depthMeters: 12.0),
        pigeon.ProfileSample(timeSeconds: 60, depthMeters: 11.0),
        pigeon.ProfileSample(timeSeconds: 90, depthMeters: 0.0),
      ],
      tanks: [],
      gasMixes: [],
      events: [],
    );

    /// Steps 1 and 2 of the report: source [sourceId] with its parse and an
    /// edit, then the original made live again in the revision picker.
    Future<({String original, String edit})> reactivateOriginal(
      String sourceId,
    ) async {
      final original = await seedParse(sourceId);
      final edit = await saveEdit();
      await series.activateSeriesForDive(diveId: diveId, seriesId: original);
      final rows = await rowsById();
      expect(rows[original]!.isPrimary, isTrue);
      expect(rows[edit]!.isPrimary, isFalse);
      return (original: original, edit: edit);
    }

    test('a re-parse of a source with no computer keeps the edit, and the '
        'fresh parse replaces the original as the live series', () async {
      await seedDive();
      await seedSource('comp-a', withRawData: true);
      final ids = await reactivateOriginal('comp-a');

      await ReparseService(db: db).applyParsedUpdate(
        diveId: diveId,
        sourceRowId: 'comp-a',
        parsed: parsedDive(),
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );

      final rows = await rowsById();
      expect(
        rows[ids.edit],
        isNotNull,
        reason: "the diver's edit is not the source's to replace",
      );
      expect(rows[ids.edit]!.isPrimary, isFalse);
      expect(rows[ids.edit]!.isEdit, isTrue);
      expect(rows.containsKey(ids.original), isFalse);
      final fresh = rows.values.where(
        (r) => r.id != ids.edit && r.sourceId == 'comp-a',
      );
      expect(fresh.single.sampleCount, 4);
      expect(fresh.single.isPrimary, isTrue);
      expect(fresh.single.isEdit, isFalse);
    });

    test('a re-parse keeps an older demoted edit beneath a live one', () async {
      await seedDive();
      await seedSource('comp-a', withRawData: true);
      await seedParse('comp-a');
      final first = await saveEdit();
      final second = await saveEdit();

      await ReparseService(db: db).applyParsedUpdate(
        diveId: diveId,
        sourceRowId: 'comp-a',
        parsed: parsedDive(),
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );

      final rows = await rowsById();
      expect(rows[first]!.isPrimary, isFalse);
      expect(rows[second]!.isPrimary, isTrue);
      final fresh = rows.values.where((r) => r.isEdit == false);
      expect(fresh.single.isPrimary, isFalse);
    });

    test(
      'a file resync keeps the edit, and the fresh parse goes live',
      () async {
        await seedDive();
        await seedSource('src-file', sourceFormat: 'uddf');
        final ids = await reactivateOriginal('src-file');

        await DiveReimportService(db: db).applyReimport(
          diveId: diveId,
          diveData: {
            'profile': const [
              {'timestamp': 0, 'depth': 0.0},
              {'timestamp': 60, 'depth': 21.0},
              {'timestamp': 120, 'depth': 0.0},
            ],
          },
          now: DateTime(2026, 9, 3),
        );

        final rows = await rowsById();
        expect(rows[ids.edit], isNotNull);
        expect(rows[ids.edit]!.isPrimary, isFalse);
        expect(rows.containsKey(ids.original), isFalse);
        final fresh = rows.values.where((r) => r.id != ids.edit);
        expect(fresh.single.sampleCount, 3);
        expect(fresh.single.isPrimary, isTrue);
        expect(fresh.single.isEdit, isFalse);
      },
    );

    test('a file resync keeps the edit over an unmarked original', () async {
      // The original came from a writer that leaves the mark unset.
      await seedDive();
      await seedSource('src-file', sourceFormat: 'uddf');
      final original = await seedParse('src-file', isEdit: null);
      final edit = await saveEdit();
      await series.activateSeriesForDive(diveId: diveId, seriesId: original);

      await DiveReimportService(db: db).applyReimport(
        diveId: diveId,
        diveData: {
          'profile': const [
            {'timestamp': 0, 'depth': 0.0},
            {'timestamp': 60, 'depth': 21.0},
            {'timestamp': 120, 'depth': 0.0},
          ],
        },
        now: DateTime(2026, 9, 3),
      );

      final rows = await rowsById();
      expect(rows[edit]!.isPrimary, isFalse);
      expect(rows.containsKey(original), isFalse);
      final fresh = rows.values.where((r) => r.id != edit);
      expect(fresh.single.isPrimary, isTrue);
    });

    test('a computer relink leaves the demoted edit off the strand', () async {
      // Relinked, the edit would sit on the computer's strand, which that
      // computer's next re-parse replaces whole.
      await seedDive();
      await seedComputer('comp-1');
      await seedSource('comp-a');
      final ids = await reactivateOriginal('comp-a');

      await series.relinkComputer('comp-1', [diveId]);

      final rows = await rowsById();
      expect(rows[ids.edit]!.computerId, isNull);
    });
  });
}
