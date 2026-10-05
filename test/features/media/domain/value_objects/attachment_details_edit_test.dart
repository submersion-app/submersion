import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_filename.dart';

void main() {
  MediaItem item({String? name = 'map.pdf'}) => MediaItem(
    id: 'm1',
    siteId: 's1',
    mediaType: MediaType.document,
    originalFilename: name,
    takenAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  group('diffAttachmentDetails', () {
    test('nothing changed is an empty edit', () {
      final edit = diffAttachmentDetails(
        item(),
        stem: 'map',
        category: null,
        displaySize: null,
      );
      expect(edit.isEmpty, isTrue);
    });

    test('a new stem becomes a filename change with the extension kept', () {
      final edit = diffAttachmentDetails(
        item(),
        stem: ' Reef map ',
        category: null,
        displaySize: null,
      );
      expect(edit.filename!.value, 'Reef map.pdf');
      expect(edit.category, isNull);
      expect(edit.displaySize, isNull);
    });

    test('category and size changes are carried, including a clear', () {
      final categorized = item().copyWith(
        siteCategory: SiteAttachmentCategory.parking,
        displaySizeOverride: AttachmentDisplaySize.tile,
      );
      final edit = diffAttachmentDetails(
        categorized,
        stem: 'map',
        category: SiteAttachmentCategory.siteMap,
        displaySize: null,
      );
      expect(edit.filename, isNull);
      expect(edit.category!.value, SiteAttachmentCategory.siteMap);
      expect(edit.displaySize, isNotNull);
      expect(edit.displaySize!.value, isNull);
    });

    test('a nameless item left blank keeps no name', () {
      final edit = diffAttachmentDetails(
        item(name: null),
        stem: '',
        category: SiteAttachmentCategory.general,
        displaySize: null,
      );
      expect(edit.filename, isNull);
      expect(edit.category!.value, SiteAttachmentCategory.general);
    });

    test('a nameless item given a name gets that name', () {
      final edit = diffAttachmentDetails(
        item(name: null),
        stem: 'Entry steps',
        category: null,
        displaySize: null,
      );
      expect(edit.filename!.value, 'Entry steps');
    });
  });

  group('attachmentNameError', () {
    test('a named item may not be blanked', () {
      expect(attachmentNameError(item(), '  '), AttachmentNameError.blank);
    });

    test('a nameless item may stay blank', () {
      expect(attachmentNameError(item(name: null), ''), isNull);
      expect(attachmentNameError(item(name: '  '), ''), isNull);
    });

    test('forbidden characters are refused either way', () {
      expect(
        attachmentNameError(item(name: null), 'a/b'),
        AttachmentNameError.forbiddenCharacter,
      );
    });
  });

  test('applyTo writes only the carried fields', () {
    final before = item().copyWith(siteCategory: SiteAttachmentCategory.access);
    final after = const AttachmentDetailsEdit(
      displaySize: FieldChange(AttachmentDisplaySize.large),
    ).applyTo(before);
    expect(after.siteCategory, SiteAttachmentCategory.access);
    expect(after.displaySizeOverride, AttachmentDisplaySize.large);
    expect(after.originalFilename, 'map.pdf');
  });
}
