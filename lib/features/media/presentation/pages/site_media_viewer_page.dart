import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/attachment_details_hold.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_editing.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/helpers/media_share_helper.dart';
import 'package:submersion/features/media/presentation/widgets/attachment_details_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_viewer_mixin.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_correction_label.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/pick_white_hint.dart';
import 'package:submersion/features/media/presentation/widgets/media_fullscreen_controls.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_nav_arrows.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

/// Which list of site-related media backs the viewer's pager.
enum SiteViewerScope {
  /// Media directly attached to the site (maps, entry points, parking).
  attachments,

  /// Photos aggregated from dives logged at the site.
  divePhotos,
}

/// Full-screen photo/video viewer for a site's media.
///
/// Modeled on TripPhotoViewerPage without the dive-context overlays: site
/// attachments have no dive profile to position against. Documents never
/// enter the pager (they open in DocumentViewerPage), so the backing list
/// is filtered here as a final guard.
class SiteMediaViewerPage extends ConsumerStatefulWidget {
  final String siteId;
  final String initialMediaId;
  final SiteViewerScope scope;

  const SiteMediaViewerPage({
    super.key,
    required this.siteId,
    required this.initialMediaId,
    required this.scope,
  });

  @override
  ConsumerState<SiteMediaViewerPage> createState() =>
      _SiteMediaViewerPageState();
}

