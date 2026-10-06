import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';

/// One category's attachments on the site page (issue #1039).
class SiteAttachmentGroup {
  const SiteAttachmentGroup({
    required this.category,
    required this.large,
    required this.tiles,
  });

  /// Null for the uncategorized group.
  final SiteAttachmentCategory? category;

  /// Full-width items, in capture order.
  final List<MediaItem> large;

  /// Grid items, in capture order.
  final List<MediaItem> tiles;
}

/// A site's attachments arranged for display.
class SiteAttachmentLayout {
  const SiteAttachmentLayout({
    required this.groups,
    required this.showHeadings,
  });

  /// Non-empty groups in category order, uncategorized last.
  final List<SiteAttachmentGroup> groups;

  /// False when nothing is categorized, so a site nobody has categorized
  /// looks as it did before categories existed.
  final bool showHeadings;
}

int _byCaptureThenId(MediaItem a, MediaItem b) {
  final byTime = a.takenAt.compareTo(b.takenAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// Arranges [attachments] into category groups, each split into large items
/// and tiles by [MediaItem.effectiveDisplaySize].
SiteAttachmentLayout layoutSiteAttachments(List<MediaItem> attachments) {
  final order = <SiteAttachmentCategory?>[
    ...SiteAttachmentCategory.values,
    null,
  ];
  final groups = <SiteAttachmentGroup>[];
  for (final category in order) {
    final members =
        attachments.where((m) => m.siteCategory == category).toList()
          ..sort(_byCaptureThenId);
    if (members.isEmpty) continue;
    groups.add(
      SiteAttachmentGroup(
        category: category,
        large: [
          for (final m in members)
            if (m.effectiveDisplaySize == AttachmentDisplaySize.large) m,
        ],
        tiles: [
          for (final m in members)
            if (m.effectiveDisplaySize == AttachmentDisplaySize.tile) m,
        ],
      ),
    );
  }
  return SiteAttachmentLayout(
    groups: groups,
    showHeadings: groups.any((g) => g.category != null),
  );
}
