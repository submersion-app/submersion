part of 'media_viewer_page.dart';

/// Writing the dive's data into the photo file, and its messages.
extension _ViewerWriteMetadata on _MediaViewerPageState {
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
    // Only unlocked with nothing unsaved; the toolbar disables it otherwise.
    if (_writeMetadataBlockedBy(context) != null) return;
    final l10n = context.l10n;
    debugPrint('[MediaViewerPage] _writeMetadataToPhoto called');

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
    final confirmed = await showWriteMetadataDialog(
      context: context,
      item: item,
      settings: settings,
      siteName: siteName,
    );

    debugPrint('[MediaViewerPage] Dialog result: confirmed=$confirmed');
    if (!confirmed || !mounted) return;

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
      // The stored platformAssetId belongs to the device that linked the
      // photo. Sent as is from any other device, it names a different photo
      // or none. Resolved under the spinner: on a device that has not seen
      // this photo yet, it searches the gallery.
      final resolution = await ref
          .read(assetResolutionServiceProvider)
          .resolveAssetId(item);
      final assetId = resolution.localAssetId;
      if (resolution.status != ResolutionStatus.resolved || assetId == null) {
        dismissLoadingDialog();
        _showError(switch (resolution.status) {
          ResolutionStatus.accessDenied when resolution.limitedAccess =>
            l10n.media_unavailablePlaceholder_limitedAccess,
          ResolutionStatus.accessDenied =>
            l10n.media_unavailablePlaceholder_accessDenied,
          _ => l10n.media_photoViewer_cannotWriteMetadata,
        });
        return;
      }

      final metadata = DiveMediaMetadata.fromMediaItem(
        item,
        siteName: siteName,
      );
      final isVideo = item.mediaType == MediaType.video;

      debugPrint('[MediaViewerPage] Calling writeMetadata...');
      final success = await _metadataWriter.writeMetadata(
        platformAssetId: assetId,
        metadata: metadata,
        isVideo: isVideo,
      );
      debugPrint('[MediaViewerPage] writeMetadata returned: $success');

      // Dismiss loading - use rootNavigator to match where showDialog placed the dialog
      debugPrint('[MediaViewerPage] Dismissing loading dialog...');
      dismissLoadingDialog();
      debugPrint('[MediaViewerPage] pop() completed');

      debugPrint('[MediaViewerPage] About to show success/error message...');
      if (success) {
        debugPrint('[MediaViewerPage] Calling _showSuccess...');
        // Only photos get here: the service refuses a video before the
        // platform channel.
        _showSuccess(l10n.media_photoViewer_diveDataWrittenToPhoto);
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
      _showError(switch (e.code) {
        metadataWriteLivePhotoUnsupportedCode =>
          l10n.media_writeMetadata_livePhotoUnsupported,
        metadataWriteVideoUnsupportedCode =>
          l10n.media_writeMetadata_videoUnsupported,
        _ => e.message,
      });
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
