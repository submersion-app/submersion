import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';

void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryTransport t;

  setUp(() {
    cloud = FakeCloudStorageProvider();
    t = SharedLibraryTransport(cloud, prefix: 'site-sync');
  });

  test(
    'manifest and roles round trip; absent reads as null and empty',
    () async {
      expect(await t.readManifest(), isNull);
      expect(await t.readRoles(), SharedLibraryRoles.empty);
      await t.writeManifest({
        'id': 'L',
        'name': 'Reef Survey',
        'formatVersion': 1,
      });
      await t.writeRoles(const SharedLibraryRoles(owners: {'m1'}));
      expect((await t.readManifest())!['name'], 'Reef Survey');
      expect((await t.readRoles()).roleOf('m1'), SharedLibraryRole.owner);
    },
  );

  test('sites, members and suggestions are listed apart', () async {
    await t.writeSite(const SiteDocument(id: 's1', fields: {'name': 'A'}));
    await t.writeMember(
      SharedLibraryMember(
        memberId: 'm1',
        displayName: 'Ann',
        joinedAt: DateTime.utc(2026),
      ),
      appVersion: '1',
    );
    await t.writeSuggestion('g1', {'id': 'g1', 'siteId': 's1'});
    final sites = await t.listSites();
    expect(sites.map(SharedLibraryTransport.siteIdOf), ['s1']);
    expect((await t.listMembers()).single.displayName, 'Ann');
    final suggestions = await t.listSuggestions();
    expect(suggestions.map(SharedLibraryTransport.suggestionIdOf), ['g1']);
    expect((await t.readSite(sites.single.id)).fields['name'], 'A');
    expect((await t.readSuggestion(suggestions.single.id))['siteId'], 's1');
    await t.deleteSuggestion('g1');
    expect(await t.listSuggestions(), isEmpty);
    await t.deleteMember('m1');
    expect(await t.listMembers(), isEmpty);
  });

  test('writeSite returns the stored modification time', () async {
    final before = DateTime.now().subtract(const Duration(seconds: 1));
    final modified = await t.writeSite(const SiteDocument(id: 's1'));
    expect(modified!.isAfter(before), isTrue);
    final listed = (await t.listSites()).single.modifiedTime;
    expect(modified, listed);
  });

  test(
    'writeSite returns null for a same-length write by another member',
    () async {
      final racing = _OverwriteBeforeReadBack();
      final rt = SharedLibraryTransport(racing, prefix: 'site-sync');
      const mine = SiteDocument(id: 's1', fields: {'name': 'AAAA'});
      const theirs = SiteDocument(id: 's1', fields: {'name': 'BBBB'});
      expect(
        SiteDocument.encode(mine).length,
        SiteDocument.encode(theirs).length,
      );
      racing.overwrite = SiteDocument.encode(theirs);
      expect(await rt.writeSite(mine), isNull);
    },
  );

  test(
    'writeSite returns null when another write lands before the read-back',
    () async {
      final racing = _OverwriteBeforeReadBack();
      final rt = SharedLibraryTransport(racing, prefix: 'site-sync');
      racing.overwrite = SiteDocument.encode(
        const SiteDocument(
          id: 's1',
          fields: {'name': 'Written by another member'},
        ),
      );
      final modified = await rt.writeSite(const SiteDocument(id: 's1'));
      expect(
        modified,
        isNull,
        reason: 'the stored time is the other write\'s, not this one\'s',
      );
    },
  );

  test('the folder sits in submersion-sites, beside the sync folder', () async {
    // An S3 account whose personal sync lives under 'submersion-sync/'.
    final s3 = _S3LikeFolders(syncPrefix: 'submersion-sync/');
    final t = SharedLibraryTransport(s3, prefix: 'site-sync');
    await t.writeManifest({
      'id': 'L',
      'name': 'Reef Survey',
      'formatVersion': 1,
    });
    await t.writeSite(const SiteDocument(id: 's1', fields: {'name': 'A'}));
    expect(s3.uploadFolders, [
      'submersion-sites/site-sync/',
      'submersion-sites/site-sync/sites/',
    ]);
  });

  test('an empty folder is submersion-sites itself', () async {
    final s3 = _S3LikeFolders(syncPrefix: 'submersion-sync/');
    final t = SharedLibraryTransport(s3, prefix: '');
    await t.writeManifest({'id': 'L', 'name': 'Root', 'formatVersion': 1});
    expect(s3.uploadFolders, ['submersion-sites/']);
    expect((await t.readManifest())!['name'], 'Root');
  });

  test('an empty folder does not read a nested library as its own', () async {
    // S3 lists a prefix recursively: submersion-sites/ also holds every
    // library below it, and library-a's files sort before the root's.
    final bucket = _S3Bucket();
    final libraryA = SharedLibraryTransport(bucket, prefix: 'library-a');
    await libraryA.writeManifest({'id': 'A', 'name': 'A', 'formatVersion': 1});
    await libraryA.writeRoles(const SharedLibraryRoles(owners: {'m1'}));
    final root = SharedLibraryTransport(bucket, prefix: '');
    expect(await root.readManifest(), isNull);
    expect(await root.readRoles(), SharedLibraryRoles.empty);
  });

  test('a file nested in a kind folder is not listed as that kind', () async {
    final bucket = _S3Bucket();
    // Not reachable through the app (a library folder may not start with
    // 'sites'), but S3 lists the kind folder recursively all the same.
    await bucket.uploadFile(
      SiteDocument.encode(const SiteDocument(id: 's1')),
      'site-s1.json',
      folderId: 'submersion-sites/sites/sites/',
    );
    final root = SharedLibraryTransport(bucket, prefix: '');
    expect(await root.listSites(), isEmpty);
  });

  test('a folder starting with a library subfolder is refused', () {
    for (final bad in ['sites', 'members/x', 'suggestions', 'backups/old']) {
      expect(SharedLibraryTransport.isValidPrefix(bad), isFalse, reason: bad);
    }
    expect(SharedLibraryTransport.isValidPrefix('reef/sites'), isTrue);
    expect(SharedLibraryTransport.isValidPrefix(' /sites/ '), isFalse);
  });

  test('a folder with . or .. segments is refused', () async {
    expect(SharedLibraryTransport.isValidPrefix('groups/site-sync'), isTrue);
    expect(SharedLibraryTransport.isValidPrefix(''), isTrue);
    expect(SharedLibraryTransport.isValidPrefix('../submersion-sync'), isFalse);
    expect(SharedLibraryTransport.isValidPrefix('a/./b'), isFalse);
    final escape = SharedLibraryTransport(
      _S3Bucket(),
      prefix: '../submersion-sync',
    );
    await expectLater(
      escape.writeManifest({'id': 'L'}),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('isPermissionError recognises 403, 401 and AccessDenied', () {
    expect(
      SharedLibraryTransport.isPermissionError(
        const CloudStorageException('Upload failed', 'HTTP 403'),
      ),
      isTrue,
    );
    expect(
      SharedLibraryTransport.isPermissionError(
        const CloudStorageException('AccessDenied'),
      ),
      isTrue,
    );
    expect(
      SharedLibraryTransport.isPermissionError(
        const CloudStorageException('Unauthorized (401)'),
      ),
      isTrue,
    );
    expect(
      SharedLibraryTransport.isPermissionError(
        const CloudStorageException('timeout'),
      ),
      isFalse,
    );
  });

  test('a member card is verified against its own key', () async {
    final key = await LibrarySigner.generate();
    final card = await SharedLibraryMember.signed(
      memberId: 'm1',
      displayName: 'Ann',
      joinedAt: DateTime.utc(2026),
      key: key,
    );
    await t.writeMember(card, appVersion: '1');
    final read = (await t.listMembers()).single;
    expect(read.publicKey, key.publicKey);
    expect(read.cardVerified, isTrue);

    // Someone renames the card without the key.
    final forged = SharedLibraryMember(
      memberId: 'm1',
      displayName: 'Mallory',
      joinedAt: DateTime.utc(2026),
      publicKey: key.publicKey,
      signature: card.signature,
    );
    await t.writeMember(forged, appVersion: '1');
    expect((await t.listMembers()).single.cardVerified, isFalse);
  });

  group('encrypted', () {
    late LibraryCipher cipher;

    setUp(() async {
      cipher = await LibraryCipher.generate();
      t
        ..cipher = cipher
        ..encrypting = true;
    });

    test('site files are sealed and read back', () async {
      await t.writeSite(const SiteDocument(id: 's1', fields: {'name': 'A'}));
      final file = (await t.listSites()).single;
      expect(LibraryCipher.isSealed(await cloud.downloadFile(file.id)), isTrue);
      expect((await t.readSite(file.id)).fields['name'], 'A');
    });

    test(
      'the manifest and keyslots stay plain; roles and info are sealed',
      () async {
        await t.writeManifest({'id': 'L', 'formatVersion': 2});
        await t.writeRoles(const SharedLibraryRoles(owners: {'m1'}));
        await t.writeInfo({'name': 'Reef Survey'});
        await t.writeKeyslots(
          await cipher.keyslots(
            passphrase: 'pw',
            recoveryCode: 'code',
            kdf: const KdfParams(m: 1024, t: 1),
          ),
        );
        Future<Uint8List> raw(String name) async => cloud.downloadFile(
          (await cloud.listFiles(namePattern: name)).single.id,
        );
        expect(
          LibraryCipher.isSealed(await raw('submersion-shared-library')),
          isFalse,
        );
        expect(LibraryCipher.isSealed(await raw('keyslots')), isFalse);
        expect(LibraryCipher.isSealed(await raw('roles')), isTrue);
        expect(LibraryCipher.isSealed(await raw('info')), isTrue);
        expect((await t.readInfo())!['name'], 'Reef Survey');
        expect((await t.readKeyslots())!.libraryKeyId, cipher.keyId);
      },
    );

    test('a plain file in an encrypted library is read and noted', () async {
      t.encrypting = false;
      await t.writeSite(const SiteDocument(id: 's1', fields: {'name': 'A'}));
      t.encrypting = true;
      final file = (await t.listSites()).single;
      expect((await t.readSite(file.id)).fields['name'], 'A');
      expect(t.mismatched.keys, ['sites/site-s1.json']);
      await t.rewrite(
        'sites/site-s1.json',
        t.mismatched['sites/site-s1.json']!,
      );
      final id = (await t.listSites()).single.id;
      expect(LibraryCipher.isSealed(await cloud.downloadFile(id)), isTrue);
    });

    test('a sealed file without the key is locked', () async {
      await t.writeSite(const SiteDocument(id: 's1', fields: {'name': 'A'}));
      final locked = SharedLibraryTransport(cloud, prefix: 'site-sync');
      final file = (await locked.listSites()).single;
      await expectLater(
        locked.readSite(file.id),
        throwsA(isA<LibraryLockedException>()),
      );
    });
  });

  test(
    'a snapshot holds every stored file, which writes back as it was',
    () async {
      await t.writeManifest({'id': 'L', 'formatVersion': 2});
      await t.writeRoles(const SharedLibraryRoles(owners: {'m1'}));
      await t.writeInfo({'name': 'Reef Survey'});
      await t.writeSite(const SiteDocument(id: 's1', fields: {'name': 'A'}));
      final snap = await t.snapshot();
      expect(snap.keys.toSet(), {
        'submersion-shared-library.json',
        'roles.json',
        'info.json',
        'sites/site-s1.json',
      });
      final other = SharedLibraryTransport(_S3Bucket(), prefix: 'moved');
      for (final e in snap.entries) {
        await other.writeRaw(e.key, e.value);
      }
      expect((await other.readInfo())!['name'], 'Reef Survey');
      expect((await other.listSites()).single.name, 'site-s1.json');
      await other.deleteRaw('sites/site-s1.json');
      expect(await other.listSites(), isEmpty);
    },
  );
}

/// Another member's upload lands between this upload and its read-back.
class _OverwriteBeforeReadBack extends FakeCloudStorageProvider {
  Uint8List? overwrite;

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final bytes = overwrite;
    if (bytes != null) {
      overwrite = null;
      seedFile(fileId, bytes);
    }
    return super.getFileInfo(fileId);
  }
}

/// Folder ids as S3 keys them: a key prefix, the bucket's top being ''. A
/// null parent means the sync prefix, as on the real provider.
class _S3LikeFolders extends FakeCloudStorageProvider {
  _S3LikeFolders({required this.syncPrefix});

  final String syncPrefix;
  final uploadFolders = <String?>[];

  @override
  Future<String> getOrCreateSyncFolder() async => syncPrefix;

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async => '${parentFolderId ?? syncPrefix}$folderName/';

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) {
    uploadFolders.add(folderId);
    return super.uploadFile(data, filename, folderId: folderId);
  }
}

/// Keys as S3 stores them, and a listing as S3 returns it: every object
/// under the prefix, however deep, named by its last segment.
class _S3Bucket extends FakeCloudStorageProvider {
  final _objects = <String, Uint8List>{};

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async => '${parentFolderId ?? ''}$folderName/';

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final key = '${folderId ?? ''}$filename';
    _objects[key] = data;
    return UploadResult(fileId: key, uploadTime: DateTime.utc(2026));
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async =>
      _objects[fileId] ?? (throw CloudStorageException('missing $fileId'));

  @override
  Future<void> deleteFile(String fileId) async => _objects.remove(fileId);

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final data = _objects[fileId];
    return data == null ? null : _info(fileId, data);
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final keys = _objects.keys.toList()..sort();
    return [
      for (final k in keys)
        if (k.startsWith(folderId ?? '') &&
            (namePattern == null || k.split('/').last.contains(namePattern)))
          _info(k, _objects[k]!),
    ];
  }

  CloudFileInfo _info(String key, Uint8List data) => CloudFileInfo(
    id: key,
    name: key.split('/').last,
    modifiedTime: DateTime.utc(2026),
    sizeBytes: data.length,
  );
}
