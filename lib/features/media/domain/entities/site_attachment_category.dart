/// How large a site attachment renders on the site page (issue #1039).
enum AttachmentDisplaySize {
  large('large'),
  tile('tile');

  const AttachmentDisplaySize(this.storageKey);

  /// Value stored in `media.display_size`.
  final String storageKey;

  /// The size stored as [key], or null for an absent or unknown key.
  static AttachmentDisplaySize? fromStorageKey(String? key) {
    for (final size in values) {
      if (size.storageKey == key) return size;
    }
    return null;
  }
}

/// Where a site attachment belongs on the site page (issue #1039).
///
/// Declared in display order: the site page lists groups in this order,
/// with uncategorized attachments last.
enum SiteAttachmentCategory {
  siteMap('siteMap', AttachmentDisplaySize.large),
  parking('parking', AttachmentDisplaySize.large),
  access('access', AttachmentDisplaySize.large),
  anchorage('anchorage', AttachmentDisplaySize.large),
  underwater('underwater', AttachmentDisplaySize.tile),
  general('general', AttachmentDisplaySize.large);

  const SiteAttachmentCategory(this.storageKey, this.defaultDisplaySize);

  /// Value stored in `media.site_category`. Stable across languages, so two
  /// devices group the same attachment identically after sync.
  final String storageKey;

  /// Size used when the attachment carries no override.
  final AttachmentDisplaySize defaultDisplaySize;

  /// The category stored as [key], or null for an absent or unknown key.
  ///
  /// A key this version does not know (one a newer app synced in) reads as
  /// uncategorized rather than as some other category.
  static SiteAttachmentCategory? fromStorageKey(String? key) {
    for (final category in values) {
      if (category.storageKey == key) return category;
    }
    return null;
  }
}
