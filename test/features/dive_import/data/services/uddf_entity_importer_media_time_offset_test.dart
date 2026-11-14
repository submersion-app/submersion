import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/test_database.dart';

/// A restored dive keeps its media time shift (issue #4539). The round-trip
/// test stops at the parsed map; this is the step that writes the dive.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('a parsed shift lands on the restored dive', () async {
    final diverId = await createTestDiver();
    final data = UddfImportResult(
      dives: [
        {
          'dateTime': DateTime.utc(2026, 5, 6, 9, 4),
          'maxDepth': 27.6,
          'diveNumber': 1,
          'mediaTimeOffsetSeconds': -47,
        },
        {
          'dateTime': DateTime.utc(2026, 5, 7, 9),
          'maxDepth': 20.0,
          'diveNumber': 2,
        },
      ],
    );

    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    final dives = await DiveRepository().getAllDives();
    expect(
      {for (final dive in dives) dive.diveNumber: dive.mediaTimeOffsetSeconds},
      {1: -47, 2: 0},
    );
  });
}
