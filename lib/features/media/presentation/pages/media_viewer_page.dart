import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/metadata_write_service.dart';
import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_editing.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';
import 'package:submersion/features/media/presentation/helpers/media_share_helper.dart';
import 'package:submersion/features/media/presentation/helpers/set_time_seed.dart';
import 'package:submersion/features/media/presentation/helpers/viewer_audio.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_fullscreen_controls.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_nav_arrows.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';
import 'package:submersion/features/media/presentation/widgets/write_metadata_dialog.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/services/media_location.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/face_box_layer.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/media_people_chips_row.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/people_tag_editor.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/people_tag_viewer_mixin.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/video_people_layer.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_caption.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_list_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/features/media/presentation/widgets/video_color_filter.dart';
import 'package:submersion/features/media/presentation/widgets/video_controls_auto_hide.dart';
import 'package:submersion/features/media/presentation/widgets/video_controls_bar.dart';
import 'package:submersion/shared/widgets/size_reporter.dart';
import 'package:submersion/features/media/presentation/helpers/color_pick_white.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_viewer_mixin.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/pick_white_hint.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_correction_label.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';
import 'package:submersion/features/media/presentation/widgets/video_playback_opener.dart';
import 'package:submersion/features/media/presentation/providers/video_playback_providers.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_reupload_menu.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/media/presentation/match_confidence_display.dart';
import 'package:submersion/features/species_id/presentation/widgets/identification_labels.dart';
import 'package:submersion/features/species_id/presentation/widgets/identification_trigger.dart';
import 'package:submersion/features/species_id/presentation/widgets/labels_menu.dart';
import 'package:submersion/features/species_id/presentation/widgets/photo_identification_layer.dart';
import 'package:submersion/features/species_id/presentation/widgets/video_identification_layer.dart';
import 'package:submersion/features/species_id/presentation/widgets/video_playhead_reporter.dart';

part 'media_viewer_actions.dart';
part 'media_viewer_bottom_metadata.dart';
part 'media_viewer_chrome.dart';
part 'media_viewer_gallery.dart';
part 'media_viewer_perdix.dart';
part 'media_viewer_video_item.dart';
part 'media_viewer_write_metadata.dart';

const _log = LoggerService('MediaViewerPage', category: LogCategory.media);

/// Full-screen media viewer with pinch-to-zoom and swipe navigation over an
/// arbitrary media list (a dive's media, a trip's flat list, or a library
/// page snapshot).
///
/// Dive context — enrichment overlays, the mini profile, and the Perdix face
/// — keys off the *current item's* dive and hides itself for items with no
/// dive link.
class MediaViewerPage extends ConsumerStatefulWidget {
  /// The media to page through, in display order. Immutable snapshot.
  final List<MediaItem> mediaList;

  /// The initial media item ID to display.
  final String initialMediaId;

  /// Shows a "Go to dive" action on items with a dive link. Enabled by
  /// cross-dive callers (trips, library); off inside dive detail, which is
  /// already on the dive.
  final bool showGoToDive;

  /// A line naming where the current item comes from, such as the check-in
  /// a gear photo backs up (issue #3355); null or an empty result shows none.
  final String? Function(MediaItem)? captionFor;

  const MediaViewerPage({
    super.key,
    required this.mediaList,
    required this.initialMediaId,
    this.showGoToDive = false,
    this.captionFor,
  });

