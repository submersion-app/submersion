import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1039: a site attachment's category, size and name are user edits
/// on the media row, written narrowly so a stale snapshot cannot clobber
/// any other column.
void main() {
  late AppDatabase db;
  late MediaRepository media;
  late SiteAttachmentRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    media = MediaRepository();
    repository = SiteAttachmentRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  MediaItem item({String name = 'map.pdf', String? caption}) {
    final now = DateTime.utc(2026, 1, 1, 10);
    return MediaItem(
      id: '',
      filePath: '/docs/$name',
      originalFilename: name,
      mediaType: MediaType.document,
      caption: caption,
      takenAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> clearPending(String id) =>
      (db.delete(db.syncRecords)..where((t) => t.recordId.equals(id))).go();

  Future<List<String>> statuses(String id) async =>
      (await (db.select(
            db.syncRecords,
          )..where((t) => t.recordId.equals(id))).get())
          .map((r) => r.syncStatus)
          .toList();

  test('createMedia and updateMedia round-trip both fields', () async {
    final created = await media.createMedia(
      item().copyWith(
        siteCategory: SiteAttachmentCategory.siteMap,
        displaySizeOverride: AttachmentDisplaySize.tile,
      ),
    );
    var fetched = (await media.getMediaById(created.id))!;
    expect(fetched.siteCategory, SiteAttachmentCategory.siteMap);
    expect(fetched.displaySizeOverride, AttachmentDisplaySize.tile);

    await media.updateMedia(
      fetched.copyWith(
        siteCategory: SiteAttachmentCategory.parking,
        displaySizeOverride: null,
      ),
    );
    fetched = (await media.getMediaById(created.id))!;
    expect(fetched.siteCategory, SiteAttachmentCategory.parking);
    expect(fetched.displaySizeOverride, isNull);
  });

  test('an unknown stored key hydrates as uncategorized', () async {
    final created = await media.createMedia(item());
    await db.customStatement(
      "UPDATE media SET site_category = 'boatRamp', display_size = 'huge' "
      "WHERE id = '${created.id}'",
    );
    final fetched = (await media.getMediaById(created.id))!;
    expect(fetched.siteCategory, isNull);
    expect(fetched.displaySizeOverride, isNull);
  });

  group('setAttachmentDetails', () {
    test('writes only the carried fields and marks the row pending', () async {
      final created = await media.createMedia(item(caption: 'keep me'));
      await clearPending(created.id);

      await repository.setAttachmentDetails(
        created.id,
        const AttachmentDetailsEdit(
          category: FieldChange(SiteAttachmentCategory.access),
        ),
      );

      final fetched = (await media.getMediaById(created.id))!;
      expect(fetched.originalFilename, 'map.pdf');
      expect(fetched.siteCategory, SiteAttachmentCategory.access);
      expect(fetched.displaySizeOverride, isNull);
      expect(fetched.caption, 'keep me');
      expect(await statuses(created.id), ['pending']);
    });

    test('a FieldChange of null clears the field', () async {
      final created = await media.createMedia(
        item().copyWith(displaySizeOverride: AttachmentDisplaySize.large),
      );
      await repository.setAttachmentDetails(
        created.id,
        const AttachmentDetailsEdit(displaySize: FieldChange(null)),
      );
      expect(
        (await media.getMediaById(created.id))!.displaySizeOverride,
        isNull,
      );
    });

    test('an empty edit writes nothing and queues nothing', () async {
      final created = await media.createMedia(item());
      await clearPending(created.id);
      await repository.setAttachmentDetails(
        created.id,
        const AttachmentDetailsEdit(),
      );
      expect(await statuses(created.id), isEmpty);
    });

    test('a row that no longer exists throws and queues nothing', () async {
      await expectLater(
        repository.setAttachmentDetails(
          'gone',
          const AttachmentDetailsEdit(
            category: FieldChange(SiteAttachmentCategory.general),
          ),
        ),
        throwsStateError,
      );
      expect(await statuses('gone'), isEmpty);
    });
  });

  group('setSiteCategory', () {
    test(
      'sets every id, leaves overrides and names, marks each pending',
      () async {
        final a = await media.createMedia(
          item(
            name: 'a.jpg',
          ).copyWith(displaySizeOverride: AttachmentDisplaySize.large),
        );
        final b = await media.createMedia(item(name: 'b.jpg'));
        await clearPending(a.id);
        await clearPending(b.id);

        await repository.setSiteCategory([
          a.id,
          b.id,
        ], SiteAttachmentCategory.underwater);

        final fa = (await media.getMediaById(a.id))!;
        final fb = (await media.getMediaById(b.id))!;
        expect(fa.siteCategory, SiteAttachmentCategory.underwater);
        expect(fb.siteCategory, SiteAttachmentCategory.underwater);
        expect(fa.displaySizeOverride, AttachmentDisplaySize.large);
        expect(fa.originalFilename, 'a.jpg');
        expect(await statuses(a.id), ['pending']);
        expect(await statuses(b.id), ['pending']);
      },
    );

    test('null uncategorizes', () async {
      final a = await media.createMedia(
        item().copyWith(siteCategory: SiteAttachmentCategory.parking),
      );
      await repository.setSiteCategory([a.id], null);
      expect((await media.getMediaById(a.id))!.siteCategory, isNull);
    });

    test('a missing id is skipped, not queued', () async {
      final a = await media.createMedia(item());
      final updated = await repository.setSiteCategory([
        a.id,
        'gone',
      ], SiteAttachmentCategory.general);
      expect(
        (await media.getMediaById(a.id))!.siteCategory,
        SiteAttachmentCategory.general,
      );
      expect(updated, 1, reason: 'only rows that still exist count');
    });

    test('an empty id list is a no-op', () async {
      expect(
        await repository.setSiteCategory(
          const [],
          SiteAttachmentCategory.general,
        ),
        0,
      );
    });
  });
}
