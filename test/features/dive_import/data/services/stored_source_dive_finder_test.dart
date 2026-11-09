import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/data/services/stored_source_dive_finder.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

class _FakeImportedFiles extends ImportedFileRepository {
  final Map<String, Uint8List> files;
  _FakeImportedFiles(this.files);

  @override
  Future<Uint8List?> read(String id) async => files[id];
}

class _CountingParser implements ImportParser {
  final ImportPayload payload;
  var parses = 0;
  _CountingParser(this.payload);

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.uddf];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    parses++;
    return payload;
  }
}

/// The stored-file lookup resync and the transmitter slot matcher share
/// (issue #4347).
void main() {
  late AppDatabase db;
  final when = DateTime(2026, 9, 1, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
  });

  tearDown(() async => db.close());

  Future<void> seedDive(
    String id, {
    DateTime? dateTime,
    String? importedFileId = 'file-uddf',
    String sourceFileFormat = 'uddf',
  }) async {
    final at = dateTime ?? when;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: at.millisecondsSinceEpoch,
            maxDepth: const Value(18.0),
            bottomTime: const Value(40 * 60),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    if (importedFileId == null) return;
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            isPrimary: const Value(true),
            importedAt: at,
            createdAt: at,
            sourceFileFormat: Value(sourceFileFormat),
            importedFileId: Value(importedFileId),
          ),
        );
  }

  Map<String, dynamic> parsedAt(DateTime at, {String? diverKey}) => {
    'dateTime': at,
    'maxDepth': 18.2,
    'duration': const Duration(minutes: 41),
    ...?(diverKey == null ? null : {SourceDiver.mapKey: diverKey}),
  };

  StoredSourceDiveFinder finder(
    List<Map<String, dynamic>> dives, {
    _CountingParser? parser,
  }) => StoredSourceDiveFinder(
    db: db,
    importedFiles: _FakeImportedFiles({'file-uddf': Uint8List(0)}),
    parserFor: (_) =>
        parser ??
        _CountingParser(
          ImportPayload(entities: {ImportEntityType.dives: dives}),
        ),
  );

  test('a dive that no longer exists is diveMissing', () async {
    final lookup = await finder(const []).find('gone');

    expect(lookup.failure, DiveResyncFailure.diveMissing);
    expect(lookup.parsedDive, isNull);
  });

  test('a dive without a stored file is noStoredFile', () async {
    await seedDive('d1', importedFileId: null);

    final lookup = await finder(const []).find('d1');

    expect(lookup.failure, DiveResyncFailure.noStoredFile);
  });

  test('a format resync cannot read is unsupportedFormat', () async {
    await seedDive('d1', sourceFileFormat: 'csv');

    final lookup = await finder(const []).find('d1');

    expect(lookup.failure, DiveResyncFailure.unsupportedFormat);
  });

  test('a stored file that is gone is storedFileMissing', () async {
    await seedDive('d1', importedFileId: 'file-gone');

    final lookup = await finder(const []).find('d1');

    expect(lookup.failure, DiveResyncFailure.storedFileMissing);
  });

  test('no probable match is noMatchingDive', () async {
    await seedDive('d1');

    final lookup = await finder([
      parsedAt(when.add(const Duration(days: 3))),
    ]).find('d1');

    expect(lookup.failure, DiveResyncFailure.noMatchingDive);
  });

  test('two divers matching with no stored key is ambiguousDiver', () async {
    await seedDive('d1');

    final lookup = await finder([
      parsedAt(when, diverKey: 'a'),
      parsedAt(when, diverKey: 'b'),
    ]).find('d1');

    expect(lookup.failure, DiveResyncFailure.ambiguousDiver);
  });

  test('picks the matching dive out of a multi-dive file', () async {
    await seedDive('d1');

    final lookup = await finder([
      parsedAt(when.add(const Duration(days: 3))),
      parsedAt(when),
    ]).find('d1');

    expect(lookup.failure, isNull);
    expect(lookup.parsedDive!['dateTime'], when);
  });

  test('findMany parses a shared file once and skips dives it cannot '
      'find', () async {
    final second = when.add(const Duration(days: 1));
    await seedDive('d1');
    await seedDive('d2', dateTime: second);
    await seedDive('d3', importedFileId: null);
    final parser = _CountingParser(
      ImportPayload(
        entities: {
          ImportEntityType.dives: [parsedAt(when), parsedAt(second)],
        },
      ),
    );

    final found = await finder(
      const [],
      parser: parser,
    ).findMany(['d1', 'd2', 'd3']);

    expect(parser.parses, 1);
    expect(found.keys, unorderedEquals(['d1', 'd2']));
    expect(found['d2']!['dateTime'], second);
  });
}
