import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/editing/attachment_details_hold.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

final _at = DateTime.utc(2026, 11, 18);

/// A site's PDF attachment, uncategorised, following its category's size.
final _document = PhotoRecord(
  item: MediaItem(
    id: 'doc1',
    siteId: 's1',
    mediaType: MediaType.document,
    sourceType: MediaSourceType.localFile,
    originalFilename: 'reef-map.pdf',
    takenAt: _at,
    createdAt: _at,
    updatedAt: _at,
  ),
  species: const [],
  people: const [],
);

/// A site attachment's details are held in the photo sitting until Save
/// (issue #4527, phase 2), from the photo viewer, the PDF viewer and the
/// details page alike.
void main() {
  test('holds the category and the size in the sitting', () {
    final session = EditSession<PhotoRecord>(_document);

    holdAttachmentDetails(
      session,
      SiteAttachmentCategory.siteMap,
      AttachmentDisplaySize.large,
    );

    expect(
      session.valueOf(photoSiteCategoryField),
      SiteAttachmentCategory.siteMap,
    );
    expect(session.valueOf(photoDisplaySizeField), AttachmentDisplaySize.large);
    expect(session.changedCardIds, {photoDetailsCardId});
  });

  test('a frozen sitting is left as it is', () {
    final session = EditSession<PhotoRecord>(_document)..freeze();

    holdAttachmentDetails(
      session,
      SiteAttachmentCategory.siteMap,
      AttachmentDisplaySize.large,
    );

    expect(session.valueOf(photoSiteCategoryField), isNull);
    expect(session.valueOf(photoDisplaySizeField), isNull);
  });

  test('no sitting is no write', () {
    expect(
      () => holdAttachmentDetails(null, SiteAttachmentCategory.siteMap, null),
      returnsNormally,
    );
  });
}
