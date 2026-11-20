import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/justified_preview_layout.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Gap between preview tiles, across and down, as the issue's mockups have.
const double kJustifiedPreviewGap = 4;

/// The rows a detail card's preview shows before the rest go behind +N.
const int kJustifiedPreviewRows = 2;

/// The +N cover on the last tile shown, for tests and for callers that place
/// something relative to it.
const Key kJustifiedPreviewMoreKey = ValueKey('justified-preview-more');

/// Builds one preview tile at [size]. [onImageSize] is handed to the tile's
/// thumbnail so the preview learns a rotated photo's displayed shape, as the
/// library does (issue #4738).
typedef JustifiedPreviewTileBuilder =
    Widget Function(
      BuildContext context,
      MediaItem item,
      Size size,
      ValueChanged<Size> onImageSize,
    );

/// A short, fixed justified gallery for a detail card (issue #4741): each
/// tile keeps its shape, rows share a height and end flush with the card,
/// and at most [maxRows] rows are drawn. When that leaves items out and
/// [onShowMore] is given, the last tile shown is darkened under "+N" and
/// opens the rest.
///
/// It has no size control and no zoom, and it does not scroll: the card's
/// page does. Shapes come from the learned-shape cache the library fills,
/// and the tiles add to it as they draw.
class JustifiedMediaPreview extends ConsumerWidget {
  const JustifiedMediaPreview({
    super.key,
    required this.items,
    required this.tileBuilder,
    this.rowHeight = 100,
    this.gap = kJustifiedPreviewGap,
    this.maxRows,
    this.totalCount,
    this.onShowMore,
  });

  /// In display order. A capped read passes what it has, and [totalCount].
  final List<MediaItem> items;
  final JustifiedPreviewTileBuilder tileBuilder;

  /// The height rows aim for.
  final double rowHeight;
  final double gap;

  /// Null draws every row.
  final int? maxRows;

  /// How many items there are in all, when more than [items].
  final int? totalCount;

  /// Opens everything the preview leaves out; null draws no +N.
  final VoidCallback? onShowMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A cache that is still loading or cannot be read lays out from the
    // stored sizes; the card is short, so a late correction costs little.
    final learned =
        ref.watch(mediaLearnedAspectsProvider).value ??
        const <String, LearnedAspect>{};
    final ratios = [
      for (final item in items)
        clampMediaAspect(mediaRawAspect(item, learned: learned[item.id])),
    ];
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final layout = layoutJustifiedPreview(
          ratios: ratios,
          width: width,
          rowHeight: rowHeight,
          gap: gap,
          maxRows: maxRows,
          totalCount: totalCount,
        );
        // +N needs a tile to cover: a count can run ahead of an empty read.
        final showMore =
            onShowMore != null &&
            layout.hiddenCount > 0 &&
            layout.shownCount > 0;
        final notifier = ref.read(mediaLearnedAspectsProvider.notifier);
        return SizedBox(
          width: width,
          height: layout.height,
          child: Stack(
            children: [
              for (var i = 0; i < layout.shownCount; i++)
                _place(
                  layout.rects[i],
                  width: width,
                  isRtl: isRtl,
                  key: ValueKey(items[i].id),
                  child: tileBuilder(
                    context,
                    items[i],
                    layout.rects[i].size,
                    (size) => notifier.report(items[i], size),
                  ),
                ),
              if (showMore)
                _place(
                  layout.rects.last,
                  width: width,
                  isRtl: isRtl,
                  key: kJustifiedPreviewMoreKey,
                  child: _MoreCover(
                    count: layout.hiddenCount,
                    onTap: onShowMore!,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// [rect] is laid out left to right; right to left mirrors it.
  static Widget _place(
    Rect rect, {
    required double width,
    required bool isRtl,
    required Key key,
    required Widget child,
  }) => Positioned(
    key: key,
    left: isRtl ? width - rect.right : rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: child,
  );
}

/// The darkened last tile: "+N" over the photo, one tap to the rest.
class _MoreCover extends StatelessWidget {
  const _MoreCover({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.media_justifiedPreview_showAllInMedia,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          // Matches the thumbnail tiles' corners.
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    l10n.media_justifiedPreview_moreCount(count),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
