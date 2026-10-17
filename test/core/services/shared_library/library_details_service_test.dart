import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/library_details_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

Future<void> _diver(String id) => DiverRepository().createDiver(
  Diver(id: id, name: id, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
);

void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryStore store;
  late LibraryDetailsService details;
  late SharedLibrary lib;
  late SharedLibraryTransport t;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Survey bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() async {
    await setUpTestDatabase();
    await _diver('d1');
    cloud = FakeCloudStorageProvider();
    store = SharedLibraryStore();
    final membership = SharedLibraryMembershipService(
      store: store,
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
      recoveryKdf: const KdfParams(m: 1024, t: 1),
    );
    lib = await membership.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await membership.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bob',
    );
    t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    details = LibraryDetailsService(
      store: store,
      transportFor: (l) async =>
          SharedLibraryTransport(cloud, prefix: l.prefix),
    );
  });

  tearDown(() async {
    SyncCoordinator.reset();
    await tearDownTestDatabase();
  });

  test(
    'owner saves name and description to info.json and the local rows',
    () async {
      await t.writeInfo({...?await t.readInfo(), 'icon': 'reef'});
      await details.save(
        libraryId: lib.id,
        diverId: 'd1',
        name: '  Group Sites ',
        description: ' Our dives ',
      );
      final info = (await t.readInfo())!;
      expect(info['name'], 'Group Sites');
      expect(info['description'], 'Our dives');
      expect(info['icon'], 'reef');
      final row = (await store.getLibrary(lib.id))!;
      expect(row.name, 'Group Sites');
      expect(row.description, 'Our dives');
      for (final m in await store.membershipsForLibrary(lib.id)) {
        expect(m.libraryName, 'Group Sites');
      }
    },
  );

  test('empty description removes the key', () async {
    await details.save(
      libraryId: lib.id,
      diverId: 'd1',
      name: 'Reef Survey',
      description: 'Group sites',
    );
    await details.save(
      libraryId: lib.id,
      diverId: 'd1',
      name: 'Reef Survey',
      description: '   ',
    );
    expect((await t.readInfo())!.containsKey('description'), isFalse);
    expect((await store.getLibrary(lib.id))!.description, isNull);
  });

  test('non-owner is refused', () async {
    await expectLater(
      details.save(libraryId: lib.id, diverId: 'd2', name: 'Mine'),
      throwsA(isA<NotLibraryOwnerError>()),
    );
    expect((await t.readInfo())!['name'], 'Reef Survey');
  });

  test('blank or over-long name is refused', () async {
    await expectLater(
      details.save(libraryId: lib.id, diverId: 'd1', name: '  '),
      throwsArgumentError,
    );
    await expectLater(
      details.save(
        libraryId: lib.id,
        diverId: 'd1',
        name: 'x' * (LibraryDetailsService.maxNameLength + 1),
      ),
      throwsArgumentError,
    );
    await expectLater(
      details.save(
        libraryId: lib.id,
        diverId: 'd1',
        name: 'Reef',
        description: 'x' * (LibraryDetailsService.maxDescriptionLength + 1),
      ),
      throwsArgumentError,
    );
    expect((await t.readInfo())!['name'], 'Reef Survey');
  });

  test('an owner whose writes are held is refused', () async {
    // An ownership reset waits for this member's answer.
    await store.setLibraryStatus(
      lib.id,
      pendingRoles: const SharedLibraryRoles(owners: {'x'}),
    );
    await expectLater(
      details.save(libraryId: lib.id, diverId: 'd1', name: 'Held'),
      throwsA(isA<LibraryWritesHeldError>()),
    );
    expect((await t.readInfo())!['name'], 'Reef Survey');
  });

  test('an owner repairs an unreadable info.json', () async {
    // Any member whose keys can write the folder can break it.
    cloud.seedFile(
      SharedLibraryLayout.infoFile,
      Uint8List.fromList(utf8.encode('not json')),
    );
    await details.save(libraryId: lib.id, diverId: 'd1', name: 'Fixed');
    expect((await t.readInfo())!['name'], 'Fixed');
    expect((await store.getLibrary(lib.id))!.name, 'Fixed');
  });

  test('a save waits for a running sync', () async {
    final release = Completer<void>();
    final running = SyncCoordinator.run(() => release.future);
    final saving = details.save(
      libraryId: lib.id,
      diverId: 'd1',
      name: 'Later',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await store.getLibrary(lib.id))!.name, 'Reef Survey');
    release.complete();
    await running;
    await saving;
    expect((await store.getLibrary(lib.id))!.name, 'Later');
  });

  test('a refused write changes nothing locally', () async {
    cloud.failUploads = true;
    await expectLater(
      details.save(
        libraryId: lib.id,
        diverId: 'd1',
        name: 'Group Sites',
        description: 'Our dives',
      ),
      throwsA(anything),
    );
    final row = (await store.getLibrary(lib.id))!;
    expect(row.name, 'Reef Survey');
    expect(row.description, isNull);
  });
}
