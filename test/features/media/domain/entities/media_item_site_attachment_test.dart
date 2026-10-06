import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';

void main() {
  final base = MediaItem(
    id: 'm1',
    siteId: 's1',
    mediaType: MediaType.photo,
    takenAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  group('effectiveDisplaySize', () {
    test('uncategorized with no override is a tile', () {
      expect(base.effectiveDisplaySize, AttachmentDisplaySize.tile);
    });

    test('follows the category default when there is no override', () {
      expect(
        base
            .copyWith(siteCategory: SiteAttachmentCategory.siteMap)
            .effectiveDisplaySize,
        AttachmentDisplaySize.large,
      );
      expect(
        base
            .copyWith(siteCategory: SiteAttachmentCategory.underwater)
            .effectiveDisplaySize,
        AttachmentDisplaySize.tile,
      );
    });

    test('an override wins in both directions', () {
      expect(
        base
            .copyWith(
              siteCategory: SiteAttachmentCategory.siteMap,
              displaySizeOverride: AttachmentDisplaySize.tile,
            )
            .effectiveDisplaySize,
        AttachmentDisplaySize.tile,
      );
      expect(
        base
            .copyWith(displaySizeOverride: AttachmentDisplaySize.large)
            .effectiveDisplaySize,
        AttachmentDisplaySize.large,
      );
    });
  });

  test('copyWith can clear both fields back to null', () {
    final set = base.copyWith(
      siteCategory: SiteAttachmentCategory.parking,
      displaySizeOverride: AttachmentDisplaySize.large,
    );
    final cleared = set.copyWith(siteCategory: null, displaySizeOverride: null);
    expect(cleared.siteCategory, isNull);
    expect(cleared.displaySizeOverride, isNull);
  });

  test('copyWith without the fields keeps them', () {
    final set = base.copyWith(siteCategory: SiteAttachmentCategory.access);
    expect(
      set.copyWith(caption: 'x').siteCategory,
      SiteAttachmentCategory.access,
    );
  });

  test('both fields take part in equality', () {
    expect(
      base.copyWith(siteCategory: SiteAttachmentCategory.general),
      isNot(base),
    );
    expect(
      base.copyWith(displaySizeOverride: AttachmentDisplaySize.tile),
      isNot(base),
    );
  });
}
