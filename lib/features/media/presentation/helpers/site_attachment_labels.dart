import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized names for site attachment categories; null is Uncategorized.
extension SiteAttachmentCategoryLabel on SiteAttachmentCategory? {
  String label(AppLocalizations l10n) => switch (this) {
    SiteAttachmentCategory.siteMap => l10n.media_siteAttachment_categorySiteMap,
    SiteAttachmentCategory.parking => l10n.media_siteAttachment_categoryParking,
    SiteAttachmentCategory.access => l10n.media_siteAttachment_categoryAccess,
    SiteAttachmentCategory.anchorage =>
      l10n.media_siteAttachment_categoryAnchorage,
    SiteAttachmentCategory.underwater =>
      l10n.media_siteAttachment_categoryUnderwater,
    SiteAttachmentCategory.general => l10n.media_siteAttachment_categoryGeneral,
    null => l10n.media_siteAttachment_categoryNone,
  };
}

/// Localized names for attachment display sizes.
extension AttachmentDisplaySizeLabel on AttachmentDisplaySize {
  String label(AppLocalizations l10n) => switch (this) {
    AttachmentDisplaySize.large => l10n.media_siteAttachment_sizeLarge,
    AttachmentDisplaySize.tile => l10n.media_siteAttachment_sizeTile,
  };
}
