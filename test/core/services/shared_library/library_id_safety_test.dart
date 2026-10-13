import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';

/// A library id read from storage names local folders (its backups), so
/// one that could leave them is refused (issue #2567).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('a manifest whose id could leave a folder is no library', () async {
    final cloud = FakeCloudStorageProvider();
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    await t.writeManifest({
      'id': '../../escape',
      'formatVersion': SharedLibraryLayout.formatVersion,
    });
    await t.writeRoles(await signedTestRoles(owners: {'o'}));
    final memberships = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
    );
    await expectLater(
      memberships.join(
        account: ConnectedAccount(
          id: 'acc',
          kind: AccountKind.s3,
          label: 'Survey bucket',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        prefix: 'site-sync',
        diverId: 'd',
        displayName: 'Ann',
      ),
      throwsStateError,
    );
    expect(await SharedLibraryStore().getLibraries(), isEmpty);
  });

  test('library ids are checked as safe folder names', () {
    expect(
      SharedLibraryLayout.isValidLibraryId(
        '6f1c2a9e-0b7d-4c1a-9f0e-2d3c4b5a6e7f',
      ),
      isTrue,
    );
    for (final bad in ['', '..', '../x', 'a/b', r'a\b', 'x' * 200]) {
      expect(SharedLibraryLayout.isValidLibraryId(bad), isFalse, reason: bad);
    }
  });
}
