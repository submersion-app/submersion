import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';

void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryTransport t;

  setUp(() {
    cloud = FakeCloudStorageProvider();
    t = SharedLibraryTransport(cloud, prefix: 'club');
  });

  test(
    'manifest and roles round trip; absent reads as null and empty',
    () async {
      expect(await t.readManifest(), isNull);
      expect(await t.readRoles(), SharedLibraryRoles.empty);
      await t.writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 1});
      await t.writeRoles(const SharedLibraryRoles(owners: {'m1'}));
      expect((await t.readManifest())!['name'], 'Club');
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
      final rt = SharedLibraryTransport(racing, prefix: 'club');
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
      final rt = SharedLibraryTransport(racing, prefix: 'club');
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
    await t.writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 1});
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
