part of 'media_viewer_page.dart';

/// The viewer's top bar, and the ways it leaves or steps through the
/// photo's lock (issue #4527).
extension _ViewerChrome on _MediaViewerPageState {
  /// Whether [item] has no stored row, or its read has not answered yet.
  bool _rowless(MediaItem item) =>
      noStoredRow(ref.watch(mediaByIdProvider(item.id)));

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
    required GeoPoint? location,
  }) {
    // Read in the viewer's build, as everything but the labels action is.
    final reuploadable = mediaReuploadAvailable(ref) && !_rowless(currentItem);
    return Consumer(
      // Its own Consumer: the labels action follows analysis as it runs, and
      // only the toolbar is rebuilt for it, not the whole viewer. Only that
      // action reads through it: the toolbar comes and goes with the
      // controls, so the other callbacks keep the viewer's context and ref,
      // which a callback still running after it has gone (Go to dive, past
      // the discard question) needs.
      builder: (toolbarContext, toolbarRef, _) {
        final labels = marineLifeLabelsAction(
          toolbarRef,
          currentItem,
          location,
          // An Analyse's notice waits for the viewer still on this page.
          showing: () => mounted && _currentIndex == currentIndex,
        );
        return MediaViewerToolbar(
          // Writing to the photo file is a whole-record operation (issue
          // #4527): it needs the unlock and a sitting with nothing unsaved.
          writeMetadataDisabledReason: _writeMetadataBlockedBy(context),
          item: currentItem,
          currentIndex: currentIndex,
          totalCount: totalCount,
          onClose: closeGuarded,
          onEnterFullscreen: enterFullscreen,
          onShowInfo: () => showMediaInfoSheet(
            context,
            currentItem,
            readOnly: photoLocked,
            sitting: photoSitting,
          ),
          // A photo held only in a dive's sitting has no row for the store to
          // take again until the dive is saved (issue #4527).
          onReupload: reuploadable
              ? (anchor) => showMediaReuploadMenu(anchor, ref, currentItem)
              : null,
          onShare: (anchor) => _shareCurrentPhoto(currentItem, anchor),
          onWriteMetadata: () => _writeMetadataToPhoto(currentItem),
          onTagSpecies: () {
            // Read at the tap: a sitting that ended since leaves nothing to
            // hold the tags in.
            final sitting = photoSitting;
            if (sitting == null) return;
            showMediaSpeciesSheet(context, currentItem, sitting: sitting);
          },
          onTagPeople: () => togglePeopleTagging(
            pauseVideo: _videoControllers[currentItem.id]?.pause,
          ),
          peopleTaggingActive: taggingPeople,
          onAdjustColor: () => openColorPanel(),
          onUnlock: !photoUnlocked && canUnlock(currentItem, storedPhoto)
              ? () => unlockPhoto(storedPhoto!)
              : null,
          writeControls: !photoLocked,
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
          onMarineLifeLabels: labels.onPressed,
          marineLifeLabelsOn: labels.on,
          marineLifeRing: labels.ring,
          marineLifeTone: labels.tone,
          marineLifeLabel: switch (labels.status) {
            final status? => labelsButtonLabel(toolbarContext.l10n, status),
            null => null,
          },
        );
      },
    );
  }

  /// What a tap on a photo does: a white point while one is being picked,
  /// else the label on the photo under it (issue #4825), else [toggle] the
  /// controls. The view is read now; [size] only for a white point: a tap
  /// can land once the tap layer has left the tree.
  GestureTapUpCallback _photoTapUp(
    MediaItem item,
    Size Function() size,
    VoidCallback toggle,
  ) {
    final viewId = View.of(context).viewId;
    return (details) {
      if (pickingWhite) {
        _pickWhiteAt(item, details.localPosition, size());
        return;
      }
      if (identificationLabelTap(viewId, details.globalPosition)) return;
      toggle();
    };
  }

  /// Steps [delta] photos; while unlocked, through the check, so the next
  /// photo opens locked.
  void _step(int delta) => unawaited(stepGuarded(delta, _stepPage));

  /// Keeps the pager on the sitting's photo when the list moves under it.
  void _followSittingTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _currentIndex = index;
      _navTargetIndex = index;
      // The page settling clears the tag selection, but the photo is the
      // same one: keep what the diver had selected on it.
      final selected = selectedPeopleTagId;
      _pageController.jumpToPage(index);
      restorePeopleSelection(selected);
    });
  }

  /// Why writing to the photo file cannot be used now, or null when it can.
  String? _writeMetadataBlockedBy(BuildContext context) {
    if (!editingOffered) return null;
    if (!photoUnlocked) return context.l10n.recordEdit_unlockToUseThis;
    if (photoEditController.isDirty) {
      return context.l10n.recordEdit_saveOrCancelFirst;
    }
    return null;
  }
}
