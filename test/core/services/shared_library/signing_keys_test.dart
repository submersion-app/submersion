import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';
import 'shared_library_service_test.dart' show device, seedLibrary;

/// Each library is signed with the key its own membership holds, the one
/// its owners approved, even where the profile's memberships came to hold
/// different keys (issue #2567).
void main() {
  tearDown(() async {
    try {
      await tearDownTestDatabase();
    } catch (_) {}
  });

  test('a library signs with its own membership key', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    final svc = await device(cloud, 'a');
    // Another membership of the profile, made on another device before
    // personal sync met, with a key of its own.
    final other = await LibrarySigner.generate();
    await SharedLibraryStore().upsertLibrary(
      const SharedLibrary(
        id: 'B',
        name: 'Wreck Survey',
        connectedAccountId: 'acc',
        prefix: 'wrecks',
      ),
    );
    await SharedLibraryStore().upsertMembership(
      SharedLibraryMembership(
        id: 'aaa',
        diverId: 'd-a',
        libraryId: 'B',
        memberId: 'a',
        displayName: 'a',
        libraryName: 'Wreck Survey',
        backendKind: 's3',
        signingKey: other,
      ),
    );
    final result = await svc.sync('L', diverId: 'd-a');
    expect(result.status, SharedLibrarySyncStatus.success);
    final cards = await SharedLibraryTransport(
      cloud,
      prefix: 'site-sync',
    ).listMembers();
    expect(
      cards.singleWhere((m) => m.memberId == 'a').publicKey,
      (await testMemberKey('a')).publicKey,
    );
  });
}
