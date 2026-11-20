import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_preview.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The height the Site Media card's rows aim for (issue #4741).
const double kSiteAttachmentRowHeight = 120;

/// A site's attachments on its card, outside selection (issue #4741): every
/// document first, then the maps and photos in [kJustifiedPreviewRows]
/// justified rows, with no split by category. When there are more photos
/// than fit, the last one shown carries +N and [onShowMore] opens the rest.
///
/// Documents are all shown because the media library, where +N leads,
/// leaves documents out: hidden behind +N they could not be reached.
/// Categories, large cards and selection belong to the grouped layout the
/// card shows while selecting ([SiteAttachmentGroups]).
class SiteAttachmentPreview extends StatelessWidget {
  const SiteAttachmentPreview({
    super.key,
    required this.media,
    required this.settings,
    required this.onOpen,
    required this.onShowMore,
  });

  /// The site's attachments, in capture order.
  final List<MediaItem> media;
  final UnitFormatterSettings settings;
  final void Function(MediaItem) onOpen;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final documents = [
      for (final m in media)
        if (m.isDocument) m,
    ];
    final visuals = [
      for (final m in media)
        if (!m.isDocument) m,
    ];
    final label = context.l10n.media_diveMediaSection_thumbnailLabel;
    Widget tile(
      BuildContext context,
      MediaItem item,
      Size size,
      ValueChanged<Size> onImageSize,
    ) => GestureDetector(
      onTap: () => onOpen(item),
      child: MediaThumbnailTile(
        item: item,
        settings: settings,
        isSelectionMode: false,
        isSelected: false,
        semanticsLabel: label,
        targetSize: mediaThumbnailDecodeTarget(size),
        onImageSize: onImageSize,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (documents.isNotEmpty)
          JustifiedMediaPreview(
            key: const ValueKey('site-attachment-documents'),
            items: documents,
            rowHeight: kSiteAttachmentRowHeight,
            tileBuilder: tile,
          ),
        if (documents.isNotEmpty && visuals.isNotEmpty)
          const SizedBox(height: kJustifiedPreviewGap),
        if (visuals.isNotEmpty)
          JustifiedMediaPreview(
            key: const ValueKey('site-attachment-media'),
            items: visuals,
            rowHeight: kSiteAttachmentRowHeight,
            maxRows: kJustifiedPreviewRows,
            onShowMore: onShowMore,
            tileBuilder: tile,
          ),
      ],
    );
  }
}
