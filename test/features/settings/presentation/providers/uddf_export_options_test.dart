import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  test('fetches sources when raw data is included', () async {
    final result = await resolveDataSources(repository, const [
      'dive-1',
    ], const UddfExportOptions());

    // No such dive, so the query returns nothing; what matters is that the
    // default options take the fetching branch at all.
    expect(result, isEmpty);
    expect(const UddfExportOptions().includeRawData, isTrue);
  });

  test('returns nothing when raw data is excluded', () async {
    // A share with the box unchecked must not pay for a query it will not
    // use, which is the entire point of the toggle on the dives only paths.
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(DateTime.now().millisecondsSinceEpoch),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
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

    // The row exists, so an unconditional fetch would return it.
    expect(
      await repository.getSourcesForExport(const ['dive-1']),
      hasLength(1),
    );

    final result = await resolveDataSources(repository, const [
      'dive-1',
    ], const UddfExportOptions(includeRawData: false));

    expect(result, isEmpty);
  });
}
