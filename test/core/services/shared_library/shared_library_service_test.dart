import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/crypto/suggestion_signatures.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';

const _lib = SharedLibrary(
  id: 'L',
  name: 'Reef Survey',
  connectedAccountId: 'acc',
  prefix: 'site-sync',
);

/// A device for [member], connected to the shared fake [cloud]: fresh,
/// or the one kept in [file] when a test returns to it.
Future<SharedLibraryService> device(
  FakeCloudStorageProvider cloud,
  String member, {
  File? file,
}) async {
  // One device at a time: a database still open (a test that re-opens a
  // device's file without closing it first) is closed, never leaked. A
  // leaked handle keeps the file locked on Windows, where deleting it fails.
  final open = DatabaseService.instance.databaseOrNull;
  if (open != null) {
    await open.close();
    DatabaseService.instance.resetForTesting();
  }
  if (file != null && file.existsSync()) {
    DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase(file, setup: registerAppSqlFunctions)),
    );
    return _service(cloud);
  }
  if (file != null) {
    DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase(file, setup: registerAppSqlFunctions)),
    );
  } else {
    await setUpTestDatabase();
  }
  await DiverRepository().createDiver(
    Diver(
      id: 'd-$member',
      name: member,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
  final store = SharedLibraryStore();
  await store.upsertLibrary(_lib);
  await store.upsertMembership(
    SharedLibraryMembership(
      id: 'ms-$member',
      diverId: 'd-$member',
      libraryId: 'L',
      memberId: member,
      displayName: member,
      libraryName: 'Reef Survey',
      backendKind: 's3',
      signingKey: await testMemberKey(member),
    ),
  );
  return _service(cloud);
}

SharedLibraryService _service(FakeCloudStorageProvider cloud) =>
    SharedLibraryService(
      store: SharedLibraryStore(),
      transportFor: (lib) async =>
          SharedLibraryTransport(cloud, prefix: lib.prefix),
    );

/// [doc] as [member] signs it in library L.
Future<SiteDocument> signedAs(String member, SiteDocument doc) async =>
    signOwnFields(
      doc,
      libraryId: 'L',
      memberId: member,
      key: await testMemberKey(member),
    );

Future<void> seedLibrary(
  FakeCloudStorageProvider cloud, {
  Set<String> owners = const {'a'},
  Set<String> editors = const {},
  Set<String>? approved,
}) async {
  final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
  await t.writeManifest({'id': 'L', 'name': 'Reef Survey', 'formatVersion': 2});
  final roles = await signedTestRoles(
    owners: owners,
    editors: editors,
    members: {'a', 'b', 'c'},
  );
  if (approved == null) {
    await t.writeRoles(roles);
    return;
  }
  await t.writeRoles(
    await roles
        .copyWith(
          approvedKeys: {
            for (final e in roles.approvedKeys.entries)
              if (approved.contains(e.key)) e.key: e.value,
          },
        )
        .signed(
          libraryId: 'L',
          signedBy: (owners.toList()..sort()).first,
          key: await testMemberKey((owners.toList()..sort()).first),
        ),
  );
}

Future<void> markDirty(String siteId) => SharedLibraryStore().putSiteState(
  SharedSiteState(siteId: siteId, libraryId: 'L', dirty: true),
);

void main() {
  tearDown(() async {
    try {
      await tearDownTestDatabase();
    } catch (_) {}
  });

  test('a pushed site reaches another member with its clocks', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    var svc = await device(cloud, 'a');
    await SiteRepository().createSite(
      const DiveSite(
        id: 's1',
        name: 'Blue',
        hazards: 'current',
        sharedLibraryId: 'L',
      ),
    );
    await SharedLibraryStore().putSiteState(
      SharedSiteState(
        siteId: 's1',
        libraryId: 'L',
        dirty: true,
        clocks: {
          for (final f in SiteDocument.fieldNames)
            f: const FieldClock(hlc: Hlc(1, 0, 'a'), memberId: 'a'),
        },
      ),
    );
    final ra = await svc.sync('L', diverId: 'd-a');
    expect(ra.status, SharedLibrarySyncStatus.success);
    expect(ra.pushed, 1);
    expect((await SharedLibraryStore().getSiteState('s1'))!.dirty, isFalse);
    await tearDownTestDatabase();

    svc = await device(cloud, 'b');
    final rb = await svc.sync('L', diverId: 'd-b');
    expect(rb.status, SharedLibrarySyncStatus.success);
    expect(rb.pulled, 1);
    final site = (await SiteRepository().getSiteById('s1'))!;
    expect(site.hazards, 'current');
    expect(site.sharedLibraryId, 'L');
    final state = (await SharedLibraryStore().getSiteState('s1'))!;
    expect(state.clocks['hazards']!.memberId, 'a');
    expect(state.dirty, isFalse);
    expect(
      (await SharedLibraryStore().memberNames('L')).keys,
      containsAll(['a', 'b']),
    );
  });

  test('two members editing different fields converge', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a', 'b'});
    var svc = await device(cloud, 'a');
    await SiteRepository().createSite(
      const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
    );
    await markDirty('s1');
    await svc.sync('L', diverId: 'd-a');
    await tearDownTestDatabase();

    svc = await device(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    var site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(
      site.copyWith(parkingInfo: 'lot B'),
      actingDiverId: 'd-b',
    );
    expect((await svc.sync('L', diverId: 'd-b')).pushed, 1);
    await tearDownTestDatabase();

    svc = await device(cloud, 'a');
    await svc.sync('L', diverId: 'd-a');
    site = (await SiteRepository().getSiteById('s1'))!;
    expect(site.parkingInfo, 'lot B');
    await SiteRepository().updateSite(
      site.copyWith(hazards: 'current'),
      actingDiverId: 'd-a',
    );
    await svc.sync('L', diverId: 'd-a');
    site = (await SiteRepository().getSiteById('s1'))!;
    expect(site.parkingInfo, 'lot B');
    expect(site.hazards, 'current');
    final doc = await SharedLibraryTransport(cloud, prefix: 'site-sync')
        .readSite(
          (await SharedLibraryTransport(
            cloud,
            prefix: 'site-sync',
          ).listSites()).single.id,
        );
    expect(doc.fields['parkingInfo'], 'lot B');
    expect(doc.fields['hazards'], 'current');
    expect(doc.clocks['hazards']!.memberId, 'a');
    expect(doc.clocks['parkingInfo']!.memberId, 'b');
  });

  test(
    'an overwritten upload is re-merged and re-uploaded next sync',
    () async {
      final cloud = FakeCloudStorageProvider();
      await seedLibrary(cloud, owners: {'a', 'b'});
      final svc = await device(cloud, 'a');
      await SiteRepository().createSite(
        const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
      );
      await markDirty('s1');
      await svc.sync('L', diverId: 'd-a');
      var site = (await SiteRepository().getSiteById('s1'))!;
      await SiteRepository().updateSite(
        site.copyWith(hazards: 'A says'),
        actingDiverId: 'd-a',
      );
      // B overwrites the document before A uploads.
      final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
      final fileId = (await t.listSites()).single.id;
      final remote = await t.readSite(fileId);
      await t.writeSite(
        await signedAs(
          'b',
          remote.copyWith(
            fields: {...remote.fields, 'parkingInfo': 'B says'},
            clocks: {
              ...remote.clocks,
              'parkingInfo': FieldClock(
                hlc: Hlc(DateTime.now().millisecondsSinceEpoch + 1000, 0, 'b'),
                memberId: 'b',
              ),
            },
          ),
        ),
      );
      final r = await svc.sync('L', diverId: 'd-a');
      expect(r.pulled, 1);
      expect(r.pushed, 1);
      site = (await SiteRepository().getSiteById('s1'))!;
      expect(site.hazards, 'A says');
      expect(site.parkingInfo, 'B says');
      final doc = await t.readSite(fileId);
      expect(doc.fields['hazards'], 'A says');
      expect(doc.fields['parkingInfo'], 'B says');
    },
  );

  test(
    'a refused upload marks the library read-only, keeps the site dirty',
    () async {
      final cloud = FakeCloudStorageProvider();
      await seedLibrary(cloud);
      final svc = await device(cloud, 'a');
      await SiteRepository().createSite(
        const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
      );
      await markDirty('s1');
      cloud.failUploads = true;
      cloud.uploadException = const CloudStorageException(
        'Forbidden',
        'HTTP 403',
      );
      final r = await svc.sync('L', diverId: 'd-a');
      expect(r.status, SharedLibrarySyncStatus.readOnly);
      expect(
        (await SharedLibraryStore().getLibrary('L'))!.readOnlyDetected,
        isTrue,
      );
      expect((await SharedLibraryStore().getSiteState('s1'))!.dirty, isTrue);
    },
  );

  test('a missing manifest stops the sync and keeps local rows', () async {
    final cloud = FakeCloudStorageProvider();
    final svc = await device(cloud, 'a');
    await SiteRepository().createSite(
      const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
    );
    final r = await svc.sync('L', diverId: 'd-a');
    expect(r.status, SharedLibrarySyncStatus.notALibrary);
    expect(await SiteRepository().getSiteById('s1'), isNotNull);
    expect((await SharedLibraryStore().getLibrary('L'))!.lastError, isNotNull);
  });

  test('a newer format version stops the sync', () async {
    final cloud = FakeCloudStorageProvider();
    await SharedLibraryTransport(cloud, prefix: 'site-sync').writeManifest({
      'id': 'L',
      'name': 'Reef Survey',
      'formatVersion': SharedLibraryLayout.formatVersion + 1,
    });
    final svc = await device(cloud, 'a');
    expect(
      (await svc.sync('L', diverId: 'd-a')).status,
      SharedLibrarySyncStatus.needsNewerApp,
    );
  });

  test('roles and members are cached; ghost ids survive', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a', 'ghost'});
    final svc = await device(cloud, 'a');
    final r = await svc.sync('L', diverId: 'd-a');
    expect(r.status, SharedLibrarySyncStatus.success);
    final lib = (await SharedLibraryStore().getLibrary('L'))!;
    expect(lib.roles.owners, containsAll(['a', 'ghost']));
    expect(lib.lastSyncAt, isNotNull);
    expect(lib.lastError, isNull);
    final members = await SharedLibraryTransport(
      cloud,
      prefix: 'site-sync',
    ).listMembers();
    expect(members.single.memberId, 'a');
  });

  test(
    'a remote tombstone removes an unlinked local row, keeps the state',
    () async {
      final cloud = FakeCloudStorageProvider();
      await seedLibrary(cloud);
      final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
      await t.writeSite(
        await signedAs(
          'a',
          const SiteDocument(
            id: 's1',
            fields: {'name': 'Gone'},
            clocks: {'name': FieldClock(hlc: Hlc(1, 0, 'a'), memberId: 'a')},
          ),
        ),
      );
      final svc = await device(cloud, 'b');
      await svc.sync('L', diverId: 'd-b');
      expect(await SiteRepository().getSiteById('s1'), isNotNull);
      await t.writeSite(
        await signedAs(
          'a',
          const SiteDocument(
            id: 's1',
            deleted: true,
            clocks: {'deleted': FieldClock(hlc: Hlc(2, 0, 'a'), memberId: 'a')},
          ),
        ),
      );
      await svc.sync('L', diverId: 'd-b');
      expect(await SiteRepository().getSiteById('s1'), isNull);
      final state = (await SharedLibraryStore().getSiteState('s1'))!;
      expect(state.deleted, isTrue);
      expect(state.dirty, isFalse);
      // A third sync downloads nothing new and recreates nothing.
      final r = await svc.sync('L', diverId: 'd-b');
      expect(r.pulled, 0);
      expect(await SiteRepository().getSiteById('s1'), isNull);
    },
  );

  test('an unreadable document is skipped and retried next time', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    await t.writeSite(
      await signedAs(
        'a',
        const SiteDocument(
          id: 'ok',
          fields: {'name': 'OK'},
          clocks: {'name': FieldClock(hlc: Hlc(1, 0, 'a'), memberId: 'a')},
        ),
      ),
    );
    cloud.seedFile('site-bad.json', Uint8List.fromList('not json'.codeUnits));
    final svc = await device(cloud, 'b');
    final r = await svc.sync('L', diverId: 'd-b');
    expect(r.status, SharedLibrarySyncStatus.success);
    expect(r.pulled, 1);
    expect(await SharedLibraryStore().getSiteState('bad'), isNull);
  });

  test('a library not connected here reports notConnected', () async {
    await setUpTestDatabase();
    final svc = SharedLibraryService(
      store: SharedLibraryStore(),
      transportFor: (lib) async => throw StateError('no account'),
    );
    expect(
      (await svc.sync('X', diverId: 'd')).status,
      SharedLibrarySyncStatus.notConnected,
    );
  });

  test(
    'an edit made while its site uploads stays dirty for the next sync',
    () async {
      final cloud = _HookedCloud();
      await seedLibrary(cloud);
      final svc = await device(cloud, 'a');
      await SiteRepository().createSite(
        const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
      );
      await SharedLibraryStore().putSiteState(
        SharedSiteState(
          siteId: 's1',
          libraryId: 'L',
          dirty: true,
          clocks: {
            for (final f in SiteDocument.fieldNames)
              f: const FieldClock(hlc: Hlc(1, 0, 'a'), memberId: 'a'),
          },
        ),
      );
      // The member saves a new hazard while the upload is on the wire.
      cloud.beforeSiteUpload = () =>
          LibraryEditStamper().stamp('s1', {'hazards'}, actingDiverId: 'd-a');

      await svc.sync('L', diverId: 'd-a');

      final state = (await SharedLibraryStore().getSiteState('s1'))!;
      expect(state.dirty, isTrue, reason: 'the new hazard is not uploaded yet');
      expect(
        state.clocks['hazards']!.hlc.physicalTime,
        greaterThan(1),
        reason: 'the edit\'s clock survives the upload\'s state write',
      );
    },
  );

  test('a refused suggestion upload leaves the sync healthy', () async {
    final cloud = _HookedCloud();
    await seedLibrary(cloud);
    final svc = await device(cloud, 'a');
    await SharedLibraryStore().putSuggestion(
      SharedSiteSuggestion(
        id: 'sg1',
        libraryId: 'L',
        siteId: 's1',
        memberId: 'a',
        memberName: 'a',
        fields: const {'hazards': 'surge'},
        createdAt: DateTime.utc(2026),
        direction: SharedSiteSuggestion.outgoing,
      ),
    );
    cloud.refuseSuggestions = true;

    final result = await svc.sync('L', diverId: 'd-a');

    expect(result.isHealthy, isTrue);
    expect(result.status, SharedLibrarySyncStatus.readOnly);
    final kept = (await SharedLibraryStore().getSuggestion('sg1'))!;
    expect(kept.status, SharedSiteSuggestion.pending, reason: 'retried later');
  });

  test('a profile with no membership cannot sync the library', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    final svc = await device(cloud, 'a');
    await DiverRepository().createDiver(
      Diver(
        id: 'other',
        name: 'Other',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    cloud.operationLog.clear();
    final result = await svc.sync('L', diverId: 'other');
    expect(result.status, SharedLibrarySyncStatus.notConnected);
    expect(cloud.operationLog.where((op) => op.startsWith('upload')), isEmpty);
  });

  test('notes and rating stay with each member', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a', 'b'});
    var svc = await device(cloud, 'a');
    await SiteRepository().createSite(
      const DiveSite(
        id: 's1',
        name: 'Blue',
        notes: 'mine',
        rating: 2,
        sharedLibraryId: 'L',
      ),
    );
    await markDirty('s1');
    await svc.sync('L', diverId: 'd-a');
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final file = (await t.listSites()).single;
    final uploaded = await t.readSite(file.id);
    expect(uploaded.fields.containsKey('notes'), isFalse);
    expect(uploaded.fields.containsKey('rating'), isFalse);
    await tearDownTestDatabase();

    svc = await device(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    final theirs = (await SiteRepository().getSiteById('s1'))!;
    expect(theirs.notes, isEmpty);
    expect(theirs.rating, isNull);

    // A document from an older build still carrying notes, under a newer
    // clock, leaves the local notes alone.
    final raw = Map<String, dynamic>.from(uploaded.toJson());
    raw['fields'] = {...uploaded.fields, 'notes': 'leaked', 'rating': 5};
    raw['clocks'] = {
      ...uploaded.toJson()['clocks'] as Map,
      'notes': {
        'hlc': const Hlc(99999999999999, 0, 'a').toString(),
        'memberId': 'a',
      },
    };
    cloud.seedFile(file.id, Uint8List.fromList(utf8.encode(jsonEncode(raw))));
    await SharedLibraryStore().putSiteState(
      (await SharedLibraryStore().getSiteState(
        's1',
      ))!.copyWith(clearRemoteModifiedTime: true),
    );
    await svc.sync('L', diverId: 'd-b');
    final after = (await SiteRepository().getSiteById('s1'))!;
    expect(after.notes, isEmpty);
    expect(after.rating, isNull);
  });

  test('a roles file signed by someone who is no owner is ignored', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    final svc = await device(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    expect(
      (await SharedLibraryStore().getLibrary('L'))!.roles.roleOf('b'),
      SharedLibraryRole.reader,
    );
    // b makes itself an owner and signs the change itself.
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final trusted = await t.readRoles();
    await t.writeRoles(
      await trusted
          .copyWith(version: 2, owners: {'a', 'b'})
          .signed(libraryId: 'L', signedBy: 'b', key: await testMemberKey('b')),
    );
    await svc.sync('L', diverId: 'd-b');
    final library = (await SharedLibraryStore().getLibrary('L'))!;
    expect(library.roles.roleOf('b'), SharedLibraryRole.reader);
    expect(library.rolesRejected, isTrue);
  });

  test("an owner's change is trusted and clears the warning", () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    final svc = await device(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final trusted = await t.readRoles();
    await t.writeRoles(
      await trusted
          .copyWith(version: 2, editors: {'b'})
          .signed(libraryId: 'L', signedBy: 'a', key: await testMemberKey('a')),
    );
    await svc.sync('L', diverId: 'd-b');
    final library = (await SharedLibraryStore().getLibrary('L'))!;
    expect(library.roles.roleOf('b'), SharedLibraryRole.editor);
    expect(library.rolesRejected, isFalse);
  });

  test("a member's own card carries their key and verifies", () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    // An unsigned card from before, as an older build wrote it.
    await t.writeMember(
      SharedLibraryMember(
        memberId: 'b',
        displayName: 'b',
        joinedAt: DateTime.utc(2026),
      ),
      appVersion: '0',
    );
    final svc = await device(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    final card = (await t.listMembers()).singleWhere((m) => m.memberId == 'b');
    expect(card.cardVerified, isTrue);
    expect(card.publicKey, (await testMemberKey('b')).publicKey);
  });

  test(
    'a forged field is ignored and rewritten by the next honest upload',
    () async {
      final cloud = FakeCloudStorageProvider();
      await seedLibrary(cloud, owners: {'a'}, editors: {'b'});
      var svc = await device(cloud, 'a');
      await SiteRepository().createSite(
        const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
      );
      await markDirty('s1');
      await svc.sync('L', diverId: 'd-a');
      await tearDownTestDatabase();

      svc = await device(cloud, 'b');
      await svc.sync('L', diverId: 'd-b');
      // Someone with write keys claims a newer edit by a, unsigned.
      final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
      final file = (await t.listSites()).single;
      final doc = await t.readSite(file.id);
      await t.writeSite(
        doc.copyWith(
          fields: {...doc.fields, 'name': 'Forged'},
          clocks: {
            ...doc.clocks,
            'name': FieldClock(
              hlc: Hlc(doc.clocks['name']!.hlc.physicalTime + 1000, 0, 'a'),
              memberId: 'a',
            ),
          },
        ),
      );
      await svc.sync('L', diverId: 'd-b');
      expect((await SiteRepository().getSiteById('s1'))!.name, 'Blue');
      final repaired = await t.readSite((await t.listSites()).single.id);
      expect(repaired.fields['name'], 'Blue');
    },
  );

  test('approval re-reads held edits', () async {
    final cloud = FakeCloudStorageProvider();
    final dir = Directory.systemTemp.createTempSync('held_edits_');
    // Closed first: Windows cannot delete a database file still open.
    addTearDown(() async {
      try {
        await tearDownTestDatabase();
      } catch (_) {}
      dir.deleteSync(recursive: true);
    });
    final aFile = File(p.join(dir.path, 'a.sqlite'));
    // p edits, but no owner approved p's key yet.
    await seedLibrary(cloud, owners: {'a'}, editors: {'p'}, approved: {'a'});
    var svc = await device(cloud, 'a', file: aFile);
    await SiteRepository().createSite(
      const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
    );
    await markDirty('s1');
    await svc.sync('L', diverId: 'd-a');
    await tearDownTestDatabase();

    svc = await device(cloud, 'p');
    await svc.sync('L', diverId: 'd-p');
    final site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(
      site.copyWith(name: 'Blue Hole'),
      actingDiverId: 'd-p',
    );
    await svc.sync('L', diverId: 'd-p');
    await tearDownTestDatabase();

    svc = await device(cloud, 'a', file: aFile);
    await svc.sync('L', diverId: 'd-a');
    expect((await SiteRepository().getSiteById('s1'))!.name, 'Blue');
    // The owner approves p's key; the held edit now applies.
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final roles = await t.readRoles();
    await t.writeRoles(
      await roles
          .copyWith(
            version: roles.version + 1,
            approvedKeys: {
              ...roles.approvedKeys,
              'p': (await testMemberKey('p')).publicKey,
            },
          )
          .signed(libraryId: 'L', signedBy: 'a', key: await testMemberKey('a')),
    );
    await svc.sync('L', diverId: 'd-a');
    expect((await SiteRepository().getSiteById('s1'))!.name, 'Blue Hole');
  });

  // The timing lives in test/performance/library_signature_benchmark_test.dart.
  test('many documents are checked in parallel, each on its own', () async {
    final key = await testMemberKey('a');
    final docs = <SiteDocument>[];
    for (var i = 0; i < 40; i++) {
      docs.add(
        await signOwnFields(
          SiteDocument(
            id: 's$i',
            fields: {'name': 'Site $i'},
            clocks: {
              'name': const FieldClock(hlc: Hlc(1000, 0, 'a'), memberId: 'a'),
            },
          ),
          libraryId: 'L',
          memberId: 'a',
          key: key,
        ),
      );
    }
    // One forged document among them: the rest still count.
    docs[17] = docs[17].copyWith(fields: {'name': 'Forged'});
    final checked = await dropUnverifiedAll(
      [for (final d in docs) (d, SiteDocument(id: d.id))],
      libraryId: 'L',
      approvedKeys: {'a': key.publicKey},
    );
    expect([for (final d in checked) d.id], [for (final d in docs) d.id]);
    expect(checked[17].fields, isEmpty);
    expect(checked[16].fields, {'name': 'Site 16'});
  });

  test('suggestions are signed, and an owner takes only proven ones', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a'});
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    var svc = await device(cloud, 'b');
    SharedSiteSuggestion outgoing(String id, String member) =>
        SharedSiteSuggestion(
          id: id,
          libraryId: 'L',
          siteId: 's1',
          memberId: member,
          memberName: member,
          note: 'please',
          fields: const {'hazards': 'surge'},
          createdAt: DateTime.utc(2026, 10, 1),
          direction: SharedSiteSuggestion.outgoing,
        );
    await SharedLibraryStore().putSuggestion(outgoing('g1', 'b'));
    await svc.sync('L', diverId: 'd-b');
    await tearDownTestDatabase();
    final uploaded = await t.readSuggestion(
      (await t.listSuggestions()).single.id,
    );
    expect(
      await verifySuggestion(
        uploaded,
        (await testMemberKey('b')).publicKey,
        libraryId: 'L',
      ),
      isTrue,
    );
    // Signed for this library: it proves nothing copied into another.
    expect(
      await verifySuggestion(
        uploaded,
        (await testMemberKey('b')).publicKey,
        libraryId: 'other',
      ),
      isFalse,
    );

    // c (approved) signs one that is then altered; p (not approved) signs
    // another.
    final tampered = await signSuggestion(
      outgoing('g2', 'c').toJson(),
      await testMemberKey('c'),
      libraryId: 'L',
    );
    await t.writeSuggestion('g2', {...tampered, 'note': 'altered'});
    await t.writeSuggestion(
      'g3',
      await signSuggestion(
        outgoing('g3', 'p').toJson(),
        await testMemberKey('p'),
        libraryId: 'L',
      ),
    );

    svc = await device(cloud, 'a');
    await svc.sync('L', diverId: 'd-a');
    final incoming = await SharedLibraryStore().suggestions(
      'L',
      direction: SharedSiteSuggestion.incoming,
    );
    expect(incoming.map((s) => s.fileId), ['g1']);

    // Once p is approved, p's suggestion comes in.
    final roles = await t.readRoles();
    await t.writeRoles(
      await roles
          .copyWith(
            version: roles.version + 1,
            approvedKeys: {
              ...roles.approvedKeys,
              'p': (await testMemberKey('p')).publicKey,
            },
          )
          .signed(libraryId: 'L', signedBy: 'a', key: await testMemberKey('a')),
    );
    await svc.sync('L', diverId: 'd-a');
    final after = await SharedLibraryStore().suggestions(
      'L',
      direction: SharedSiteSuggestion.incoming,
    );
    expect(after.map((s) => s.fileId).toSet(), {'g1', 'g3'});
  });

  test('a pending ownership reset keeps the device from writing', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud, owners: {'a'}, editors: {'b'});
    final svc = await device(cloud, 'b');
    await svc.sync('L', diverId: 'd-b');
    // Someone with full storage keys resets ownership.
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final trusted = await t.readRoles();
    await t.writeRoles(
      await SharedLibraryRoles(
        version: trusted.version + 1,
        owners: const {'c'},
        approvedKeys: {'c': (await testMemberKey('c')).publicKey},
        reset: true,
      ).signed(libraryId: 'L', signedBy: 'c', key: await testMemberKey('c')),
    );
    await SiteRepository().createSite(
      const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
    );
    await markDirty('s1');
    final r = await svc.sync('L', diverId: 'd-b');
    expect(r.pushed, 0);
    expect(r.status, SharedLibrarySyncStatus.readOnly);
    final library = (await SharedLibraryStore().getLibrary('L'))!;
    expect(library.pendingRoles?.owners, {'c'});
    expect(library.roles, trusted);
    expect((await SharedLibraryStore().getSiteState('s1'))!.dirty, isTrue);
  });

  test('a library from a test build (format 1) is retired', () async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    await SharedLibraryTransport(
      cloud,
      prefix: 'site-sync',
    ).writeManifest({'id': 'L', 'name': 'Reef Survey', 'formatVersion': 1});
    final svc = await device(cloud, 'a');
    final r = await svc.sync('L', diverId: 'd-a');
    expect(r.status, SharedLibrarySyncStatus.retired);
  });

  test('without its key a library is locked; unlocked, it syncs', () async {
    final cloud = FakeCloudStorageProvider();
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final cipher = await sealTestLibrary(
      t,
      roles: await signedTestRoles(owners: {'a'}, editors: {'b'}),
    );
    final svc = await device(cloud, 'b');
    await SiteRepository().createSite(
      const DiveSite(id: 's1', name: 'Blue', sharedLibraryId: 'L'),
    );
    await markDirty('s1');
    cloud.operationLog.clear();
    final locked = await svc.sync('L', diverId: 'd-b');
    expect(locked.status, SharedLibrarySyncStatus.locked);
    expect(cloud.operationLog.where((op) => op.startsWith('upload')), isEmpty);

    await SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
    ).unlockLibrary(libraryId: 'L', diverId: 'd-b', secret: testPassphrase);
    final r = await svc.sync('L', diverId: 'd-b');
    expect(r.status, SharedLibrarySyncStatus.success);
    expect(r.pushed, 1);
    final file = (await t.listSites()).single;
    expect(LibraryCipher.isSealed(await cloud.downloadFile(file.id)), isTrue);
    expect((await t.readSite(file.id)).fields['name'], 'Blue');
    expect(cipher.keyId, (await SharedLibraryStore().getLibrary('L'))!.keyId);
  });
}

/// Runs [beforeSiteUpload] once before the next site upload, and refuses
/// suggestion uploads with a 403 when [refuseSuggestions] is set.
class _HookedCloud extends FakeCloudStorageProvider {
  Future<void> Function()? beforeSiteUpload;
  bool refuseSuggestions = false;

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final hook = beforeSiteUpload;
    if (hook != null && filename.startsWith('site-')) {
      beforeSiteUpload = null;
      await hook();
    }
    if (refuseSuggestions && filename.startsWith('suggestion-')) {
      throw const CloudStorageException('403 Forbidden');
    }
    return super.uploadFile(data, filename, folderId: folderId);
  }
}
