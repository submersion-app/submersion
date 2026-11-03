import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_fetch.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  /// One dive with one data source row, so a fetch has something to return.
  Future<void> seedSource() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-1'),
            diveId: const Value('dive-1'),
            isPrimary: const Value(true),
            importedAt: Value(DateTime(2019, 6, 2)),
            createdAt: Value(DateTime(2019, 6, 2)),
          ),
        );
  }

  test('fetches the sources', () async {
    // The row has to exist, or this would pass just as well against a
    // resolveDataSources that never queried at all.
    await seedSource();

    final result = await resolveDataSources(repository, const ['dive-1']);

    expect(result, hasLength(1));
    expect(result.single.diveId, 'dive-1');
  });

  // Issue #4180: the rows are the dive's computers and their samples, so an
  // export with the raw data box unticked still needs them. Only the writers
  // drop the bytes.
  for (final includeRawData in [true, false]) {
    test('the export fetch returns the sources with includeRawData '
        '$includeRawData', () async {
      await seedSource();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(uddfSourceFetchProvider)(const [
        'dive-1',
      ], UddfExportOptions(includeRawData: includeRawData));

      expect(result.map((s) => s.id), ['src-1']);
    });
  }
}
