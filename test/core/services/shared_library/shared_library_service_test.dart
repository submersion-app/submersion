import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
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
import '../../../helpers/test_database.dart';

const _lib = SharedLibrary(
  id: 'L',
  name: 'Club',
  connectedAccountId: 'acc',
  prefix: 'club',
);

/// A fresh device for [member], connected to the shared fake [cloud].
Future<SharedLibraryService> device(
  FakeCloudStorageProvider cloud,
  String member,
) async {
  await setUpTestDatabase();
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
      libraryName: 'Club',
      backendKind: 's3',
    ),
  );
  return SharedLibraryService(
    store: store,
    transportFor: (lib) async =>
        SharedLibraryTransport(cloud, prefix: lib.prefix),
  );
}

Future<void> seedLibrary(
  FakeCloudStorageProvider cloud, {
  Set<String> owners = const {'a'},
}) async {
  final t = SharedLibraryTransport(cloud, prefix: 'club');
  await t.writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 1});
  await t.writeRoles(SharedLibraryRoles(owners: owners));
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
    final doc = await SharedLibraryTransport(cloud, prefix: 'club').readSite(
      (await SharedLibraryTransport(
        cloud,
        prefix: 'club',
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
      final t = SharedLibraryTransport(cloud, prefix: 'club');
      final fileId = (await t.listSites()).single.id;
      final remote = await t.readSite(fileId);
      await t.writeSite(
        remote.copyWith(
          fields: {...remote.fields, 'notes': 'B says'},
          clocks: {
            ...remote.clocks,
            'notes': FieldClock(
              hlc: Hlc(DateTime.now().millisecondsSinceEpoch + 1000, 0, 'b'),
              memberId: 'b',
            ),
          },
        ),
      );
      final r = await svc.sync('L', diverId: 'd-a');
      expect(r.pulled, 1);
      expect(r.pushed, 1);
      site = (await SiteRepository().getSiteById('s1'))!;
      expect(site.hazards, 'A says');
      expect(site.notes, 'B says');
      final doc = await t.readSite(fileId);
      expect(doc.fields['hazards'], 'A says');
      expect(doc.fields['notes'], 'B says');
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
    await SharedLibraryTransport(
      cloud,
      prefix: 'club',
    ).writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 2});
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
      prefix: 'club',
    ).listMembers();
    expect(members.single.memberId, 'a');
  });

  test(
    'a remote tombstone removes an unlinked local row, keeps the state',
    () async {
      final cloud = FakeCloudStorageProvider();
      await seedLibrary(cloud);
      final t = SharedLibraryTransport(cloud, prefix: 'club');
      await t.writeSite(
        const SiteDocument(
          id: 's1',
          fields: {'name': 'Gone'},
          clocks: {'name': FieldClock(hlc: Hlc(1, 0, 'a'), memberId: 'a')},
        ),
      );
      final svc = await device(cloud, 'b');
      await svc.sync('L', diverId: 'd-b');
      expect(await SiteRepository().getSiteById('s1'), isNotNull);
      await t.writeSite(
        const SiteDocument(
          id: 's1',
          deleted: true,
          clocks: {'deleted': FieldClock(hlc: Hlc(2, 0, 'a'), memberId: 'a')},
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
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    await t.writeSite(const SiteDocument(id: 'ok', fields: {'name': 'OK'}));
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
