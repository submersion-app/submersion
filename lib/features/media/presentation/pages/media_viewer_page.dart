import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/media/data/services/metadata_write_service.dart';
import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';
import 'package:submersion/features/media/presentation/helpers/media_share_helper.dart';
import 'package:submersion/features/media/presentation/helpers/set_time_seed.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_nav_arrows.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';
import 'package:submersion/features/media/presentation/widgets/write_metadata_dialog.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_reupload_button.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

  const MediaViewerPage({
    super.key,
    required this.mediaList,
    required this.initialMediaId,
    this.showGoToDive = false,
  });

  @override
  ConsumerState<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends ConsumerState<MediaViewerPage> {
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

  late PageController _pageController;
  int _currentIndex = 0;

  /// The page the last nav request aimed at, which runs ahead of
  /// [_currentIndex] while the pager is still animating. See [_stepPage].
  int _navTargetIndex = 0;

  bool _showOverlay = true;

  /// Dives whose enrichment backfill has already been attempted this session,
  /// so a swipe through several un-enriched items of one dive runs it once.
  final Set<String> _enrichAttempted = {};

  /// Live video controllers hoisted from _VideoItem, keyed by media id, so
  /// the Perdix overlay (mounted at page level) can follow playback. Entries
  /// come and go as gallery pages initialize/dispose.
  final Map<String, VideoPlayerController> _videoControllers = {};

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
      _videoControllers.remove(mediaId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
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

  /// Opens the Set-time dialog for [item] and applies the diver's choice
  /// (issue #1090). The viewer re-reads the row on the media tick the write
  /// raises, so the chips, the mini profile and the face all move at once.
  Future<void> _setTimeInDive(
    MediaItem item,
    List<DiveProfilePoint> profile,
    AppSettings settings,
  ) async {
    final choice = await showSetMediaTimeDialog(
      context,
      profile: profile,
      initialElapsedSeconds: setTimeSeedFor(
        item,
        profileLengthSeconds: MediaDiveWindow.profileLengthSeconds(profile),
      ),
      isPinned: item.manualElapsedSeconds != null,
      settings: settings,
    );
    if (choice == null || !mounted) return;
    await ref.read(mediaTimePinnerProvider).apply(item, choice);
  }

  /// Computes and saves the missing [MediaEnrichment] rows for [diveId], the
  /// same idempotent backfill dive detail runs on open.
  ///
  /// Media linked from a local file gets a row but no enrichment, and until
  /// now only dive detail ever closed that gap: a photo could show its depth
  /// and profile marker there and nothing at all in the Media section.
  void _backfillEnrichment(String diveId) {
    if (!_enrichAttempted.add(diveId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // The callback can fire after this state is disposed; touching `ref`
      // then throws, so bail before using it.
      if (!mounted) return;
      try {
        // Nothing to invalidate by hand: saving an enrichment ticks
        // watchMediaChanges, and mediaByIdProvider self-invalidates on it, so
        // the overlays pick the row up on the next frame. An invalidate here
        // would also have to guess which ids were affected, and guessing from
        // widget.mediaList is exactly what failed -- the snapshot still says
        // diveId == null for the media that was just linked.
        await ref.read(diveMediaEnricherProvider).enrichMissingForDive(diveId);
      } catch (_) {
        // Best-effort: a failure just leaves the overlays absent this session.
      }
    });
  }

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
  void _stepPage(int delta) {
    if (!_pageController.hasClients) return;
    final count = _pageableMedia.length;
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
      _stepPage(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _stepPage(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = _pageableMedia;
    // The gallery is live: a delete elsewhere, a dive-deletion cascade, or a
    // sync pull can shrink it under the open viewer. Clamp once here and use
    // this everywhere rather than writing it back during build -- PageView
    // corrects _currentIndex itself on the next settle via onPageChanged, so
    // the clamp only has to survive one frame.
    final currentIndex = mediaList.isEmpty
        ? 0
        : _currentIndex.clamp(0, mediaList.length - 1);
    // Resolve the live record BEFORE reading any dive context off it. Taking
    // the dive link from the snapshot instead is what left a freshly
    // re-linked photo looking unlinked: no Go-to-dive, no depth chips, no
    // mini profile, no dive computer.
    final hydratedItem = mediaList.isEmpty
        ? null
        : _hydrate(mediaList[currentIndex]);
    final currentDiveId = hydratedItem?.diveId;
    final diveAsync = currentDiveId == null
        ? const AsyncValue<Dive?>.data(null)
        : ref.watch(diveProvider(currentDiveId));
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          if (mediaList.isEmpty) {
            return Center(
              child: Text(
                context.l10n.media_photoViewer_noPhotosAvailable,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          // Non-null once mediaList is known non-empty. Every consumer below
          // reads the hydrated record: the mini profile, the Perdix gate, the
          // toolbar's Go-to-dive and hasEnrichment flags, the bottom
          // depth/temp/elapsed chips and the info sheet.
          final currentItem = hydratedItem!;
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

          // Same source-aware profile/analysis pairing as the fullscreen
          // profile page: analysis curves are read by index, so the profile
          // passed to the resolver must be the one the analysis was computed
          // over (multi-computer dives).
          //
          // Built ONLY when the face can actually render: a dive-linked,
          // profile-synced item with the overlay turned on. The watches
          // below start the per-source profile analysis, and through it the
          // full Buhlmann pipeline with its recursive residual-CNS/tissue
          // lookback across the surrounding dives. Watching that
          // unconditionally ran the whole cascade on the UI isolate for
          // every dive-linked item the viewer showed, with the result
          // discarded whenever the overlay was off -- the first ingredient
          // of the app-wide freeze after viewing media (2026-08 hang
          // reports). Toggling the overlay on simply rebuilds and starts the
          // watches then.
          PerdixFaceResolver? perdixResolver;
          if (currentDiveId != null &&
              perdixPrecondition &&
              settings.perdixOverlayEnabled) {
            final activeSourceId = ref.watch(
              activeDiveSourceProvider(currentDiveId),
            );
            final analysis = ref
                .watch(
                  sourceProfileAnalysisProvider((
                    diveId: currentDiveId,
                    sourceId: activeSourceId,
                  )),
                )
                .value;
            final sourceProfiles =
                ref.watch(sourceProfilesProvider(currentDiveId)).value ??
                const {};
            final dataSources =
                ref.watch(diveDataSourcesProvider(currentDiveId)).value ??
                const [];
            final gasSwitches =
                ref.watch(gasSwitchesProvider(currentDiveId)).value ?? const [];
            final tankPressures = ref
                .watch(tankPressuresProvider(currentDiveId))
                .value;
            final primarySource =
                dataSources.where((s) => s.isPrimary).firstOrNull ??
                dataSources.firstOrNull;
            final activeSource = activeSourceId == null
                ? primarySource
                : dataSources
                          .where((s) => s.id == activeSourceId)
                          .firstOrNull ??
                      primarySource;
            final activeProfile = activeSource == null
                ? null
                : sourceProfiles[activeSource.id];
            final perdixProfile =
                (dataSources.length >= 2 && activeProfile != null)
                ? activeProfile.points
                : dive?.profile ?? const [];
            // Rebuilt only on page-level setState (page swipes, toggles),
            // not per video frame; prefix-max and gas segments precompute
            // here.
            perdixResolver = PerdixFaceResolver(
              profile: perdixProfile,
              analysis: analysis,
              tanks: dive?.tanks ?? const [],
              gasSwitches: gasSwitches,
              tankPressures: tankPressures,
            );
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

          final viewer = GestureDetector(
            // Swipe down to close (common pattern for fullscreen viewers)
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 300) {
                Navigator.of(context).pop();
              }
            },
            child: Stack(
              children: [
                // Photo/video gallery
                _PhotoGallery(
                  mediaList: mediaList,
                  pageController: _pageController,
                  onPageChanged: (index) {
                    // Swipes and settles both land here, which is what
                    // re-syncs the nav target after a gesture.
                    setState(() {
                      _currentIndex = index;
                      _navTargetIndex = index;
                    });
                  },
                  showOverlay: _showOverlay,
                  onToggleOverlay: () =>
                      setState(() => _showOverlay = !_showOverlay),
                  onSetOverlay: (value) => setState(() => _showOverlay = value),
                  onVideoControllerChanged: _onVideoControllerChanged,
                  currentIndex: currentIndex,
                ),

                // Transparent tap target to toggle overlays (photos only)
                // Videos handle their own tap gestures for play/pause
                if (!currentItem.isVideo)
                  Positioned.fill(
                    child: Semantics(
                      label: context.l10n.media_photoViewer_toggleOverlayLabel,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () =>
                            setState(() => _showOverlay = !_showOverlay),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),

                // Overlay controls (app bar and metadata)
                if (_showOverlay) ...[
                  // Top app bar
                  _TopOverlay(
                    item: currentItem,
                    currentIndex: currentIndex,
                    totalCount: mediaList.length,
                    onClose: () => Navigator.of(context).pop(),
                    onShare: (anchor) =>
                        _shareCurrentPhoto(currentItem, anchor),
                    onWriteMetadata: () => _writeMetadataToPhoto(currentItem),
                    // The viewer is deliberately NOT popped first: leaving it
                    // on the stack is what lets Back return the user to the
                    // photo they launched from, with its page index, zoom and
                    // overlay toggles intact, rather than to the bare grid.
                    onGoToDive: widget.showGoToDive && currentDiveId != null
                        ? () => context.pushOrReturnTo('/dives/$currentDiveId')
                        : null,
                    hasEnrichment: enrichment?.depthMeters != null,
                    showPerdixToggle: perdixToggleAvailable,
                    perdixEnabled: settings.perdixOverlayEnabled,
                    onTogglePerdix: () => ref
                        .read(settingsProvider.notifier)
                        .setPerdixOverlayEnabled(
                          !settings.perdixOverlayEnabled,
                        ),
                    onOpenInLightroom: _lightroomWebUrl(currentItem) == null
                        ? null
                        : () => unawaited(
                            launchUrl(
                              Uri.parse(_lightroomWebUrl(currentItem)!),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                  ),

                  // Previous / next controls. Mounted with the rest of the
                  // chrome, so the tap-to-hide gesture takes them away too.
                  MediaNavArrows(
                    currentIndex: currentIndex,
                    totalCount: mediaList.length,
                    onPrevious: () => _stepPage(-1),
                    onNext: () => _stepPage(1),
                  ),

                  // Mini dive profile overlay (lower right)
                  if (diveProfile != null &&
                      diveProfile.isNotEmpty &&
                      positioned)
                    PositionedMiniProfileOverlay(
                      profile: diveProfile,
                      photoElapsedSeconds: enrichment.elapsedSeconds!,
                      photoDepthMeters: enrichment.depthMeters,
                      settings: settings,
                      visible: _showOverlay,
                    ),

                  // Bottom metadata
                  _BottomMetadataOverlay(
                    item: currentItem,
                    settings: settings,
                    profileLengthSeconds: profileLength,
                    // Pinning needs a profile to pin against; a dive with
                    // none has no moments to choose from.
                    onSetTime: diveProfile == null || diveProfile.isEmpty
                        ? null
                        : () => _setTimeInDive(
                            currentItem,
                            diveProfile,
                            settings,
                          ),
                    siteName: diveAsync.whenOrNull(
                      data: (dive) => dive?.site?.name,
                    ),
                  ),
                ],

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
                if (settings.perdixOverlayEnabled &&
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
                    settings: settings,
                    topReserve:
                        MediaQuery.paddingOf(context).top + _topChromeHeight,
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
              ],
            ),
          );

          // Keyboard nav has to wrap the whole viewer to see its key events.
          // Built as a local above rather than nested inline so the tree it
          // wraps stays where it is.
          return Focus(
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: viewer,
          );
        },
      ),
    );
  }

  /// The lightroom.adobe.com URL for a connector item, or null when the
  /// item is not Lightroom-linked or this device has no connected account
  /// (the catalog id lives only on the connected device).
  String? _lightroomWebUrl(MediaItem item) {
    // Lightroom "Open in Lightroom" action hidden pending Adobe review
    // (lightroomUiEnabled). Returning null here suppresses both the toolbar
    // button and the video-poster overlay, which are gated on this URL.
    if (!lightroomUiEnabled) return null;
    if (item.sourceType != MediaSourceType.serviceConnector ||
        item.remoteAssetId == null) {
      return null;
    }
    final catalogId = ref
        .watch(lightroomAccountProvider)
        .value
        ?.accountIdentifier;
    if (catalogId == null) return null;
    return LightroomApiClient.assetWebUrl(catalogId, item.remoteAssetId!);
  }

  Future<void> _shareCurrentPhoto(MediaItem item, Rect? anchor) async {
    // Shared resolve-and-share flow (also used by the library selection bar).
    await shareMediaItems(context, ref, [item], anchor: anchor);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _writeMetadataToPhoto(MediaItem item) async {
    final l10n = context.l10n;
    debugPrint('[MediaViewerPage] _writeMetadataToPhoto called');
    if (item.platformAssetId == null) {
      _showError(l10n.media_photoViewer_cannotWriteMetadata);
      return;
    }

    final settings = ref.read(settingsProvider);

    // Get dive site name for the metadata (items without a dive link have
    // no site to record).
    String? siteName;
    final itemDiveId = item.diveId;
    if (itemDiveId != null) {
      final diveAsync = ref.read(diveProvider(itemDiveId));
      if (diveAsync.hasValue && diveAsync.value != null) {
        siteName = diveAsync.value!.site?.name;
      }
    }

    // Show confirmation dialog
    debugPrint('[MediaViewerPage] Showing confirmation dialog...');
    final dialogResult = await showWriteMetadataDialog(
      context: context,
      item: item,
      settings: settings,
      siteName: siteName,
    );

    debugPrint(
      '[MediaViewerPage] Dialog result: confirmed=${dialogResult.confirmed}',
    );
    if (!dialogResult.confirmed || !mounted) return;

    // Show loading indicator. The navigator is captured up front so the
    // dialog can still be dismissed if this page is unmounted while the
    // write is in flight -- otherwise a non-dismissible barrier is stranded
    // over the whole app. `barrierDismissible: false` blocks barrier taps
    // only, so Android's Back button can still pop this dialog out from
    // under us; the flag keeps the dismissal from popping whatever route
    // happens to be on top instead.
    debugPrint('[MediaViewerPage] Showing loading dialog...');
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    var loadingDialogOpen = true;
    void dismissLoadingDialog() {
      if (!loadingDialogOpen) return;
      loadingDialogOpen = false;
      rootNavigator.pop();
    }

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      ).whenComplete(() => loadingDialogOpen = false),
    );
    debugPrint('[MediaViewerPage] Loading dialog shown, calling service...');

    try {
      final metadataService = MetadataWriteService();
      final metadata = DiveMediaMetadata.fromMediaItem(
        item,
        siteName: siteName,
      );
      final isVideo = item.mediaType == MediaType.video;

      debugPrint('[MediaViewerPage] Calling writeMetadata...');
      final success = await metadataService.writeMetadata(
        platformAssetId: item.platformAssetId!,
        metadata: metadata,
        isVideo: isVideo,
        keepOriginal: dialogResult.keepOriginal,
      );
      debugPrint('[MediaViewerPage] writeMetadata returned: $success');

      // Dismiss loading - use rootNavigator to match where showDialog placed the dialog
      debugPrint('[MediaViewerPage] Dismissing loading dialog...');
      dismissLoadingDialog();
      debugPrint('[MediaViewerPage] pop() completed');

      debugPrint('[MediaViewerPage] About to show success/error message...');
      if (success) {
        debugPrint('[MediaViewerPage] Calling _showSuccess...');
        _showSuccess(
          isVideo
              ? l10n.media_photoViewer_diveDataWrittenToVideo
              : l10n.media_photoViewer_diveDataWrittenToPhoto,
        );
        debugPrint('[MediaViewerPage] _showSuccess completed');

        // Invalidate the image cache so the photo reloads with updated metadata
        debugPrint('[MediaViewerPage] Invalidating asset provider...');
        ref.invalidate(resolvedFullResolutionProvider(item));
      } else {
        _showError(l10n.media_photoViewer_failedToWriteMetadata);
      }
      debugPrint(
        '[MediaViewerPage] _writeMetadataToPhoto completed successfully',
      );
    } on MetadataWriteException catch (e) {
      debugPrint('[MediaViewerPage] MetadataWriteException: ${e.message}');
      dismissLoadingDialog();
      // The service's messages are English-only; substitute a translation for
      // the codes we have one for and fall back to its text otherwise.
      _showError(
        e.code == metadataWriteLivePhotoUnsupportedCode
            ? l10n.media_writeMetadata_livePhotoUnsupported
            : e.message,
      );
    } catch (e) {
      debugPrint('[MediaViewerPage] Exception: $e');
      dismissLoadingDialog();
      _showError(
        l10n.media_photoViewer_failedToWriteMetadataError(e.toString()),
      );
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}

/// The photo/video gallery using PhotoView for zoom support on photos.
class _PhotoGallery extends ConsumerWidget {
  final List<MediaItem> mediaList;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final bool showOverlay;
  final VoidCallback onToggleOverlay;
  final ValueChanged<bool> onSetOverlay;
  final void Function(String mediaId, VideoPlayerController? controller)
  onVideoControllerChanged;
  final int currentIndex;

  const _PhotoGallery({
    required this.mediaList,
    required this.pageController,
    required this.onPageChanged,
    required this.showOverlay,
    required this.onToggleOverlay,
    required this.onSetOverlay,
    required this.onVideoControllerChanged,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      pageController: pageController,
      itemCount: mediaList.length,
      onPageChanged: onPageChanged,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      builder: (context, index) {
        final item = mediaList[index];

        // Videos use custom player, photos use PhotoView
        if (item.isVideo) {
          // Lightroom-linked videos are poster-only (the original is never
          // downloaded), so show the poster with an Open-in-Lightroom play
          // affordance instead of the local player, which would otherwise
          // fail with "video file not found".
          if (item.sourceType == MediaSourceType.serviceConnector) {
            return PhotoViewGalleryPageOptions.customChild(
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained,
              child: _ConnectorVideoItem(item: item),
            );
          }
          return PhotoViewGalleryPageOptions.customChild(
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained, // No zoom for videos
            child: _VideoItem(
              item: item,
              showOverlay: showOverlay,
              onSetOverlay: onSetOverlay,
              onControllerChanged: onVideoControllerChanged,
            ),
          );
        }

        return PhotoViewGalleryPageOptions.customChild(
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3.0,
          child: _PhotoItem(item: item),
        );
      },
      loadingBuilder: (context, event) =>
          const Center(child: CircularProgressIndicator(color: Colors.white54)),
    );
  }
}

/// Individual photo item that loads full-resolution image.
class _PhotoItem extends StatelessWidget {
  final MediaItem item;

  const _PhotoItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return MediaItemView(item: item, fit: BoxFit.contain);
  }
}

/// A Lightroom-linked video: the original is never downloaded (only a poster
/// rendition is stored), so this shows the poster with a play badge that
/// opens the video in Lightroom rather than attempting local playback.
class _ConnectorVideoItem extends ConsumerWidget {
  final MediaItem item;

  const _ConnectorVideoItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogId = ref
        .watch(lightroomAccountProvider)
        .value
        ?.accountIdentifier;
    final url = (catalogId != null && item.remoteAssetId != null)
        ? LightroomApiClient.assetWebUrl(catalogId, item.remoteAssetId!)
        : null;
    // Shared open action: drives both the pointer tap (GestureDetector) and the
    // semantic activation on the labeled play button so screen readers can
    // actually trigger it, not just announce it.
    final onOpen = url == null
        ? null
        : () => unawaited(
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Stack(
        alignment: Alignment.center,
        children: [
          MediaItemView(item: item, fit: BoxFit.contain),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: url != null,
                label: context.l10n.media_lightroom_openInLightroom,
                onTap: onOpen,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              if (url != null) ...[
                const SizedBox(height: 12),
                // Label already voiced by the Semantics button above.
                ExcludeSemantics(
                  child: Text(
                    context.l10n.media_lightroom_openInLightroom,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Video player item that loads and plays video files.
class _VideoItem extends ConsumerStatefulWidget {
  final MediaItem item;
  final bool showOverlay;
  final ValueChanged<bool> onSetOverlay;

  /// Reports the live controller (or null on dispose) so the page can drive
  /// page-level overlays from playback position.
  final void Function(String mediaId, VideoPlayerController? controller)
  onControllerChanged;

  const _VideoItem({
    required this.item,
    required this.showOverlay,
    required this.onSetOverlay,
    required this.onControllerChanged,
  });

  @override
  ConsumerState<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends ConsumerState<_VideoItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  /// Handle keyboard events for video playback
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _initializeVideo() async {
    // Held outside the try so a throw from initialize() can still dispose it:
    // `_controller` is only assigned after a successful init, so dispose()
    // cannot clean up a controller that never got that far, and each leak
    // orphans a native decoder/texture for the process lifetime.
    VideoPlayerController? pending;
    try {
      final path = await ref.read(resolvedFilePathProvider(widget.item).future);

      if (path == null) {
        setState(() {
          _error = 'videoFileNotFound';
          _isLoading = false;
        });
        return;
      }

      final controller = VideoPlayerController.file(File(path));
      pending = controller;
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _isLoading = false;
      });
      // Ownership has moved to _controller; dispose() owns it from here.
      pending = null;
      widget.onControllerChanged(widget.item.id, controller);
    } catch (e) {
      await pending?.dispose();
      if (mounted) {
        setState(() {
          _error = 'failedToLoadVideo';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      // Unregister before disposing so the page never holds a dead
      // controller; guarded by mounted on the page side.
      widget.onControllerChanged(widget.item.id, null);
    }
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;

    final wasPlaying = controller.value.isPlaying;

    setState(() {
      if (wasPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });

    // Sync overlay state with play state:
    // - Paused (wasPlaying=true, now paused) → show overlay (true)
    // - Playing (wasPlaying=false, now playing) → hide overlay (false)
    widget.onSetOverlay(wasPlaying);
  }

  String _resolveVideoError(BuildContext context, String errorKey) {
    switch (errorKey) {
      case 'videoNotLinked':
        return context.l10n.media_photoViewer_videoNotLinked;
      case 'videoFileNotFound':
        return context.l10n.media_photoViewer_videoFileNotFound;
      case 'failedToLoadVideo':
        return context.l10n.media_photoViewer_failedToLoadVideo;
      default:
        return errorKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(
              _resolveVideoError(context, _error!),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    // Request focus when video is ready to enable keyboard controls
    _focusNode.requestFocus();

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video player - tap anywhere on video to play/pause
          Semantics(
            button: true,
            label: context.l10n.media_photoViewer_playPauseVideoLabel,
            child: GestureDetector(
              onTap: _togglePlayPause,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),

          // Play/pause button overlay (center) - visual indicator only when paused
          if (!controller.value.isPlaying)
            IgnorePointer(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

          // Video controls overlay (bottom)
          if (widget.showOverlay)
            Positioned(
              left: 0,
              right: 0,
              bottom: 160, // Above the metadata overlay and mini profile
              child: _VideoControlsOverlay(controller: controller),
            ),
        ],
      ),
    );
  }
}

/// Video playback controls with tap-to-seek progress bar and time display.
///
/// Uses tap-to-seek instead of drag-to-seek to avoid gesture conflicts
/// with the PageView's horizontal swipe navigation.
class _VideoControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControlsOverlay({required this.controller});

  @override
  State<_VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<_VideoControlsOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoUpdate);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _seekToPosition(double tapX, double totalWidth) {
    if (totalWidth <= 0) return;

    final progress = (tapX / totalWidth).clamp(0.0, 1.0);
    final duration = widget.controller.value.duration;
    final newPosition = Duration(
      milliseconds: (progress * duration.inMilliseconds).toInt(),
    );
    widget.controller.seekTo(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Current time
          SizedBox(
            width: 48,
            child: Text(
              _formatDuration(position),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Tap-to-seek progress bar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Semantics(
                  label: context.l10n.media_photoViewer_seekVideoLabel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _seekToPosition(
                        details.localPosition.dx,
                        constraints.maxWidth,
                      );
                    },
                    child: SizedBox(
                      height: 40, // Larger touch target
                      child: Center(
                        child: Stack(
                          children: [
                            // Background track
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Progress track
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Thumb indicator
                            Positioned(
                              left: (constraints.maxWidth * progress) - 8,
                              top: -6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Total time
          SizedBox(
            width: 48,
            child: Text(
              _formatDuration(duration),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Height of [_TopOverlay]'s content below the status bar: its 8 px vertical
/// padding either side of a default 48 px [IconButton]. The Perdix overlay
/// reserves this band so the face can never sit on top of the toolbar's
/// buttons -- keep the two in step if the toolbar's padding changes.
const double _topChromeHeight = 64;

/// Top overlay with close button, page indicator, share, and write metadata.
class _TopOverlay extends StatelessWidget {
  final MediaItem item;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;
  final void Function(Rect? anchor) onShare;
  final VoidCallback onWriteMetadata;
  final bool hasEnrichment;

  /// Whether the Perdix overlay toggle is shown (media synced to a profile).
  final bool showPerdixToggle;

  /// Whether the Perdix overlay is currently enabled (tints the icon).
  final bool perdixEnabled;

  final VoidCallback onTogglePerdix;

  /// Non-null only for Lightroom-linked items on the connected device.
  final VoidCallback? onOpenInLightroom;

  /// Non-null when the viewer is cross-dive and the item has a dive link.
  final VoidCallback? onGoToDive;

  const _TopOverlay({
    required this.item,
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
    required this.onShare,
    required this.onWriteMetadata,
    required this.hasEnrichment,
    required this.showPerdixToggle,
    required this.perdixEnabled,
    required this.onTogglePerdix,
    this.onOpenInLightroom,
    this.onGoToDive,
  });

  @override
  Widget build(BuildContext context) {
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
                // Jump to the owning dive (cross-dive viewers only)
                if (onGoToDive != null)
                  IconButton(
                    icon: const Icon(Icons.scuba_diving, color: Colors.white),
                    tooltip: context.l10n.media_viewer_goToDive,
                    onPressed: onGoToDive,
                  ),
                // Write metadata button (only shown if photo has dive data)
                if (hasEnrichment)
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.white),
                    tooltip:
                        context.l10n.media_photoViewer_writeDiveDataTooltip,
                    onPressed: onWriteMetadata,
                  ),
                // Perdix dive computer overlay toggle (only when the media
                // can be synced to the dive profile)
                if (showPerdixToggle)
                  IconButton(
                    icon: Icon(
                      Icons.watch,
                      color: perdixEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                    ),
                    tooltip: context.l10n.media_perdixOverlay_toggleTooltip,
                    onPressed: onTogglePerdix,
                  ),
                if (onOpenInLightroom != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.white),
                    tooltip: context.l10n.media_lightroom_openInLightroom,
                    onPressed: onOpenInLightroom,
                  ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  tooltip: context.l10n.media_info_title,
                  onPressed: () => showMediaInfoSheet(context, item),
                ),
                // Builder so the iPad share popover anchors to this
                // button: findRenderObject from a Builder's context descends
                // to the IconButton rather than yielding the whole overlay.
                Builder(
                  builder: (buttonContext) => IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    tooltip: context.l10n.media_photoViewer_shareTooltip,
                    onPressed: () => onShare(shareAnchorFrom(buttonContext)),
                  ),
                ),
                MediaReuploadButton(item: item, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom overlay showing dive metadata for the current photo.
class _BottomMetadataOverlay extends StatelessWidget {
  final MediaItem item;
  final AppSettings settings;
  final String? siteName;

  /// Length of the dive's profile, for the dive-window tolerance.
  final int profileLengthSeconds;

  /// Opens the Set-time dialog (issue #1090); null when there is no profile
  /// to pin against, which also hides the affordance.
  final VoidCallback? onSetTime;

  const _BottomMetadataOverlay({
    required this.item,
    required this.settings,
    required this.profileLengthSeconds,
    this.onSetTime,
    this.siteName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Depth, temperature and the elapsed chip describe a moment in the
    // dive, so they only render for a position inside the dive window (or
    // pinned by the diver). Outside it the raw offset used to print as
    // `+1879:28`; now the chip says the time is unknown and offers the fix.
    final positioned =
        item.enrichment?.isWithinDiveWindow(profileLengthSeconds) ?? false;
    final enrichment = positioned ? item.enrichment : null;
    final formatter = UnitFormatter(settings);
    final timeFormat = DateFormat.jm();
    final dateFormat = DateFormat.yMMMd();

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
                // Site name
                if (siteName != null && siteName!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          siteName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                // Metadata row
                Row(
                  children: [
                    // Depth
                    if (enrichment?.depthMeters != null) ...[
                      _MetadataChip(
                        icon: Icons.arrow_downward,
                        value: formatter.formatDepth(
                          enrichment!.depthMeters,
                          decimals: 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // Temperature
                    if (enrichment?.temperatureCelsius != null) ...[
                      _MetadataChip(
                        icon: Icons.thermostat,
                        value: formatter.formatTemperature(
                          enrichment!.temperatureCelsius,
                          decimals: 0,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // Elapsed time: the diver's pin, the automatic
                    // position, or an explicit unknown for a linked item
                    // whose capture time fell outside the dive.
                    if (enrichment?.elapsedSeconds != null)
                      _MetadataChip(
                        icon: enrichment!.isManual
                            ? Icons.push_pin_outlined
                            : Icons.timer_outlined,
                        value: _formatElapsedTime(enrichment.elapsedSeconds!),
                        onTap: onSetTime,
                        tooltip: l10n.media_timeInDive_setAction,
                      )
                    else if (item.diveId != null && onSetTime != null)
                      _MetadataChip(
                        icon: Icons.timer_off_outlined,
                        value: l10n.media_timeInDive_unknown,
                        onTap: onSetTime,
                        tooltip: l10n.media_timeInDive_setAction,
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Timestamp row
                Row(
                  children: [
                    Text(
                      '${dateFormat.format(item.takenAt)} at ${timeFormat.format(item.takenAt)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),

                    // Confidence indicator. A manual position is the
                    // diver's own statement, not an estimate, so it gets
                    // the pin icon on the chip instead of a warning here.
                    if (enrichment != null &&
                        enrichment.matchConfidence != MatchConfidence.exact &&
                        enrichment.matchConfidence !=
                            MatchConfidence.interpolated &&
                        !enrichment.isManual) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          enrichment.matchConfidence.displayName,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `+3:00` into the dive, `-1:30` for a surface shot just before it; the
  /// formatter already carries the minus, so the plus is only for the rest.
  String _formatElapsedTime(int seconds) {
    final formatted = formatElapsedMmSs(seconds);
    return seconds < 0 ? formatted : '+$formatted';
  }
}

/// Small metadata chip with icon and value.
class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String value;

  /// Makes the chip an action (the elapsed chip opens the Set-time dialog).
  final VoidCallback? onTap;
  final String? tooltip;

  const _MetadataChip({
    required this.icon,
    required this.value,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    final tappable = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: row,
      ),
    );
    return tooltip == null
        ? tappable
        : Tooltip(message: tooltip!, child: tappable);
  }
}
