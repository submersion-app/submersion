part of 'media_viewer_page.dart';

/// The viewer's top bar, and the ways it leaves or steps through the
/// photo's lock (issue #4527).
extension _ViewerChrome on _MediaViewerPageState {
  Widget _toolbar(
    BuildContext context, {
    required MediaItem currentItem,
    required int currentIndex,
    required int totalCount,
    required String? currentDiveId,
    required MediaEnrichment? enrichment,
    required bool perdixToggleAvailable,
    required bool perdixEnabled,
    required PhotoRecord? storedPhoto,
  }) => MediaViewerToolbar(
    item: currentItem,
    currentIndex: currentIndex,
    totalCount: totalCount,
    onClose: _close,
    onEnterFullscreen: enterFullscreen,
    onShowInfo: () => showMediaInfoSheet(
      context,
      currentItem,
      readOnly: editingOffered && !photoUnlocked,
      sitting: photoSitting,
    ),
    onReupload: mediaReuploadAvailable(ref)
        ? (anchor) => showMediaReuploadMenu(anchor, ref, currentItem)
        : null,
    onShare: (anchor) => _shareCurrentPhoto(currentItem, anchor),
    onWriteMetadata: () => _writeMetadataToPhoto(currentItem),
    onTagSpecies: () =>
        showMediaSpeciesSheet(context, currentItem, sitting: photoSitting),
    onTagPeople: () => togglePeopleTagging(
      pauseVideo: _videoControllers[currentItem.id]?.pause,
    ),
    peopleTaggingActive: taggingPeople,
    onAdjustColor: () => openColorPanel(),
    onUnlock: !photoUnlocked && canUnlock(currentItem, storedPhoto)
        ? () => unlockPhoto(storedPhoto!)
        : null,
    writeControls: !editingOffered || photoUnlocked,
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
    // The viewer is deliberately NOT popped first: leaving it
    // on the stack is what lets Back return the user to the
    // photo they launched from, with its page index, zoom and
    // overlay toggles intact, rather than to the bare grid.
    onGoToDive: widget.showGoToDive && currentDiveId != null
        ? () => unawaited(() async {
            // Following the link replaces the viewer, so a
            // sitting is asked about first.
            if (await leaveGuarded() && context.mounted) {
              context.pushOrReturnTo('/dives/$currentDiveId');
            }
          }())
        : null,
    canWriteMetadata:
        enrichment?.depthMeters != null &&
        _metadataWriter.canWriteTo(currentItem),
    showPerdixToggle: perdixToggleAvailable,
    perdixEnabled: perdixEnabled,
    onTogglePerdix: () => ref
        .read(settingsProvider.notifier)
        .setPerdixOverlayEnabled(!perdixEnabled),
    onOpenInLightroom: _lightroomWebUrl(currentItem) == null
        ? null
        : () => unawaited(
            launchUrl(
              Uri.parse(_lightroomWebUrl(currentItem)!),
              mode: LaunchMode.externalApplication,
            ),
          ),
  );

  /// Steps [delta] photos; while unlocked, through the check, so the next
  /// photo opens locked.
  void _step(int delta) {
    if (!editingOffered) return _stepPage(delta);
    unawaited(stepGuarded(() => _stepPage(delta)));
  }

  /// Closes the viewer; while unlocked, through the check, as the close
  /// button and the swipe down pop past the leave guard.
  void _close() {
    if (!editingOffered) return Navigator.of(context).pop();
    unawaited(() async {
      if (await leaveGuarded() && mounted) Navigator.of(context).pop();
    }());
  }

  /// Keeps the pager on the sitting's photo when the list moves under it.
  void _followSittingTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _currentIndex = index;
      _navTargetIndex = index;
      _pageController.jumpToPage(index);
    });
  }
}