  @override
  ConsumerState<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends ConsumerState<MediaViewerPage>
    with
        MediaFullscreenMixin<MediaViewerPage>,
        VideoControlsAutoHideMixin<MediaViewerPage>,
        ColorAdjustViewerMixin<MediaViewerPage>,
        PeopleTagViewerMixin<MediaViewerPage>,
        PhotoViewerEditing<MediaViewerPage> {
  /// Tag mode holds its changes in the photo's sitting.
  @override
  EditSession<PhotoRecord>? get peopleSitting => photoSitting;

  /// Adjust color holds its changes in the photo's sitting.
  @override
  EditSession<PhotoRecord>? get colorSitting => photoSitting;

  /// Locking, by any route, closes what changes the photo.
  @override
  void onPhotoLocked() {
    closeColorEditing();
    dismissHeldOffer();
    if (taggingPeople) togglePeopleTagging();
  }

  /// The pageable subset of [MediaViewerPage.mediaList].
  ///
  /// Documents (PDF, docx, ...) resolve to raw bytes the Image widgets cannot
  /// decode, so they never enter the pager: they would render as a grey
  /// placeholder tile, count toward the "n / m" indicator, and be swipeable
  /// onto for no purpose. Filtering here rather than in each caller covers
  /// every wrapper at once (PhotoViewerPage, TripPhotoViewerPage,
  /// SiteMediaViewerPage, and the library view), which is what the per-caller
  /// guards kept missing.
  List<MediaItem> get _pageableMedia =>
      widget.mediaList.where((m) => !m.isDocument).toList();

  final _metadataWriter = MetadataWriteService();

  late PageController _pageController;
  int _currentIndex = 0;

  /// The page the last nav request aimed at, which runs ahead of
  /// [_currentIndex] while the pager is still animating. See [_stepPage].
  int _navTargetIndex = 0;

  bool _showOverlay = true;

  /// The bottom panel's height as last laid out, which the fish labels on
  /// a video keep above (issue #4762), and an unlocked photo's (#4825).
  double _bottomPanelHeight = 0;

  /// The bottom panel was laid out at [height]. A video's fish labels read
  /// it, and an unlocked photo's; a locked photo's panel just records it,
  /// without a rebuild, and the unlock reads it.
  void _onBottomPanelHeight(double height, {required bool video}) {
    if (!mounted || height == _bottomPanelHeight) return;
    if (!video && photoLocked) {
      _bottomPanelHeight = height;
      return;
    }
    setState(() => _bottomPanelHeight = height);
  }

  @override
  bool get videoOverlayShown => _showOverlay;

  @override
  void setVideoOverlayShown(bool shown) => setState(() => _showOverlay = shown);

  /// Dives whose enrichment backfill has already been attempted this session,
  /// so a swipe through several un-enriched items of one dive runs it once.
  final Set<String> _enrichAttempted = {};

  /// Live video controllers hoisted from _VideoItem, keyed by media id, so
  /// the Perdix overlay (mounted at page level) can follow playback. Entries
  /// come and go as gallery pages initialize/dispose.
  final Map<String, VideoPlayerController> _videoControllers = {};

  /// The videos' sound, muted on open, for as long as the viewer is (#4817).
  final _audio = ViewerAudio();

  void _onVideoControllerChanged(
    String mediaId,
    VideoPlayerController? controller,
  ) {
    if (!mounted) return;
    if (controller == null) {
      // The removal path runs from _VideoItemState.dispose, which can fire
      // while the tree is locked (viewer teardown, page eviction). Drop the
      // dead controller immediately so nothing reads it, but defer the
      // rebuild to the next frame.
      final released = _videoControllers.remove(mediaId);
      if (released != null) unwatchVideoPlayState(released);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      watchVideoPlayState(controller);
      setState(() => _videoControllers[mediaId] = controller);
    }
  }

  /// Resolves the live record for the item on screen when the caller passed a
  /// lean one.
  ///
  /// Two things make the passed item untrustworthy for dive context. The
  /// Media section's library query hydrates rows without the enrichment join
  /// on purpose (grids never render photo-time depth), so its items always
  /// carry `enrichment == null`. And [MediaViewerPage.mediaList] is an
  /// immutable snapshot taken when the route was pushed, so a re-link since
  /// then leaves it reporting the *old* dive link, or none at all.
  ///
  /// Reading the one item actually on screen straight from the database
  /// settles both: the library keeps its lean grid, and the viewer keeps
  /// showing the truth. [mediaByIdProvider] self-invalidates on media and
  /// enrichment changes, so a re-link or a backfill that happens while the
  /// viewer is open lands too.
  ///
  /// Deliberately unconditional. Skipping the read for a snapshot that
  /// already carries an enrichment would save one keyed lookup on the
  /// dive-detail path, but a snapshot holding an enrichment is no more
  /// current than one holding none: both were captured when the route was
  /// pushed. Trusting it is what produced this class of bug twice already,
  /// so the rule is that the on-screen item always comes from the database.
  /// The passed item stands in only while the read is in flight.
  MediaItem _hydrate(MediaItem item) =>
      ref.watch(mediaByIdProvider(item.id)).value ?? item;

  @override
  void initState() {
    super.initState();
    final initialIndex = _pageableMedia.indexWhere(
      (m) => m.id == widget.initialMediaId,
    );
    _currentIndex = initialIndex == -1 ? 0 : initialIndex;
    _navTargetIndex = _currentIndex;
    _pageController = PageController(initialPage: _currentIndex);

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
    _audio.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  void onExitFullscreen() => _showOverlay = true;

  /// Video play/pause reports here: [show] is true when the video just
  /// paused. Outside fullscreen that drives the overlays as before; inside
  /// it reveals the fullscreen controls, which stay up while paused.
  void _onSetOverlay(bool show) {
    if (isFullscreen) {
      revealFullscreenControls(autoHide: !show);
      return;
    }
    cancelVideoOverlayClock();
    setState(() => _showOverlay = show);
  }

  /// Steps [delta] pages from the last page *requested*, not the last one
  /// settled on.
  ///
  /// onPageChanged only fires once the pager crosses the halfway point, so
  /// [_currentIndex] lags an in-flight animation; stepping from it would drop
  /// the second of two quick presses instead of advancing two items.
  void _stepPage(int delta) {
    if (!_pageController.hasClients) return;
    final count = keepSittingPhoto(_pageableMedia).length;
    if (count == 0) return;
    // The gallery is live and can shrink under the viewer, stranding the nav
    // target past the new end. Clamp to the same bounds the arrows and the
    // page indicator are drawn from, or every press would fall out of range
    // and navigation would freeze with the controls still showing.
    final target = _navTargetIndex.clamp(0, count - 1) + delta;
    // Out-of-range steps do nothing: the ends of the list do not wrap.
    if (target < 0 || target >= count) return;
    _navTargetIndex = target;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Keyboard navigation for pointer platforms: arrows page, Escape closes.
  ///
  /// This node is an ancestor of the video item's own [Focus], which handles
  /// only the space bar and returns [KeyEventResult.ignored] for everything
  /// else, so arrows keep working while a video holds focus. Arrow presses are
  /// reported handled even at the ends of the list, which keeps them from
  /// falling through to default directional focus traversal.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      // Escape backs out one step at a time: in a sitting, Pick white and
      // the colour panel first (issue #4527), then people tag mode.
      if (photoUnlocked && pickingWhite) {
        togglePickWhite();
        return KeyEventResult.handled;
      }
      if (photoUnlocked && colorPanelOpen) {
        closeColorEditing();
        return KeyEventResult.handled;
      }
      if (taggingPeople) {
        togglePeopleTagging();
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
    // A sitting keeps its photo here while the photo exists (issue #4527).
    final mediaList = keepSittingPhoto(_pageableMedia);
    // The gallery is live: a delete elsewhere, a dive-deletion cascade, or a
    // sync pull can shrink it under the open viewer. Clamp once here and use
    // this everywhere rather than writing it back during build -- PageView
    // corrects _currentIndex itself on the next settle via onPageChanged, so
    // the clamp only has to survive one frame.
    final shownIndex = mediaList.isEmpty
        ? 0
        : _currentIndex.clamp(0, mediaList.length - 1);
    // A sitting stays on its own photo as the list moves under it.
    final sittingIndex = photoUnlocked ? sittingIndexIn(mediaList) : null;
    if (sittingIndex != null && sittingIndex != shownIndex) {
      _followSittingTo(sittingIndex);
    }
    final currentIndex = sittingIndex ?? shownIndex;
    // Resolve the live record BEFORE reading any dive context off it. Taking
    // the dive link from the snapshot instead is what left a freshly
    // re-linked photo looking unlinked: no Go-to-dive, no depth chips, no
    // mini profile, no dive computer.
    final hydratedItem = mediaList.isEmpty
        ? null
        : _hydrate(mediaList[currentIndex]);
    final currentDiveId = hydratedItem?.diveId;
    final storedPhoto = hydratedItem == null
        ? null
        : followStoredPhoto(hydratedItem);
    final diveAsync = currentDiveId == null
        ? const AsyncValue<Dive?>.data(null)
        : ref.watch(diveProvider(currentDiveId));
    final units = ref.watch(unitFormatterProvider);
    final settings = ref.watch(
      settingsProvider.select(
        (s) => (
          perdixOverlayEnabled: s.perdixOverlayEnabled,
          perdixOverlayX: s.perdixOverlayX,
          perdixOverlayY: s.perdixOverlayY,
        ),
      ),
    );

    return photoEditScope(
      backsOutFirst: () => isFullscreen,
      child: fullscreenPopScope(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Builder(
            builder: (context) {
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

              // Non-null once mediaList is known non-empty. Every consumer below
              // reads the hydrated record: the mini profile, the Perdix gate, the
              // toolbar's Go-to-dive and write-metadata flags, the bottom
              // depth/temp/elapsed chips and the info sheet.
              final heldProfile = diveAsync.value?.profile ?? const [];
              final currentItem = shownItem(hydratedItem!, heldProfile);
              final enrichment = currentItem.enrichment;
              if (enrichment == null && currentDiveId != null) {
                _backfillEnrichment(currentDiveId);
              }

              // Get dive profile for the mini chart overlay
              final diveProfile = diveAsync.whenOrNull(
                data: (dive) => dive?.profile ?? [],
              );

              final dive = diveAsync.value;
              final profileLength = MediaDiveWindow.profileLengthSeconds(
                diveProfile ?? const [],
              );
              // Whether this item is synced to a moment in the profile, decided
              // from the enrichment alone (inside the dive-window tolerance, or
              // pinned by the diver). Media that is not synced can never show
              // the Perdix face, whatever the analysis would say.
              final positioned =
                  enrichment != null &&
                  enrichment.isWithinDiveWindow(profileLength);
              final perdixPrecondition = positioned;

              PerdixFaceResolver? perdixResolver;
              if (currentDiveId != null &&
                  perdixPrecondition &&
                  settings.perdixOverlayEnabled) {
                perdixResolver = _perdixResolverFor(currentDiveId, dive);
              }
              // Toolbar-toggle visibility, decided the same cheap way in BOTH
              // toggle states: a synced item and a non-empty merged profile.
              // Deliberately NOT the resolver's answer. On a multi-computer dive
              // whose ACTIVE source is metadata-only, the resolver scopes to an
              // empty bucket and reports unavailable; a toggle that followed it
              // would vanish the moment the user turned it on, stranding the
              // setting with no control on this page to turn it back off. The
              // cheap test's cost is an inert toggle in that case, never a
              // vanished one. The resolver's own availability still gates the
              // face mount below.
              final perdixToggleAvailable =
                  perdixPrecondition && (diveProfile?.isNotEmpty ?? false);

              // People tag mode (issue #1745), shared with every gallery page.
              final peopleSession = buildPeopleSession(
                pauseVideo: (id) => unawaited(_videoControllers[id]?.pause()),
              );

              // The bottom panel, a video's scrub bar its top row so no tag
              // can cover it (issue #4762).
              final panelShown =
                  (_showOverlay || photoUnlocked) &&
                  !isFullscreen &&
                  !pickingWhite &&
                  !taggingPeople;
              final miniProfileShown =
                  diveProfile != null && diveProfile.isNotEmpty && positioned;

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
                      child: _PhotoGallery(
                        mediaList: shownMediaList(mediaList, heldProfile),
                        pagingLocked: photoUnlocked,
                        pageController: _pageController,
                        onPageChanged: (index) {
                          // Swipes and settles both land here, which is what
                          // re-syncs the nav target after a gesture.
                          setState(() {
                            _currentIndex = index;
                            _navTargetIndex = index;
                            selectedPeopleTagId = null;
                          });
                          // Controls left up on a paused video have no timer; the
                          // next page restarts the 3-second hide so they do not
                          // linger over a photo nobody tapped.
                          if (isFullscreen && fullscreenControlsVisible) {
                            revealFullscreenControls(autoHide: true);
                          }
                          // A mouse-move clock left by a video is not the
                          // next page's to act on.
                          cancelVideoOverlayClock();
                        },
                        showOverlay: isFullscreen
                            ? fullscreenControlsVisible
                            : _showOverlay || photoUnlocked,
                        fullscreen: isFullscreen,
                        onFullscreenTap: toggleFullscreenControls,
                        onSetOverlay: _onSetOverlay,
                        onVideoHoldChanged: videoHoldChanged,
                        onVideoControllerChanged: _onVideoControllerChanged,
                        audio: _audio,
                        currentIndex: currentIndex,
                        people: peopleSession,
                        identificationsEditable: !photoLocked,
                        hideIdentifications: pickingWhite,
                        videoControlsInset: panelShown ? _bottomPanelHeight : 0,
                      ),
                    ),

                    // A photo's tap layer; a video takes its own taps.
                    if (!currentItem.isVideo)
                      Positioned.fill(
                        child: Semantics(
                          label:
                              context.l10n.media_photoViewer_toggleOverlayLabel,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: taggingPeople && !pickingWhite
                                ? null
                                : _photoTapUp(
                                    currentItem,
                                    () => context.size ?? Size.zero,
                                    isFullscreen
                                        ? toggleFullscreenControls
                                        : () {
                                            cancelVideoOverlayClock();
                                            setState(
                                              () =>
                                                  _showOverlay = !_showOverlay,
                                            );
                                          },
                                  ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),

                    // "Pick white" on a paused video: the player owns ordinary
                    // taps, so the pick gets its own catcher above it.
                    if (pickingWhite && currentItem.isVideo)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, box) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) => _pickWhiteAt(
                              currentItem,
                              details.localPosition,
                              box.biggest,
                            ),
                          ),
                        ),
                      ),
                    if (pickingWhite) const PickWhiteHint(),

                    // Looks for marine life in the photo on screen (issue
                    // #4668); never for the neighbours built ahead.
                    IdentificationTrigger(
                      key: const ValueKey('media_identification_trigger'),
                      item: currentItem,
                      location: _photoLocation(currentItem, diveAsync.value),
                    ),

                    // The controls; while unlocked the bar never hides: it
                    // holds Cancel and Save.
                    if ((_showOverlay || photoUnlocked) &&
                        !isFullscreen &&
                        !pickingWhite) ...[
                      // Top app bar
                      _toolbar(
                        context,
                        currentItem: currentItem,
                        currentIndex: currentIndex,
                        totalCount: mediaList.length,
                        currentDiveId: currentDiveId,
                        enrichment: enrichment,
                        perdixToggleAvailable: perdixToggleAvailable,
                        perdixEnabled: settings.perdixOverlayEnabled,
                        storedPhoto: storedPhoto,
                        location: _photoLocation(currentItem, diveAsync.value),
                      ),

                      // What colour correction the item is drawn with.
                      Positioned(
                        top:
                            MediaQuery.paddingOf(context).top +
                            kMediaViewerToolbarHeight +
                            4,
                        left: 12,
                        child: ColorCorrectionLabel(item: currentItem),
                      ),

                      // Where the item comes from (issue #3355).
                      if (widget.captionFor?.call(currentItem)
                          case final caption? when caption.isNotEmpty)
                        Positioned(
                          top:
                              MediaQuery.paddingOf(context).top +
                              kMediaViewerToolbarHeight +
                              4,
                          right: 12,
                          child: MediaViewerCaption(text: caption),
                        ),

                      // Tag mode keeps the photo clear below the toolbar.
                      if (!taggingPeople) ...[
                        // Previous / next controls. Mounted with the rest of the
                        // chrome, so the tap-to-hide gesture takes them away too.
                        MediaNavArrows(
                          currentIndex: currentIndex,
                          totalCount: mediaList.length,
                          onPrevious: () => _step(-1),
                          onNext: () => _step(1),
                        ),

                        // Mini dive profile overlay (lower right)
                        if (diveProfile != null &&
                            diveProfile.isNotEmpty &&
                            positioned)
                          PositionedMiniProfileOverlay(
                            profile: diveProfile,
                            photoElapsedSeconds: enrichment.elapsedSeconds!,
                            photoDepthMeters: enrichment.depthMeters,
                            settings: units.settings,
                            visible: _showOverlay || photoUnlocked,
                          ),

                        // Bottom metadata
                        _bottomPanel(
                          context,
                          item: currentItem,
                          settings: units.settings,
                          diveProfile: diveProfile,
                          profileLength: profileLength,
                          photoLocked: photoLocked,
                          siteName: diveAsync.whenOrNull(
                            data: (dive) => dive?.site?.name,
                          ),
                          miniProfileShown: miniProfileShown,
                        ),
                      ],
                    ],

                    // People tag mode's hint and actions (issue #1745).
                    if (taggingPeople)
                      peopleTagHint(
                        currentItem,
                        video: currentItem.isVideo
                            ? _videoControllers[currentItem.id]?.value
                            : null,
                        onShowMoment: (tag) => _showMoment(currentItem, tag),
                      ),

                    // Perdix dive computer overlay. Deliberately independent of
                    // the _showOverlay chrome, which auto-hides during video
                    // playback exactly when this must stay up.
                    //
                    // Mounted ABOVE the chrome so it always wins the pointers
                    // that drag it: the bottom metadata's gradient Container and
                    // the mini profile chart both absorb hit tests across their
                    // full bounds, and either would strand the face where it
                    // could no longer be picked up. Neither is interactive, so
                    // nothing is lost by the face shadowing them. The top
                    // toolbar is the exception -- it does have buttons -- so
                    // rather than order, the face is kept out of its band
                    // entirely via topReserve.
                    //
                    // The face absorbs pointer events over its own bounds (drags
                    // move it, taps do nothing); chrome-toggle and video
                    // play/pause taps work anywhere outside it.
                    if (!isFullscreen &&
                        settings.perdixOverlayEnabled &&
                        perdixResolver != null &&
                        perdixResolver.isAvailable)
                      DraggablePerdixOverlay(
                        // Re-key when the persisted seed first arrives so a late
                        // settings load re-seeds the position (same trick as the
                        // fullscreen readout card).
                        key: ValueKey(
                          'perdix-${currentItem.id}-'
                          '${settings.perdixOverlayX}-${settings.perdixOverlayY}',
                        ),
                        resolver: perdixResolver,
                        // Non-null here: the resolver is only ever built for
                        // items passing perdixPrecondition.
                        baseElapsedSeconds: enrichment!.elapsedSeconds!,
                        settings: units.settings,
                        topReserve:
                            MediaQuery.paddingOf(context).top +
                            kMediaViewerToolbarHeight,
                        playback: currentItem.isVideo
                            ? _videoControllers[currentItem.id]
                            : null,
                        positionGetter:
                            currentItem.isVideo &&
                                _videoControllers[currentItem.id] != null
                            ? () =>
                                  _videoControllers[currentItem.id]
                                      ?.value
                                      .position ??
                                  Duration.zero
                            : null,
                        initialFraction:
                            (settings.perdixOverlayX != null &&
                                settings.perdixOverlayY != null)
                            ? Offset(
                                settings.perdixOverlayX!,
                                settings.perdixOverlayY!,
                              )
                            : null,
                        onDragEnd: (fraction) => ref
                            .read(settingsProvider.notifier)
                            .setPerdixOverlayPosition(fraction.dx, fraction.dy),
                      ),

                    if (isFullscreen && fullscreenControlsVisible)
                      MediaFullscreenExitButton(onExit: exitFullscreen),
                  ],
                ),
              );

              // A mouse move brings a video's controls up, and they go again
              // once it rests or leaves the window while the video plays.
              final videoOnScreen = currentItem.isVideo
                  ? _videoControllers[currentItem.id]
                  : null;
              final hoverViewer = MouseRegion(
                onHover: (_) => videoPointerMoved(videoOnScreen),
                onExit: (_) => videoPointerLeft(videoOnScreen),
                child: viewer,
              );

              // Keyboard nav has to wrap the whole viewer to see its key events.
              // Built as a local above rather than nested inline so the tree it
              // wraps stays where it is.
              return Focus(
                autofocus: true,
                onKeyEvent: _handleKeyEvent,
                // Adjust color (issue #3520).
                child: colorAdjustLayout(
                  item: currentItem,
                  fullscreen: isFullscreen,
                  pickWhiteAvailable:
                      !currentItem.isVideo ||
                      _videoControllers[currentItem.id] != null,
                  onPickWhite: () => _startPickingWhite(currentItem),
                  child: hoverViewer,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
