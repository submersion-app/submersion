part of 'media_viewer_page.dart';

/// What the viewer's controls do: Pick white, a video moment, Set time,
/// the enrichment backfill, Lightroom and Share.
extension _ViewerActions on _MediaViewerPageState {
  /// "Pick white" answered by a tap at [at] on the page: the photo's pixels
  /// (with its correction off for a frame), or a paused video's frame drawn
  /// contain-fit in [box].
  Future<void> _pickWhiteAt(MediaItem item, Offset at, Size box) {
    if (!item.isVideo) return pickWhiteOnPhoto(item, at);
    final controller = _videoControllers[item.id];
    return pickWhiteWith(
      item,
      () async => controller == null
          ? null
          : sampleWhiteFromVideo(
              ref,
              item,
              controller.value.position,
              at,
              box,
              // The file the player has open (it plays from a file).
              playing: controller.dataSourceType == DataSourceType.file
                  ? Uri.parse(controller.dataSource).toFilePath()
                  : null,
            ),
    );
  }

  /// Enters "Pick white"; a video is paused first so the tap reads the
  /// frame on screen.
  void _startPickingWhite(MediaItem item) {
    // One tap-capturing mode at a time: Pick white leaves people tag mode
    // (issue #1745). The toolbar is hidden while Pick white waits, so tag
    // mode cannot be entered the other way round.
    if (!pickingWhite && taggingPeople) togglePeopleTagging();
    // Tapping Pick white again cancels it.
    if (!pickingWhite && item.isVideo) {
      unawaited(_videoControllers[item.id]?.pause());
    }
    togglePickWhite();
  }

  /// A video face tag's chip was tapped (issue #1745): pause on its frame,
  /// where the video item draws the tag's box. A video that cannot play
  /// here (no controller, or one that failed) has no frame to show, so the
  /// tap does nothing.
  void _showMoment(MediaItem item, MediaPersonTag tag) {
    final at = tag.videoPosition;
    final controller = _videoControllers[item.id];
    if (at == null || controller == null) return;
    final value = controller.value;
    if (!value.isInitialized || value.hasError) return;
    unawaited(controller.pause().then((_) => controller.seekTo(at)));
  }

  /// Opens the Set-time dialog for [item] and holds the diver's choice in
  /// the photo's sitting until Save (issues #1090, #4527).
  Future<void> _setTimeInDive(
    MediaItem item,
    List<DiveProfilePoint> profile,
  ) async {
    final pinner = ref.read(mediaTimePinnerProvider);
    // In a sitting the choice is held (issue #4527). Captured first: one
    // that ends while the dialog is open must not turn into a write.
    final sitting = photoSitting;
    final held = sitting != null && sitting.stored.item.id == item.id
        ? sitting
        : null;
    final automatic = pinner.automaticTimeFor(item);
    final choice = await showSetMediaTimeDialog(
      context,
      profile: profile,
      initialElapsedSeconds: setTimeSeedFor(
        item,
        profileLengthSeconds: MediaDiveWindow.profileLengthSeconds(profile),
      ),
      isPinned: item.manualElapsedSeconds != null,
      settings: ref.read(settingsProvider),
      automatic: automatic,
    );
    // A time is only ever held: a sitting that ended while the dialog was
    // open, or a device that cannot unlock, writes nothing.
    if (choice == null || !mounted || held == null) return;
    return holdTimeChoice(held, item.id, choice, automatic);
  }

  /// Computes and saves the missing [MediaEnrichment] rows for [diveId], the
  /// same idempotent backfill dive detail runs on open.
  ///
  /// Media linked from a local file gets a row but no enrichment, and until
  /// now only dive detail ever closed that gap: a photo could show its depth
  /// and profile marker there and nothing at all in the Media section.
  /// Where [item] was taken, for limiting marine life names to the species
  /// recorded there (issue #4668): its own position, else its dive's site,
  /// else where the dive's computer logged its entry.
  GeoPoint? _photoLocation(MediaItem item, Dive? dive) => mediaLocation(
    item,
    siteLocation: dive?.site?.location,
    entryLocation: dive?.entryLocation,
  );

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
}
