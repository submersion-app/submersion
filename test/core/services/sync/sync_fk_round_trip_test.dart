import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/sync_test_helpers.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Regression tests for the FK violations the on-device diagnosis surfaced
/// (see docs/superpowers/findings/2026-06-02-icloud-sync-diagnosis.md and
/// test/core/services/sync/_diagnose_apply_failures_test.dart).
///
/// Two distinct intra-payload referential bugs are exercised:
///   1) Apply-order FK violation: a dive references a dive site that is
///      applied *later* in the static merge order, so without deferred FK
///      checks the dive insert fails and never reaches the receiving DB.
///   2) Missing entity in payload: `SyncData` had no `courses` field, so any
///      `courseId` set on a dive or certification was a dangling reference
///      on every receiving device.
void main() {
  group('Sync FK round-trip (intra-payload references)', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    test('a dive with siteId round-trips A -> B even though dives apply before '
        'diveSites in the static order', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();

      // Device A: a dive site, plus a dive that points at it. We build the
      // dive via the domain repo so we get every non-nullable column set,
      // then re-upsert with siteId pointed at the site.
      await serializer.upsertRecord('diveSites', {
        'id': 'site-fk-1',
        'name': 'Reef Wall',
        'description': '',
        'notes': '',
        'isShared': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-fk-1', diveNumber: 77),
      );
      final original = await serializer.fetchRecord('dives', 'dive-fk-1');
      expect(original, isNotNull, reason: 'dive seeded on device A');
      await serializer.upsertRecord('dives', {
        ...original!,
        'siteId': 'site-fk-1',
        'updatedAt': 2000,
      });

      await buildService().performSync(); // device A push

      // Device B impersonation: drop both records and reset sync state so
      // the pull genuinely re-applies them from the cloud payload.
      await serializer.deleteRecord('dives', 'dive-fk-1');
      await serializer.deleteRecord('diveSites', 'site-fk-1');
      await impersonateFreshDevice();
      expect(await serializer.fetchRecord('dives', 'dive-fk-1'), isNull);
      expect(await serializer.fetchRecord('diveSites', 'site-fk-1'), isNull);

      final pull = await buildService().performSync();
      expect(
        pull.status,
        isNot(SyncResultStatus.error),
        reason:
            'pull must succeed; got ${pull.status} (${pull.message}). '
            'Without deferred FK checks the dive insert fails because the '
            'static merge order applies dives before diveSites.',
      );

      final restoredSite = await serializer.fetchRecord(
        'diveSites',
        'site-fk-1',
      );
      expect(restoredSite, isNotNull);

      final restoredDive = await serializer.fetchRecord('dives', 'dive-fk-1');
      expect(
        restoredDive,
        isNotNull,
        reason:
            'dive should round-trip even with siteId referencing a '
            'sibling record that comes later in the apply order',
      );
      expect(restoredDive!['siteId'], 'site-fk-1');
    });

    test('a course + a dive referencing it both round-trip A -> B '
        '(courses must be in SyncData)', () async {
      final serializer = SyncDataSerializer();
      final diveRepo = DiveRepository();

      // Courses require a Diver (FK NOT NULL, cascade). Drift's `fromJson`
      // does NOT honour SQL defaults, so columns like `medicalNotes` /
      // `notes` / `isDefault` must be supplied explicitly.
      await serializer.upsertRecord('divers', {
        'id': 'diver-fk-1',
        'name': 'Test Diver',
        'medicalNotes': '',
        'notes': '',
        'isDefault': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      // Device A: a course owned by the diver, plus a dive that links to it.
      await serializer.upsertRecord('courses', {
        'id': 'course-fk-1',
        'diverId': 'diver-fk-1',
        'name': 'Advanced Open Water Diver',
        'agency': 'PADI',
        'startDate': 1700000000000,
        'notes': '',
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await diveRepo.createDive(
        createTestDiveWithBottomTime(id: 'dive-course-1', diveNumber: 78),
      );
      final origDive = await serializer.fetchRecord('dives', 'dive-course-1');
      await serializer.upsertRecord('dives', {
        ...origDive!,
        'courseId': 'course-fk-1',
        'updatedAt': 2000,
      });

      await buildService().performSync(); // device A push

      // Device B impersonation: drop the course + dive, reset sync state.
      // Leave the diver in place so the FK comparison stays focused on the
      // course propagation itself.
      await serializer.deleteRecord('dives', 'dive-course-1');
      await serializer.deleteRecord('courses', 'course-fk-1');
      await impersonateFreshDevice();

      final pull = await buildService().performSync();
      expect(
        pull.status,
        isNot(SyncResultStatus.error),
        reason: 'pull must succeed; got ${pull.status} (${pull.message})',
      );

      final restoredCourse = await serializer.fetchRecord(
        'courses',
        'course-fk-1',
      );
      expect(
        restoredCourse,
        isNotNull,
        reason:
            'course must round-trip via SyncData (was previously '
            'omitted from the payload entirely)',
      );
      expect(restoredCourse!['name'], 'Advanced Open Water Diver');

      // Verify via the domain repo: SyncDataSerializer.fetchRecord still uses
      // a hand-maintained `_diveToJson` that doesn't include courseId
      // (asymmetric with export, only feeds conflict comparison which reads
      // updatedAt). The DB row itself is what matters here.
      final restoredDive = await diveRepo.getDiveById('dive-course-1');
      expect(restoredDive, isNotNull);
      expect(
        restoredDive!.courseId,
        'course-fk-1',
        reason: 'dive must keep its course link after sync',
      );
    });
  });
}