class _SiteMediaViewerPageState extends ConsumerState<SiteMediaViewerPage>
    with
        MediaFullscreenMixin<SiteMediaViewerPage>,
        ColorAdjustViewerMixin<SiteMediaViewerPage>,
        PhotoViewerEditing<SiteMediaViewerPage> {
  /// Locking, by any route, closes what changes the photo.
  @override
  void onPhotoLocked() => closeColorEditing();

  /// Adjust color holds its changes in the photo's sitting.
  @override
  EditSession<PhotoRecord>? get colorSitting => photoSitting;

  /// Steps through the check while unlocked, so the next photo opens locked.
  void _step(int delta, int totalCount) =>
      unawaited(stepGuarded(delta, (by) => _stepPage(by, totalCount)));

  /// Keeps the pager on the sitting's photo when the list moves under it.
  void _followSittingTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _currentIndex = index;
      _navTargetIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  late PageController _pageController;
  int _currentIndex = 0;

  /// The page the last nav request aimed at, which runs ahead of
  /// [_currentIndex] while the pager is still animating. See [_stepPage].
  int _navTargetIndex = 0;

  bool _showOverlay = true;

  @override
  void onExitFullscreen() => _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Set immersive mode for full-screen experience
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  void dispose() {
    disposePhotoEditing();
    _pageController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  /// Steps [delta] pages from the last page *requested*, not the last one
  /// settled on.
  ///
  /// onPageChanged only fires once the pager crosses the halfway point, so
  /// [_currentIndex] lags an in-flight animation; stepping from it would drop
  /// the second of two quick presses instead of advancing two items.
  void _stepPage(int delta, int totalCount) {
    if (!_pageController.hasClients) return;
    if (totalCount == 0) return;
    // The list is live and can shrink under the viewer, stranding the nav
    // target past the new end. Clamp to the same bounds the arrows and the
    // page indicator are drawn from, or every press would fall out of range
    // and navigation would freeze with the controls still showing.
    final target = _navTargetIndex.clamp(0, totalCount - 1) + delta;
    // Out-of-range steps do nothing: the ends of the list do not wrap.
    if (target < 0 || target >= totalCount) return;
    _navTargetIndex = target;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Keyboard navigation for pointer platforms: arrows page, Escape closes.
  ///
  /// Arrow presses are reported handled even at the ends of the list, which
  /// keeps them from falling through to default directional focus traversal.
  KeyEventResult _handleKeyEvent(KeyEvent event, int totalCount) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _step(-1, totalCount);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _step(1, totalCount);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      // In a sitting Escape backs out of Pick white and the colour panel
      // first (issue #4527).
      if (photoUnlocked && pickingWhite) {
        togglePickWhite();
        return KeyEventResult.handled;
      }
      if (photoUnlocked && colorPanelOpen) {
        closeColorEditing();
        return KeyEventResult.handled;
      }
      // While unlocked, Escape is Cancel: the viewer stays open.
      if (photoUnlocked) {
        unawaited(cancelPhotoSitting());
        return KeyEventResult.handled;
      }
      if (isFullscreen) {
        exitFullscreen();
      } else {
        Navigator.of(context).maybePop();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final sourceAsync = widget.scope == SiteViewerScope.attachments
        ? ref.watch(mediaForSiteProvider(widget.siteId))
        : ref.watch(flatMediaFromDivesAtSiteProvider(widget.siteId));
    return photoEditScope(
      backsOutFirst: () => isFullscreen,
      child: fullscreenPopScope(
        child: Scaffold(
          backgroundColor: Colors.black,
          // A reload keeps drawing the list it has: every media write (a
          // colour save from the panel below among them) reloads the
          // dive-photo providers, and showing the spinner for it would tear
          // down the gallery and the panel mid-edit (issue #3520).
          body: sourceAsync.when(
            skipLoadingOnReload: true,
            data: (all) {
              // A sitting keeps its photo here while the photo exists.
              final mediaList = keepSittingPhoto(
                all.where((m) => !m.isDocument).toList(),
              );
              if (mediaList.isEmpty) {
                // Nothing left to tap means no exit button (a sync can empty the
                // list under the viewer).
                exitFullscreenWhenEmpty();
                return Center(
                  child: Text(
                    context.l10n.media_photoViewer_noPhotosAvailable,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              // Find initial index
              final initialIndex = mediaList.indexWhere(
                (m) => m.id == widget.initialMediaId,
              );
              if (initialIndex != -1 && _pageController.hasClients == false) {
                _currentIndex = initialIndex;
                _navTargetIndex = initialIndex;
                // hasClients == false means no PageView is attached, so the
                // outgoing controller is safe to dispose; without this the one
                // built in initState leaks.
                _pageController.dispose();
                _pageController = PageController(initialPage: initialIndex);
              }

              // The list is live: a media delete or a sync pull can shrink it
              // under the open viewer, leaving _currentIndex past the end.
              // Clamp once here and use it everywhere rather than writing it back
              // during build -- the pager corrects _currentIndex itself on the
              // next settle via onPageChanged, so the clamp only has to survive
              // one frame. Same guard MediaViewerPage carries.
              final shownIndex = _currentIndex.clamp(0, mediaList.length - 1);
              // A sitting stays on its own photo as the list moves under it.
              final sittingIndex = photoUnlocked
                  ? sittingIndexIn(mediaList)
                  : null;
              if (sittingIndex != null && sittingIndex != shownIndex) {
                _followSittingTo(sittingIndex);
              }
              final currentIndex = sittingIndex ?? shownIndex;
              final storedPhoto = followStoredPhoto(mediaList[currentIndex]);
              final currentItem = shownItem(mediaList[currentIndex], const []);

              final viewer = GestureDetector(
                // Swipe down to close (common pattern for fullscreen viewers)
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 300) {
                    closeGuarded();
                  }
                },
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: galleryBoundaryKey,
                      child: _MediaGalleryPager(
                        mediaList: shownMediaList(mediaList, const []),
                        pagingLocked: photoUnlocked,
                        pageController: _pageController,
                        onPageChanged: (index) {
                          // Swipes and settles both land here, which is what
                          // re-syncs the nav target after a gesture.
                          setState(() {
                            _currentIndex = index;
                            _navTargetIndex = index;
                          });
                        },
                      ),
                    ),

                    // Transparent tap target to toggle overlays
                    Positioned.fill(
                      child: Semantics(
                        label:
                            context.l10n.media_photoViewer_toggleOverlayLabel,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: pickingWhite
                              ? null
                              : isFullscreen
                              ? toggleFullscreenControls
                              : () => setState(
                                  () => _showOverlay = !_showOverlay,
                                ),
                          onTapUp: pickingWhite
                              ? (details) => pickWhiteOnPhoto(
                                  currentItem,
                                  details.localPosition,
                                )
                              : null,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),

                    if (pickingWhite) const PickWhiteHint(),

                    // While unlocked the bar never hides: it holds Cancel and
                    // Save.
                    if ((_showOverlay || photoUnlocked) &&
                        !isFullscreen &&
                        !pickingWhite) ...[
                      _TopOverlay(
                        onAdjustColor: () => openColorPanel(),
                        onUnlock:
                            !photoUnlocked &&
                                canUnlock(currentItem, storedPhoto)
                            ? () => unlockPhoto(storedPhoto!)
                            : null,
                        editBar: photoUnlocked
                            ? MediaViewerEditBar(
                                title: currentItem.isVideo
                                    ? context.l10n.media_viewer_editingVideo
                                    : context.l10n.media_viewer_editingPhoto,
                                canSave: photoEditController.isDirty,
                                isSaving: photoEditController.isSaving,
                                onCancel: () => unawaited(cancelPhotoSitting()),
                                onSave: () => unawaited(savePhotoAndReport()),
                              )
                            : null,
                        currentIndex: currentIndex,
                        totalCount: mediaList.length,
                        onClose: closeGuarded,
                        onEnterFullscreen: enterFullscreen,
                        onShare: (anchor) =>
                            _shareCurrentItem(currentItem, anchor),
                        // Only an attachment is the site's to categorize; a
                        // dive photo belongs to its dive. The pager keeps
                        // capture-time order, so an edit never moves the
                        // photo out from under the diver. Offered only in
                        // the editing bar, so the details are always held.
                        onEditDetails:
                            widget.scope == SiteViewerScope.attachments
                            ? () => showAttachmentDetailsSheet(
                                context,
                                item: currentItem,
                                siteId: widget.siteId,
                                // Held until Save.
                                onHold: (category, size) =>
                                    holdAttachmentDetails(
                                      photoSitting,
                                      category,
                                      size,
                                    ),
                              )
                            : null,
                      ),
                      // What colour correction the item is drawn with.
                      Positioned(
                        top:
                            MediaQuery.paddingOf(context).top +
                            kToolbarHeight +
                            12,
                        left: 12,
                        child: ColorCorrectionLabel(item: currentItem),
                      ),
                      // Previous / next controls. Mounted with the rest of the
                      // chrome, so the tap-to-hide gesture takes them away too.
                      MediaNavArrows(
                        currentIndex: currentIndex,
                        totalCount: mediaList.length,
                        onPrevious: () => _step(-1, mediaList.length),
                        onNext: () => _step(1, mediaList.length),
                      ),
                      _BottomMetadataOverlay(item: currentItem),
                    ],

                    if (isFullscreen && fullscreenControlsVisible)
                      MediaFullscreenExitButton(onExit: exitFullscreen),
                  ],
                ),
              );

              // Keyboard nav has to wrap the whole viewer to see its key events.
              // Built as a local above rather than nested inline so the tree it
              // wraps stays where it is.
              return Focus(
                autofocus: true,
                onKeyEvent: (node, event) =>
                    _handleKeyEvent(event, mediaList.length),
                // Adjust color (issue #3520). Photos only pick white here:
                // this viewer shows a video's poster, not a player.
                child: colorAdjustLayout(
                  item: currentItem,
                  fullscreen: isFullscreen,
                  pickWhiteAvailable: !currentItem.isVideo,
                  onPickWhite: togglePickWhite,
                  child: viewer,
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (error, stack) => Center(
              child: Text(
                context.l10n.media_photoViewer_errorLoadingPhotos(
                  error.toString(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareCurrentItem(MediaItem item, Rect? anchor) async {
    // Shared resolve-and-share flow (the dive viewer and the library use it
    // too), so a corrected video goes out re-encoded here as well (#3521).
    await shareMediaItems(context, ref, [item], anchor: anchor);
  }
}

/// The gallery pager using PhotoView for zoom support.
class _MediaGalleryPager extends StatelessWidget {
  final List<MediaItem> mediaList;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  /// Whether paging by swipe is off: a sitting is stepped out of only
  /// through its check (issue #4527).
  final bool pagingLocked;

  const _MediaGalleryPager({
    required this.mediaList,
    required this.pageController,
    required this.onPageChanged,
    this.pagingLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return PhotoViewGallery.builder(
      scrollPhysics: pagingLocked
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      pageController: pageController,
      // Build the page either side of the current one, so the next photo has
      // resolved and decoded before a swipe or arrow press brings it in.
      // Built on demand, it slid in empty and popped in afterwards (#3298).
      // Each page's decode is bounded by MediaItemView, so the extra
      // neighbour costs one viewport-sized bitmap, not an original.
      allowImplicitScrolling: true,
      itemCount: mediaList.length,
      onPageChanged: onPageChanged,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      builder: (context, index) {
        final item = mediaList[index];
        // A video's still is its poster, sized to the display's pixels: the
        // poster is fetched at targetSize, so points would make it a third
        // of the screen's resolution at 3x, and the window's size would
        // fetch it again on every frame of a desktop window resize (issue
        // #4699). Drawn as a photo,
        // it resolved the original: a photo-library video was read whole
        // into memory, hundreds of MB for a 4K clip, and handed to the image
        // decoder, which cannot read it.
        final video = item.isVideo;
        return PhotoViewGalleryPageOptions.customChild(
          minScale: PhotoViewComputedScale.contained,
          maxScale: video
              ? PhotoViewComputedScale.contained
              : PhotoViewComputedScale.covered * 3.0,
          // A full-screen pager: a photo outside a limited selection offers
          // the ways back here, as in the dive viewer (spec 6.3).
          child: MediaItemView(
            item: item,
            fit: BoxFit.contain,
            showAccessActions: true,
            thumbnail: video,
            targetSize: video ? View.of(context).display.size : null,
          ),
        );
      },
      loadingBuilder: (context, event) =>
          const Center(child: CircularProgressIndicator(color: Colors.white54)),
    );
  }
}

/// Top overlay with close and fullscreen buttons, page indicator, and share
/// button.
class _TopOverlay extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;
  final VoidCallback onEnterFullscreen;
  final void Function(Rect? anchor) onShare;
  final VoidCallback? onEditDetails;
  final VoidCallback onAdjustColor;

  /// Unlocks the photo (issue #4527); null offers no lock.
  final VoidCallback? onUnlock;

  /// Non-null while unlocked: drawn as the shared editing bar.
  final MediaViewerEditBar? editBar;

  const _TopOverlay({
    required this.onAdjustColor,
    this.onUnlock,
    this.editBar,
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
    required this.onEnterFullscreen,
    required this.onShare,
    this.onEditDetails,
  });

  /// The editing bar's actions: Adjust color, Edit details and Share, with
  /// Share kept in the bar longest.
  List<MediaViewerAction> _editActions(BuildContext context) {
    final l10n = context.l10n;
    final details = onEditDetails;
    return [
      MediaViewerAction(
        id: 'adjust_color',
        icon: Icons.palette_outlined,
        label: l10n.media_color_adjustAction,
        priority: 1,
        onPressed: (_) => onAdjustColor(),
      ),
      if (details != null)
        MediaViewerAction(
          id: 'edit_details',
          icon: Icons.edit_outlined,
          label: l10n.media_siteAttachment_editDetails,
          priority: 2,
          onPressed: (_) => details(),
        ),
      MediaViewerAction(
        id: 'share',
        icon: Icons.share,
        label: l10n.media_photoViewer_shareTooltip,
        priority: 0,
        onPressed: (anchor) => onShare(shareAnchorFrom(anchor)),
      ),
    ];
  }

  // Builder so the iPad share popover anchors to this button:
  // findRenderObject from a Builder's context descends to the IconButton
  // rather than yielding the whole overlay.
  Widget _share(BuildContext context, Color? color) => Builder(
    builder: (buttonContext) => IconButton(
      icon: Icon(Icons.share, color: color),
      tooltip: context.l10n.media_photoViewer_shareTooltip,
      onPressed: () => onShare(shareAnchorFrom(buttonContext)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bar = editBar;
    if (bar != null) {
      // In the toolbar's band, so the photo does not move on unlock; the
      // actions take the bar's own colours.
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: MediaQuery.paddingOf(context).top + kMediaViewerToolbarHeight,
        // A semantics container of its own: without it the bar's nodes
        // mix with the viewer's full-screen tap target under it, and the
        // semantics tree is left half built after a dialog closes.
        child: Semantics(
          container: true,
          // The bar's own width: on a narrow window the actions fold into
          // the overflow menu, as in the dive viewer's bar.
          child: LayoutBuilder(
            builder: (context, constraints) => RecordEditBar(
              title: bar.title,
              canSave: bar.canSave,
              isSaving: bar.isSaving,
              onCancel: bar.onCancel,
              onSave: bar.onSave,
              actions: toolbarActionButtons(
                context,
                splitToolbarActions(
                  _editActions(context),
                  editBarActionsWidth(constraints.maxWidth),
                ),
                null,
              ),
            ),
          ),
        ),
      );
    }
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: context.l10n.media_photoViewer_closeTooltip,
                  onPressed: onClose,
                ),
                IconButton(
                  key: const ValueKey('viewer_enter_fullscreen'),
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  tooltip: context.l10n.media_viewer_enterFullscreen,
                  onPressed: onEnterFullscreen,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      context.l10n.media_photoViewer_pageIndicator(
                        currentIndex + 1,
                        totalCount,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (onUnlock != null)
                  IconButton(
                    key: const ValueKey('viewer_unlock'),
                    icon: const Icon(Icons.lock_outline, color: Colors.white),
                    tooltip: context.l10n.recordEdit_unlockTooltip,
                    onPressed: onUnlock,
                  ),
                _share(context, Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom overlay showing capture time and caption for the current item.
class _BottomMetadataOverlay extends ConsumerWidget {
  final MediaItem item;

  const _BottomMetadataOverlay({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.caption != null && item.caption!.isNotEmpty) ...[
                  Text(
                    item.caption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  units.formatDateTime(item.takenAt, l10n: context.l10n),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
