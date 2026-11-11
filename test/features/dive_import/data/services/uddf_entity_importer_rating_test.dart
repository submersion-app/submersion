import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/test_database.dart';

/// Every importer hands its dives' ratings to the entity importer, which
/// stores 1 to 5 stars whatever scale a parser passed on: a rating of 0 is an
/// unrated dive and one above 5 came from a 1 to 10 scale (issue #4415).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<Map<int, int?>> importRatings(List<int?> ratings) async {
    final diverId = await createTestDiver();
    final data = UddfImportResult(
      dives: [
        for (var i = 0; i < ratings.length; i++)
          {
            'dateTime': DateTime.utc(2018, 2, 10 + i, 10),
            'maxDepth': 20.0,
            'diveNumber': i + 1,
            'rating': ratings[i],
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
    return {for (final dive in dives) dive.diveNumber!: dive.rating};
  }

  test('a star count on the 1 to 5 scale is kept', () async {
    expect(await importRatings([1, 3, 5, null]), {1: 1, 2: 3, 3: 5, 4: null});
  });

  test('0 is stored as unrated and a value above 5 is halved', () async {
    expect(await importRatings([0, 6, 10]), {1: null, 2: 3, 3: 5});
  });
}
