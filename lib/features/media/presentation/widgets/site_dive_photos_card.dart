import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/presentation/pages/media_scoped_gallery_page.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_preview.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The height the card's rows aim for (issue #4741).
const double kSiteDivePhotoRowHeight = 100;

/// Site Details card showing photos from the dives logged at the site
/// (issue #4502): the newest in [kJustifiedPreviewRows] justified rows
/// (issue #4741), each photo keeping its shape. When there are more, the
/// last one shown is darkened under "+N" and opens all of this site's dive
/// photos in a focused gallery.
///
/// The page builds it only when [count] is non-zero. The preview reads
/// [recentMediaFromDivesAtSiteProvider], a capped query, so opening the page
/// never loads every photo at the site. Read-only: photos are managed on
/// their dives.
class SiteDivePhotosCard extends ConsumerWidget {
  final String siteId;

  /// How many media items the site's dives hold, for the title and for the
  /// count behind +N.
  final int count;

  const SiteDivePhotosCard({
    super.key,
    required this.siteId,
    required this.count,
  });

  void _open(BuildContext context, MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SiteMediaViewerPage(
          siteId: siteId,
          initialMediaId: item.id,
          scope: SiteViewerScope.divePhotos,
        ),
      ),
    );
  }

  /// The library's site facet also matches a site's own attachments, so the
  /// Attached to facet keeps it to dive photos, the ones this card counts.
  void _showAll(BuildContext context, WidgetRef ref) => openMediaGallery(
    context,
    title: context.l10n.media_siteDivePhotos_title,
    subtitle: ref.read(siteProvider(siteId)).value?.name,
    filter: MediaLibraryFilter(
      siteId: siteId,
      attachedTo: const {MediaAttachmentKind.dive},
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(unitFormatterProvider).settings;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(recentMediaFromDivesAtSiteProvider(siteId));
    final photos = async.value;

    final Widget body;
    if (photos != null) {
      body = JustifiedMediaPreview(
        items: photos,
        totalCount: count,
        rowHeight: kSiteDivePhotoRowHeight,
        maxRows: kJustifiedPreviewRows,
        onShowMore: () => _showAll(context, ref),
        tileBuilder: (context, item, size, onImageSize) => GestureDetector(
          onTap: () => _open(context, item),
          child: MediaThumbnailTile(
            item: item,
            settings: settings,
            isSelectionMode: false,
            isSelected: false,
            semanticsLabel: context.l10n.media_siteMediaSection_divePhotoLabel,
            targetSize: mediaThumbnailDecodeTarget(size),
            onImageSize: onImageSize,
          ),
        ),
      );
    } else if (async.hasError) {
      body = Text(
        context.l10n.media_diveMediaSection_errorLoading,
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
      );
    } else {
      // As tall as the rows it stands in for, so the page does not jump
      // when they arrive.
      body = const SizedBox(
        height:
            kJustifiedPreviewRows * kSiteDivePhotoRowHeight +
            (kJustifiedPreviewRows - 1) * kJustifiedPreviewGap,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.collections_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.media_siteDivePhotos_titleWithCount(count),
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}
