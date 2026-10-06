import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/services/site_attachment_layout.dart';

void main() {
  MediaItem m(
    String id,
    int minute, {
    SiteAttachmentCategory? category,
    AttachmentDisplaySize? size,
  }) => MediaItem(
    id: id,
    siteId: 's1',
    mediaType: MediaType.photo,
    takenAt: DateTime.utc(2026, 1, 1, 10, minute),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    siteCategory: category,
    displaySizeOverride: size,
  );

  test('nothing attached is no groups and no headings', () {
    final layout = layoutSiteAttachments(const []);
    expect(layout.groups, isEmpty);
    expect(layout.showHeadings, isFalse);
  });

  test('all uncategorized is one headless group of tiles, as before', () {
    final layout = layoutSiteAttachments([m('b', 2), m('a', 1)]);
    expect(layout.showHeadings, isFalse);
    expect(layout.groups.single.category, isNull);
    expect(layout.groups.single.large, isEmpty);
    expect(layout.groups.single.tiles.map((i) => i.id), ['a', 'b']);
  });

  test('groups follow category order with uncategorized last', () {
    final layout = layoutSiteAttachments([
      m('u', 1),
      m('g', 2, category: SiteAttachmentCategory.general),
      m('w', 3, category: SiteAttachmentCategory.underwater),
      m('s', 4, category: SiteAttachmentCategory.siteMap),
    ]);
    expect(layout.showHeadings, isTrue);
    expect(layout.groups.map((g) => g.category), [
      SiteAttachmentCategory.siteMap,
      SiteAttachmentCategory.underwater,
      SiteAttachmentCategory.general,
      null,
    ]);
  });

  test('within a group large and tile items split, each in time order', () {
    final layout = layoutSiteAttachments([
      m(
        't2',
        4,
        category: SiteAttachmentCategory.siteMap,
        size: AttachmentDisplaySize.tile,
      ),
      m('l2', 3, category: SiteAttachmentCategory.siteMap),
      m(
        't1',
        2,
        category: SiteAttachmentCategory.siteMap,
        size: AttachmentDisplaySize.tile,
      ),
      m('l1', 1, category: SiteAttachmentCategory.siteMap),
    ]);
    final group = layout.groups.single;
    expect(group.large.map((i) => i.id), ['l1', 'l2']);
    expect(group.tiles.map((i) => i.id), ['t1', 't2']);
  });

  test('an uncategorized item can be forced large', () {
    final layout = layoutSiteAttachments([
      m('a', 1, size: AttachmentDisplaySize.large),
    ]);
    expect(layout.groups.single.large.map((i) => i.id), ['a']);
  });

  test('equal capture times tie-break on id, so order is stable', () {
    final layout = layoutSiteAttachments([m('b', 1), m('a', 1)]);
    expect(layout.groups.single.tiles.map((i) => i.id), ['a', 'b']);
  });
}
