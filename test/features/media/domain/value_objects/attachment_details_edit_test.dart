import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';

void main() {
  MediaItem item() => MediaItem(
    id: 'm1',
    siteId: 's1',
    mediaType: MediaType.document,
    originalFilename: 'map.pdf',
    takenAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  group('diffAttachmentDetails', () {
    test('nothing changed is an empty edit', () {
      final edit = diffAttachmentDetails(
        item(),
        category: null,
        displaySize: null,
      );
      expect(edit.isEmpty, isTrue);
    });

    test('a new category is carried and the size left alone', () {
      final edit = diffAttachmentDetails(
        item(),
        category: SiteAttachmentCategory.general,
        displaySize: null,
      );
      expect(edit.category!.value, SiteAttachmentCategory.general);
      expect(edit.displaySize, isNull);
    });

    test('category and size changes are carried, including a clear', () {
      final categorized = item().copyWith(
        siteCategory: SiteAttachmentCategory.parking,
        displaySizeOverride: AttachmentDisplaySize.tile,
      );
      final edit = diffAttachmentDetails(
        categorized,
        category: SiteAttachmentCategory.siteMap,
        displaySize: null,
      );
      expect(edit.category!.value, SiteAttachmentCategory.siteMap);
      expect(edit.displaySize, isNotNull);
      expect(edit.displaySize!.value, isNull);
    });
  });

  test('applyTo writes only the carried fields and never the name', () {
    final before = item().copyWith(siteCategory: SiteAttachmentCategory.access);
    final after = const AttachmentDetailsEdit(
      displaySize: FieldChange(AttachmentDisplaySize.large),
    ).applyTo(before);
    expect(after.siteCategory, SiteAttachmentCategory.access);
    expect(after.displaySizeOverride, AttachmentDisplaySize.large);
    expect(after.originalFilename, 'map.pdf');
  });
}
