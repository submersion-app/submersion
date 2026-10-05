import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width over height for [item]'s large body: its stored dimensions, or 4:3
/// when they are unknown or degenerate.
double largeCardAspectRatio(MediaItem item) {
  final w = item.width ?? 0;
  final h = item.height ?? 0;
  return w > 0 && h > 0 ? w / h : 4 / 3;
}

/// A site attachment shown at full card width (issue #1039): an image or
/// video at its own aspect ratio, a PDF's first page, or a document row.
class SiteAttachmentLargeCard extends ConsumerWidget {
  const SiteAttachmentLargeCard({
    super.key,
    required this.item,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onEditDetails,
  });

  final MediaItem item;
  final bool isSelectionMode;
  final bool isSelected;

  /// Opens the item, or toggles it while selecting; the caller decides.
  final VoidCallback onTap;

  /// Shown as the card's overflow menu entry; null hides the menu.
  final VoidCallback? onEditDetails;

  /// A tall portrait may not swallow the page: the body stops at this share
  /// of the screen height and letterboxes inside it.
  static const double _maxHeightFraction = 0.7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: isSelected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              item: item,
              isSelectionMode: isSelectionMode,
              isSelected: isSelected,
              onToggle: onTap,
              onEditDetails: onEditDetails,
            ),
            // A non-PDF document has nothing to draw: the header row is the
            // whole card.
            if (!item.isDocument || item.isPdf) _body(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final maxHeight = MediaQuery.sizeOf(context).height * _maxHeightFraction;
      if (item.isPdf) {
        final request = (
          item: item,
          maxDimension: pdfPreviewBucket(
            width,
            MediaQuery.devicePixelRatioOf(context),
          ),
        );
        // No preview (unreadable PDF, pdfium unavailable) leaves only the
        // header, which is the document row: never an empty box.
        return ref
            .watch(pdfLargePreviewProvider(request))
            .when(
              data: (preview) => preview == null
                  ? const SizedBox.shrink()
                  : _PdfPage(
                      preview: preview,
                      maxHeight: maxHeight,
                      cacheWidth:
                          (width * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                    ),
              loading: () => SizedBox(
                height: width * 0.6,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            );
      }
      final naturalHeight = width / largeCardAspectRatio(item);
      final height = naturalHeight > maxHeight ? maxHeight : naturalHeight;
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaItemView(
              item: item,
              fit: BoxFit.contain,
              thumbnail: item.isVideo,
              targetSize: Size(width, height),
            ),
            if (item.isVideo)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 56,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _PdfPage extends StatelessWidget {
  const _PdfPage({
    required this.preview,
    required this.maxHeight,
    required this.cacheWidth,
  });

  final PdfPagePreview preview;
  final double maxHeight;

  /// Decode width: the card's physical width. The render comes from a size
  /// bucket up to twice that, and decoding the full bucket would hold a
  /// bitmap far larger than anything drawn.
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final pages = preview.pageCount;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Stack(
        children: [
          Center(
            child: Image.memory(
              preview.jpeg,
              fit: BoxFit.contain,
              cacheWidth: cacheWidth,
              gaplessPlayback: true,
            ),
          ),
          if (pages != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(context.l10n.media_siteAttachment_pageCount(pages)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggle,
    required this.onEditDetails,
  });

  final MediaItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback? onEditDetails;

  IconData get _icon {
    if (item.isPdf) return Icons.picture_as_pdf;
    if (item.isDocument) return Icons.description_outlined;
    if (item.isVideo) return Icons.videocam_outlined;
    return Icons.image_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final extension = item.documentExtension;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Icon(_icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.originalFilename ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
          ),
          if (item.isDocument && !item.isPdf && extension.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(extension.toUpperCase(), style: textTheme.labelMedium),
          ],
          if (isSelectionMode)
            Checkbox(value: isSelected, onChanged: (_) => onToggle())
          else if (onEditDetails != null)
            PopupMenuButton<String>(
              tooltip: l10n.media_siteAttachment_moreOptions,
              onSelected: (_) => onEditDetails!(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(l10n.media_siteAttachment_editDetails),
                ),
              ],
            )
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}
