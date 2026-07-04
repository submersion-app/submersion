import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Regression tests for issue #474: "Blanking custom dive name doesn't seem to
/// propagate to sync."
///
/// Renaming a dive to a NEW value syncs, but CLEARING the name (null) does not.
/// Root cause: the merge write path applies incoming rows with Drift's
/// `insertOnConflictUpdate(Dive.fromJson(data))`. A data class is serialized
/// via `toColumns(nullToAbsent: true)`, which OMITS a null column from the
/// `ON CONFLICT DO UPDATE SET ...` clause -- so an incoming `name: null` never
/// overwrites the receiving device's existing non-null name. A non-null rename
/// is included and applies; a blank is silently dropped.
void main() {
  group('Clearing a dive name propagates through the sync merge (#474)', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    /// The full JSON of a locally-stored dive that already carries a name,
    /// standing in for the row a receiving device holds before the changeset
    /// that blanks the name arrives.
    Future<Map<String, dynamic>> seedNamedDive(String id) async {
      final serializer = SyncDataSerializer();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: id).copyWith(name: 'Original Name'),
      );
      final seeded = await serializer.fetchRecord('dives', id);
      expect(
        seeded!['name'],
        'Original Name',
        reason: 'precondition: the dive is stored with its name',
      );
      return seeded;
    }

    test(
      'upsertRecords (batched merge path) clears the name when incoming is null',
      () async {
        final serializer = SyncDataSerializer();
        final seeded = await seedNamedDive('dive-clear-batch');

        // Incoming changeset from the other device: same row, name blanked.
        final cleared = {...seeded, 'name': null};
        await serializer.upsertRecords('dives', [cleared]);

        final after = await serializer.fetchRecord('dives', 'dive-clear-batch');
        expect(
          after!['name'],
          isNull,
          reason:
              'THE BUG: a blanked (null) name did not overwrite the stored name',
        );
      },
    );

    test(
      'upsertRecord (single merge path) clears the name when incoming is null',
      () async {
        final serializer = SyncDataSerializer();
        final seeded = await seedNamedDive('dive-clear-single');

        final cleared = {...seeded, 'name': null};
        await serializer.upsertRecord('dives', cleared);

        final after = await serializer.fetchRecord(
          'dives',
          'dive-clear-single',
        );
        expect(
          after!['name'],
          isNull,
          reason:
              'THE BUG: a blanked (null) name did not overwrite the stored name',
        );
      },
    );

    test(
      'a non-null rename still applies through the merge (control)',
      () async {
        final serializer = SyncDataSerializer();
        final seeded = await seedNamedDive('dive-rename-control');

        final renamed = {...seeded, 'name': 'New Name'};
        await serializer.upsertRecords('dives', [renamed]);

        final after = await serializer.fetchRecord(
          'dives',
          'dive-rename-control',
        );
        expect(
          after!['name'],
          'New Name',
          reason: 'a non-null rename must continue to propagate',
        );
      },
    );
  });
}
