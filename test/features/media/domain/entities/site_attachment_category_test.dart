import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';

void main() {
  group('SiteAttachmentCategory', () {
    test('is declared in display order', () {
      expect(SiteAttachmentCategory.values.map((c) => c.storageKey), [
        'siteMap',
        'parking',
        'access',
        'anchorage',
        'underwater',
        'general',
      ]);
    });

    test('underwater defaults to tile, every other category to large', () {
      for (final c in SiteAttachmentCategory.values) {
        expect(
          c.defaultDisplaySize,
          c == SiteAttachmentCategory.underwater
              ? AttachmentDisplaySize.tile
              : AttachmentDisplaySize.large,
          reason: c.storageKey,
        );
      }
    });

    test('parses every key it writes', () {
      for (final c in SiteAttachmentCategory.values) {
        expect(SiteAttachmentCategory.fromStorageKey(c.storageKey), c);
      }
    });

    test('an unknown or absent key is uncategorized, never a real value', () {
      expect(SiteAttachmentCategory.fromStorageKey(null), isNull);
      expect(SiteAttachmentCategory.fromStorageKey(''), isNull);
      expect(SiteAttachmentCategory.fromStorageKey('boatRamp'), isNull);
      expect(SiteAttachmentCategory.fromStorageKey('SITEMAP'), isNull);
    });
  });

  group('AttachmentDisplaySize', () {
    test('round-trips its keys and rejects unknown ones', () {
      expect(
        AttachmentDisplaySize.fromStorageKey('large'),
        AttachmentDisplaySize.large,
      );
      expect(
        AttachmentDisplaySize.fromStorageKey('tile'),
        AttachmentDisplaySize.tile,
      );
      expect(AttachmentDisplaySize.fromStorageKey('huge'), isNull);
      expect(AttachmentDisplaySize.fromStorageKey(null), isNull);
    });
  });
}
