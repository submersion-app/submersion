import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/library_connection_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_errors.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';

void main() {
  // The fake keeps one flat file map, so each folder gets a cloud of its own.
  late Map<String, FakeCloudStorageProvider> clouds;
  late SharedLibraryStore store;
  late LibraryConnectionService service;
  late SharedLibraryRoles roles;
  final newAccount = ConnectedAccount(
    id: 'acc2',
    kind: AccountKind.webdav,
    label: 'Group server',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  SharedLibraryTransport at(String prefix) => SharedLibraryTransport(
    clouds.putIfAbsent(prefix, FakeCloudStorageProvider.new),
    prefix: prefix,
  );

  /// A plain copy of library L at [prefix], its roles at [version].
  Future<void> copyAt(String prefix, {int version = 2, String id = 'L'}) async {
    final t = at(prefix);
    await t.writeManifest({
      'id': id,
      'name': 'Reef Survey',
      'formatVersion': 2,
    });
    await t.writeInfo({'name': id == 'L' ? 'Reef Survey' : 'Other Group'});
    await t.writeRoles(
      await signedTestRoles(owners: {'a'}, version: version, libraryId: id),
    );
  }

  Future<SharedLibrary> row() async => (await store.getLibrary('L'))!;

  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    clouds = {};
    store = SharedLibraryStore();
    roles = await signedTestRoles(owners: {'a'}, version: 2);
    await copyAt('a');
    await store.upsertLibrary(
      SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'acc',
        prefix: 'a',
        roles: roles,
        lastSyncAt: DateTime.utc(2026, 5),
        lastError: 'offline',
      ),
    );
    await store.upsertMembership(
      SharedLibraryMembership(
        id: 'ms',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'a',
        displayName: 'Ann',
        libraryName: 'Reef Survey',
        backendKind: 's3',
        locationHint: 'Survey bucket: a',
        signingKey: await testMemberKey('a'),
      ),
    );
    await store.putSiteState(
      const SharedSiteState(
        siteId: 's1',
        libraryId: 'L',
        remoteModifiedTime: '2026-05-01T00:00:00Z',
      ),
    );
    service = LibraryConnectionService(
      store: store,
      transportFor: ({required account, required prefix}) async => at(prefix),
    );
  });

  tearDown(() async {
    SyncCoordinator.reset();
    await tearDownTestDatabase();
  });

  Future<LibraryLocationCheck> check(String prefix, {String? secret}) =>
      service.check(
        libraryId: 'L',
        diverId: 'd1',
        account: newAccount,
        prefix: prefix,
        secret: secret,
      );

  Future<SharedLibrary> repoint(
    String prefix, {
    String? secret,
    bool acceptOlder = false,
  }) => service.repoint(
    libraryId: 'L',
    diverId: 'd1',
    account: newAccount,
    prefix: prefix,
    secret: secret,
    acceptOlder: acceptOlder,
  );

  test(
    'same library at a new folder is same, and repoint moves the row',
    () async {
      await copyAt('b');
      final c = await check('b');
      expect(c.verdict, LibraryLocationVerdict.same);
      expect(c.foundName, 'Reef Survey');
      expect(c.canSave, isTrue);
      final moved = await repoint('b');
      expect(moved.prefix, 'b');
      expect(moved.connectedAccountId, 'acc2');
      expect(moved.roles, roles);
      expect(moved.lastSyncAt, DateTime.utc(2026, 5).toLocal());
      expect(moved.lastError, isNull);
      final ms = (await store.membership(diverId: 'd1', libraryId: 'L'))!;
      expect(ms.locationHint, 'Group server: b');
      expect(ms.backendKind, 'webdav');
      expect((await store.getSiteState('s1'))!.remoteModifiedTime, isNull);
    },
  );

  test('saving the same location again changes nothing else', () async {
    final sameAccount = ConnectedAccount(
      id: 'acc',
      kind: AccountKind.s3,
      label: 'Survey bucket',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final before = (await store.membership(diverId: 'd1', libraryId: 'L'))!;
    final again = await service.repoint(
      libraryId: 'L',
      diverId: 'd1',
      account: sameAccount,
      prefix: 'a',
    );
    expect(again.prefix, 'a');
    expect(again.lastError, isNull);
    // No content compare forced, no membership change sent to other devices.
    expect(
      (await store.getSiteState('s1'))!.remoteModifiedTime,
      '2026-05-01T00:00:00Z',
    );
    expect(await store.membership(diverId: 'd1', libraryId: 'L'), before);
  });

  test(
    'repoint writes every local profile\'s card at the new folder',
    () async {
      await DiverRepository().createDiver(
        Diver(
          id: 'd2',
          name: 'Bob',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await store.upsertMembership(
        SharedLibraryMembership(
          id: 'ms2',
          diverId: 'd2',
          libraryId: 'L',
          memberId: 'c',
          displayName: 'Bob',
          libraryName: 'Reef Survey',
          backendKind: 's3',
          signingKey: await testMemberKey('c'),
        ),
      );
      await copyAt('b');
      await repoint('b');
      final cards = await at('b').listMembers();
      expect(cards.map((m) => m.memberId), containsAll(['a', 'c']));
      expect(cards.every((m) => m.cardVerified), isTrue);
    },
  );

  Future<void> secondProfile() async {
    await DiverRepository().createDiver(
      Diver(
        id: 'd2',
        name: 'Bob',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await store.upsertMembership(
      SharedLibraryMembership(
        id: 'ms2',
        diverId: 'd2',
        libraryId: 'L',
        memberId: 'c',
        displayName: 'Bob',
        libraryName: 'Reef Survey',
        backendKind: 's3',
        signingKey: await testMemberKey('c'),
      ),
    );
  }

  test('a refused card does not stop the other profiles\' cards', () async {
    await secondProfile();
    await copyAt('b');
    final order = [
      for (final m in await store.membershipsForLibrary('L')) m.memberId,
    ];
    at('b');
    clouds['b']!.failUploadsNamed = SharedLibraryTransport.memberFileName(
      order.first,
    );
    await repoint('b');
    final cards = await at('b').listMembers();
    expect(cards.map((m) => m.memberId), contains(order.last));
  });

  test('a card written anew keeps the join date this device knows', () async {
    await store.replaceMembers('L', [
      await SharedLibraryMember.signed(
        memberId: 'a',
        displayName: 'Ann',
        joinedAt: DateTime.utc(2025, 3, 1),
        key: await testMemberKey('a'),
      ),
    ]);
    await copyAt('b');
    await repoint('b');
    final card = (await at(
      'b',
    ).listMembers()).singleWhere((m) => m.memberId == 'a');
    expect(card.joinedAt, DateTime.utc(2025, 3, 1));
  });

  test('an identical card already there is not uploaded again', () async {
    await copyAt('b');
    await at('b').writeMember(
      await SharedLibraryMember.signed(
        memberId: 'a',
        displayName: 'Ann',
        joinedAt: DateTime.utc(2025, 3, 1),
        key: await testMemberKey('a'),
      ),
      appVersion: 'test',
    );
    clouds['b']!.operationLog.clear();
    await repoint('b');
    expect(
      clouds['b']!.operationLog,
      isNot(contains('upload:${SharedLibraryTransport.memberFileName('a')}')),
    );
  });

  test('roles no owner signed are not taken as current', () async {
    await copyAt('b');
    // Newer, but signed by someone the trusted roles make no owner.
    await at(
      'b',
    ).writeRoles(await signedTestRoles(owners: {'mallory'}, version: 9));
    expect((await check('b')).verdict, LibraryLocationVerdict.olderCopy);
  });

  test('different library is refused and nothing moves', () async {
    await copyAt('b', id: 'M');
    final c = await check('b');
    expect(c.verdict, LibraryLocationVerdict.differentLibrary);
    expect(c.foundName, 'Other Group');
    expect(c.canSave, isFalse);
    await expectLater(repoint('b'), throwsA(isA<LibraryLocationRejected>()));
    final r = await row();
    expect(r.prefix, 'a');
    expect(r.connectedAccountId, 'acc');
    expect(
      (await store.membership(diverId: 'd1', libraryId: 'L'))!.locationHint,
      'Survey bucket: a',
    );
  });

  test('empty folder is noLibrary; newer format is needsNewerApp', () async {
    expect((await check('empty')).verdict, LibraryLocationVerdict.noLibrary);
    await at('new').writeManifest({'id': 'L', 'formatVersion': 99});
    expect((await check('new')).verdict, LibraryLocationVerdict.needsNewerApp);
    await at('old').writeManifest({'id': 'L', 'formatVersion': 1});
    expect((await check('old')).verdict, LibraryLocationVerdict.retired);
    await expectLater(
      repoint('empty'),
      throwsA(isA<LibraryLocationRejected>()),
    );
  });

  test('older roles version is olderCopy', () async {
    await copyAt('b', version: 1);
    final c = await check('b');
    expect(c.verdict, LibraryLocationVerdict.olderCopy);
    expect(c.canSave, isTrue);
    await expectLater(repoint('b'), throwsA(isA<LibraryLocationRejected>()));
    expect((await row()).prefix, 'a');
    expect((await repoint('b', acceptOlder: true)).prefix, 'b');
  });

  test('a copy with no roles file is olderCopy', () async {
    await at(
      'b',
    ).writeManifest({'id': 'L', 'name': 'Reef Survey', 'formatVersion': 2});
    expect((await check('b')).verdict, LibraryLocationVerdict.olderCopy);
  });

  test(
    'encrypted copy re-keyed elsewhere is locked until the secret is given',
    () async {
      final cipher = await sealTestLibrary(at('b'), roles: roles);
      expect((await check('b')).verdict, LibraryLocationVerdict.locked);
      await expectLater(
        check('b', secret: 'nope'),
        throwsA(isA<WrongPassphraseError>()),
      );
      await expectLater(
        repoint('b', secret: 'nope'),
        throwsA(isA<WrongPassphraseError>()),
      );
      expect((await row()).prefix, 'a');
      final c = await check('b', secret: testPassphrase);
      expect(c.verdict, LibraryLocationVerdict.same);
      expect(c.foundName, 'Reef Survey');
      final moved = await repoint('b', secret: testPassphrase);
      expect(moved.prefix, 'b');
      expect(moved.encrypted, isTrue);
      expect(moved.keyId, cipher.keyId);
      final ms = (await store.membership(diverId: 'd1', libraryId: 'L'))!;
      expect(ms.libraryKeyId, cipher.keyId);
      // The key is held now: a second check needs no secret.
      expect((await check('b')).verdict, LibraryLocationVerdict.same);
    },
  );

  test('repoint re-checks the location', () async {
    await copyAt('b');
    expect((await check('b')).verdict, LibraryLocationVerdict.same);
    await copyAt('b', id: 'M');
    await expectLater(repoint('b'), throwsA(isA<LibraryLocationRejected>()));
    expect((await row()).prefix, 'a');
  });

  test('repoint waits for a running sync', () async {
    await copyAt('b');
    final release = Completer<void>();
    final running = SyncCoordinator.run(() => release.future);
    final moving = repoint('b');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await row()).prefix, 'a');
    release.complete();
    await running;
    expect((await moving).prefix, 'b');
  });
}
