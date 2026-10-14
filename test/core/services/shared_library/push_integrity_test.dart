import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';
import 'shared_library_service_test.dart' show device, seedLibrary;

/// What a member's device uploads keeps other members' signed values as
/// they signed them, and never loses an edit saved during a pull (issue
/// #2567).
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('push_integrity_'));

  tearDown(() async {
    try {
      await tearDownTestDatabase();
    } catch (_) {}
    dir.deleteSync(recursive: true);
  });

  Future<Tag> tag(String diverId, String name) => TagRepository().createTag(
    Tag(
      id: '',
      diverId: diverId,
      name: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      scopes: const {TagScope.sites},
    ),
  );

  /// Owner a adds s1 (and s2) to the library, every field clocked.
  Future<void> ownerAdds(
    FakeCloudStorageProvider cloud,
    File aFile, {
    List<String> tags = const [],
    bool second = false,
  }) async {
    final svc = await device(cloud, 'a', file: aFile);
    await svc.sync('L', diverId: 'd-a');
    for (final id in ['s1', if (second) 's2']) {
      await SiteRepository().createSite(
        DiveSite(id: id, name: 'Blue $id', diverId: 'd-a'),
      );
      if (tags.isNotEmpty) {
        await SiteClassificationRepository().replaceTags(id, [
          for (final name in tags) (await tag('d-a', name)).id,
        ]);
      }
      await SharedSitePublisher().push(
        siteId: id,
        libraryId: 'L',
        diverId: 'd-a',
      );
    }
    await svc.sync('L', diverId: 'd-a');
    await tearDownTestDatabase();
  }

  test(
    "a value another device spells its own way goes up as its author's",
    () async {
      final cloud = FakeCloudStorageProvider();
      await seedLibrary(cloud, owners: {'a'}, editors: {'b', 'c'});
      await ownerAdds(
        cloud,
        File(p.join(dir.path, 'a.sqlite')),
        tags: ['Wreck'],
      );

      // b already has a tag "wreck": the site links to it.
      var svc = await device(cloud, 'b');
      await tag('d-b', 'wreck');
      await svc.sync('L', diverId: 'd-b');
      final site = (await SiteRepository().getSiteById('s1'))!;
      await SiteRepository().updateSite(
        site.copyWith(description: 'Calm in the morning'),
        actingDiverId: 'd-b',
      );
      await svc.sync('L', diverId: 'd-b');
      await tearDownTestDatabase();

      // c joins and checks every signature.
      svc = await device(cloud, 'c');
      await svc.sync('L', diverId: 'd-c');
      final tags = await SiteClassificationRepository().getTagsForSite('s1');
      expect(tags.map((t) => t.name), ['Wreck']);
      expect(
        (await SiteRepository().getSiteById('s1'))!.description,
        'Calm in the morning',
      );
    },
  );

  test('a value someone changed under its clock is not sent up', () async {
    final cloud = FakeCloudStorageProvider();
    final bFile = File(p.join(dir.path, 'b.sqlite'));
    await seedLibrary(cloud, owners: {'a'}, editors: {'b'});
    await ownerAdds(cloud, File(p.join(dir.path, 'a.sqlite')));
    var svc = await device(cloud, 'b', file: bFile);
    await svc.sync('L', diverId: 'd-b');
    await tearDownTestDatabase();

    // Someone with write access changes a's name in the folder, keeping
    // a's clock and signature.
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final file = (await t.listSites()).single;
    final doc = await t.readSite(file.id);
    await t.writeSite(
      doc.copyWith(fields: {...doc.fields, 'name': 'Taken over'}),
    );

    svc = await device(cloud, 'b', file: bFile);
    final site = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(
      site.copyWith(description: 'Calm in the morning'),
      actingDiverId: 'd-b',
    );
    await svc.sync('L', diverId: 'd-b');
    final stored = await t.readSite(file.id);
    expect(stored.fields['name'], 'Blue s1');
    expect(stored.fields['description'], 'Calm in the morning');
  });

  test('an edit saved while its site is being pulled is uploaded', () async {
    final cloud = _OnDownload();
    final aFile = File(p.join(dir.path, 'a.sqlite'));
    final bFile = File(p.join(dir.path, 'b.sqlite'));
    await seedLibrary(cloud, owners: {'a'}, editors: {'b'});
    await ownerAdds(cloud, aFile, second: true);

    var svc = await device(cloud, 'b', file: bFile);
    await svc.sync('L', diverId: 'd-b');
    await tearDownTestDatabase();

    // a renames both sites.
    svc = await device(cloud, 'a', file: aFile);
    for (final id in ['s1', 's2']) {
      final site = (await SiteRepository().getSiteById(id))!;
      await SiteRepository().updateSite(
        site.copyWith(name: 'Renamed $id'),
        actingDiverId: 'd-a',
      );
    }
    await svc.sync('L', diverId: 'd-a');
    await tearDownTestDatabase();

    // b pulls both; while s2 downloads, b saves an edit to s1.
    svc = await device(cloud, 'b', file: bFile);
    cloud.onDownload = (fileId) async {
      if (!fileId.contains('site-s2')) return;
      cloud.onDownload = null;
      final s1 = (await SiteRepository().getSiteById('s1'))!;
      await SiteRepository().updateSite(
        s1.copyWith(description: 'Saved mid pull'),
        actingDiverId: 'd-b',
      );
    };
    await svc.sync('L', diverId: 'd-b');
    await svc.sync('L', diverId: 'd-b');
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final stored = [
      for (final f in await t.listSites()) await t.readSite(f.id),
    ].firstWhere((d) => d.id == 's1');
    expect(stored.fields['description'], 'Saved mid pull');
    expect(stored.fields['name'], 'Renamed s1');
    final row = (await SiteRepository().getSiteById('s1'))!;
    expect(row.description, 'Saved mid pull');
    expect(row.name, 'Renamed s1');
  });
}

/// The fake storage, running [onDownload] before each download.
class _OnDownload extends FakeCloudStorageProvider {
  Future<void> Function(String fileId)? onDownload;

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    await onDownload?.call(fileId);
    return super.downloadFile(fileId);
  }
}
