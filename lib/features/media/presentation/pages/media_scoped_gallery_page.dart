import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_scoped_gallery_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_gallery.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_toolbar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The view menu in a focused gallery's app bar, for tests.
const Key kMediaGalleryViewMenuKey = ValueKey('media-gallery-view-menu');

/// The views a focused gallery offers: the library's, less the map.
const List<MediaLibraryViewMode> kMediaGalleryModes = [
  MediaLibraryViewMode.grid,
  MediaLibraryViewMode.byDive,
  MediaLibraryViewMode.timeline,
];

/// Opens the media [filter] selects in a focused gallery over the current
/// page (issue #4741), headed [title] and, under it, [subtitle].
void openMediaGallery(
  BuildContext context, {
  required String title,
  String? subtitle,
  required MediaLibraryFilter filter,
  MediaViewerOpener openViewer = openMediaViewer,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MediaScopedGalleryPage(
        title: title,
        subtitle: subtitle,
        filter: filter,
        openViewer: openViewer,
      ),
    ),
  );
}

/// Every photo and video of one scope, such as a dive site's dive photos,
/// and nothing else (issue #4741): the scope is set by the card that opens
/// it, so there are no section tabs, no import or transfer actions, no
/// filters and no map. One menu holds the view (the grid, or the by-dive or
/// timeline groups), the sort and the thumbnail size; a tile opens the
/// viewer.
///
/// It pages through its own scope ([mediaScopedLibraryProvider]), so the
/// Media screen keeps its own filter and view.
class MediaScopedGalleryPage extends ConsumerStatefulWidget {
  const MediaScopedGalleryPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.filter,
    this.openViewer = openMediaViewer,
  });

  final String title;
  final String? subtitle;
  final MediaLibraryFilter filter;
  final MediaViewerOpener openViewer;

  @override
  ConsumerState<MediaScopedGalleryPage> createState() =>
      _MediaScopedGalleryPageState();
}

class _MediaScopedGalleryPageState
    extends ConsumerState<MediaScopedGalleryPage> {
  /// Page state only: each opening starts on the grid.
  MediaLibraryViewMode _mode = MediaLibraryViewMode.grid;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = MediaGalleryScope(filter: widget.filter, mode: _mode);
    final state = ref.watch(mediaScopedLibraryProvider(scope));
    final subtitle = widget.subtitle;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, overflow: TextOverflow.ellipsis),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          _GalleryMenu(
            mode: _mode,
            onModeChanged: (mode) => setState(() => _mode = mode),
          ),
        ],
      ),
      body: MediaLibraryGallery(
        state: state,
        mode: _mode,
        emptyMessage: state.error != null
            ? l10n.media_diveMediaSection_errorLoading
            : l10n.media_library_emptyFiltered,
        onLoadMore: () =>
            ref.read(mediaScopedLibraryProvider(scope).notifier).loadMore(),
        onTileTap: (entry, shown) => widget.openViewer(context, [
          for (final e in shown) e.item,
        ], entry.item.id),
      ),
    );
  }
}

/// The app bar's one menu (issue #4741): the views, then Sort, then the
/// thumbnail size slider, the library toolbar's controls less its filter,
/// selection and map.
class _GalleryMenu extends ConsumerWidget {
  const _GalleryMenu({required this.mode, required this.onModeChanged});

  final MediaLibraryViewMode mode;
  final ValueChanged<MediaLibraryViewMode> onModeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    return MenuAnchor(
      menuChildren: [
        for (final m in kMediaGalleryModes)
          MenuItemButton(
            leadingIcon: Icon(
              MediaLibraryToolbar.iconFor(m),
              color: m == mode ? primary : null,
            ),
            onPressed: () => onModeChanged(m),
            child: Text(
              MediaLibraryToolbar.labelFor(m, l10n),
              style: m == mode
                  ? TextStyle(color: primary, fontWeight: FontWeight.w600)
                  : null,
            ),
          ),
        // Grid only, as in the library: the by-dive and timeline groups
        // need their rows in date order.
        if (mode == MediaLibraryViewMode.grid) ...[
          const Divider(height: 8),
          MenuItemButton(
            leadingIcon: const Icon(Icons.sort),
            onPressed: () => showMediaLibrarySortSheet(context, ref),
            child: Text(l10n.media_library_sort_title),
          ),
        ],
        const Divider(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: MediaThumbnailSizeSlider(),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        key: kMediaGalleryViewMenuKey,
        icon: Icon(MediaLibraryToolbar.iconFor(mode)),
        tooltip: MediaLibraryToolbar.labelFor(mode, l10n),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
