import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';

/// Keys folders by path and lists like S3: a folder's listing holds every
/// object below it, nested libraries included.
class _PathProvider extends FakeCloudStorageProvider {
  final files = <String, int?>{};

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async => (parentFolderId == null || parentFolderId.isEmpty)
      ? folderName
      : '$parentFolderId/$folderName';

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async => [
    for (final e in files.entries)
      if (folderId == null || e.key.startsWith('$folderId/'))
        CloudFileInfo(
          id: e.key,
          name: e.key.split('/').last,
          modifiedTime: DateTime(2026),
          sizeBytes: e.value,
        ),
  ];
}

/// Looks folders up without creating them, as WebDAV does.
class _LookupProvider extends _PathProvider implements FolderLookup {
  final created = <String>[];

  /// Folders whose lookup fails, as a server that times out would.
  final failing = <String>{};

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async {
    final path = await super.createFolder(
      folderName,
      parentFolderId: parentFolderId,
    );
    created.add(path);
    return path;
  }

  @override
  Future<String?> findFolder(
    String folderName, {
    String? parentFolderId,
  }) async {
    final path = await super.createFolder(
      folderName,
      parentFolderId: parentFolderId,
    );
    if (failing.contains(folderName)) {
      throw CloudStorageException('PROPFIND timed out: $path');
    }
    return files.keys.any((k) => k.startsWith('$path/')) ? path : null;
  }
}

void main() {
  test('sums only sync files', () async {
    final cloud = FakeCloudStorageProvider();
    await cloud.uploadFile(Uint8List(10), 'ssv1.dev1.manifest.json');
    await cloud.uploadFile(Uint8List(20), 'ssv1.dev1.cs.000000000001.json');
    await cloud.uploadFile(Uint8List(99), 'submersion_backup_x.db');
    await cloud.uploadFile(Uint8List(7), 'ssv1.bogus');

    final measured = await measureSyncFolderBytes(cloud);
    expect(measured.bytes, 30);
    expect(measured.partial, isFalse);
  });

  test('a sync file without a size marks the figure partial', () async {
    final cloud = _PathProvider();
    cloud.files['ssv1.dev1.manifest.json'] = 10;
    cloud.files['ssv1.dev1.cs.000000000001.json'] = null;

    final measured = await measureSyncFolderBytes(cloud);

    expect(measured.bytes, 10);
    expect(measured.partial, isTrue);
  });

  test('library measure ignores nested library folders', () async {
    final cloud = _PathProvider();
    const root = 'submersion-sites/site-sync';
    cloud.files.addAll({
      '$root/submersion-shared-library.json': 5,
      '$root/keyslots.json': 6,
      '$root/sites/site-a.json': 10,
      '$root/members/member-m1.json': 3,
      '$root/suggestions/suggestion-g1.json': 2,
      '$root/backups/index.json': 4,
      '$root/backups/backup-1.zip': 100,
      // A library nested under this one: not ours to count.
      '$root/nested/submersion-shared-library.json': 50,
      '$root/nested/sites/site-z.json': 50,
    });

    final measured = await SharedLibraryTransport(
      cloud,
      prefix: 'site-sync',
    ).measureBytes();

    expect(measured.bytes, 5 + 6 + 10 + 3 + 2 + 4 + 100);
    expect(measured.partial, isFalse);
  });

  test('measuring creates no missing optional folder', () async {
    // A size scan must not write to a library, even one it may write to.
    final cloud = _LookupProvider();
    const root = 'submersion-sites/site-sync';
    cloud.files.addAll({
      '$root/sites/site-a.json': 10,
      '$root/members/member-m1.json': 3,
      '$root/backups/backup-1.zip': 100,
    });

    final measured = await SharedLibraryTransport(
      cloud,
      prefix: 'site-sync',
    ).measureBytes();

    expect(measured.bytes, 10 + 3 + 100);
    expect(measured.partial, isFalse);
    expect(cloud.created, isNot(contains('$root/suggestions')));
  });

  test(
    'an optional folder that cannot be looked up marks it partial',
    () async {
      // Missing is a null lookup; a lookup that fails may be hiding bytes.
      final cloud = _LookupProvider()..failing.add('backups');
      cloud.files['submersion-sites/site-sync/sites/site-a.json'] = 10;

      final measured = await SharedLibraryTransport(
        cloud,
        prefix: 'site-sync',
      ).measureBytes();

      expect(measured.bytes, 10);
      expect(measured.partial, isTrue);
    },
  );

  test('a file without a size marks the library partial', () async {
    final cloud = _PathProvider();
    cloud.files['submersion-sites/site-sync/sites/site-a.json'] = null;
    cloud.files['submersion-sites/site-sync/keyslots.json'] = 6;

    final measured = await SharedLibraryTransport(
      cloud,
      prefix: 'site-sync',
    ).measureBytes();

    expect(measured.bytes, 6);
    expect(measured.partial, isTrue);
  });

  test('CloudUsage round-trips through json', () {
    final usage = CloudUsage(
      mediaBytes: 100,
      mediaReclaimableBytes: 10,
      mediaWaitingBytes: 5,
      syncBytes: 30,
      librariesBytes: null,
      partial: true,
      mediaHold: CloudDeleteHold.unregistered,
      mediaStoreId: 'store-1',
      scannedAt: DateTime(2026, 10, 17, 12),
    );

    final back = CloudUsage.fromJson(usage.toJson());

    expect(back.mediaBytes, 100);
    expect(back.mediaReclaimableBytes, 10);
    expect(back.mediaWaitingBytes, 5);
    expect(back.syncBytes, 30);
    expect(back.librariesBytes, isNull);
    expect(back.partial, isTrue);
    expect(back.mediaHold, CloudDeleteHold.unregistered);
    expect(back.mediaStoreId, 'store-1');
    expect(back.scannedAt, usage.scannedAt);
  });

  test('onlyAreas shows media figures only of the attached store', () {
    final usage = CloudUsage(
      scannedAt: DateTime(2026, 10, 17),
      mediaBytes: 100,
      mediaReclaimableBytes: 10,
      mediaStoreId: 'store-a',
      syncBytes: 30,
    );
    CloudUsage only(String? attached) =>
        usage.onlyAreas(mediaStoreId: attached, sync: true, libraries: false);

    expect(only('store-a').mediaBytes, 100);
    expect(only('store-b').mediaBytes, isNull);
    expect(only('store-b').mediaReclaimableBytes, isNull);
    expect(only(null).mediaBytes, isNull);
    expect(only('store-b').syncBytes, 30);
  });

  test('CloudUsage copyWith replaces only what it is given', () {
    final usage = CloudUsage(
      scannedAt: DateTime(2026, 10, 17),
      mediaBytes: 100,
      syncBytes: 30,
      mediaHold: CloudDeleteHold.uploads,
    );

    final next = usage.copyWith(mediaBytes: 60);

    expect(next.mediaBytes, 60);
    expect(next.mediaHold, CloudDeleteHold.uploads);
    expect(next.syncBytes, 30);
    expect(next.scannedAt, usage.scannedAt);
  });
}
