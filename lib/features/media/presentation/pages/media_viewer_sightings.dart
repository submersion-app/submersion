part of 'media_viewer_page.dart';

/// The species the viewer follows when a sighting row opened it (issue
/// #5084).
extension _ViewerSightings on _MediaViewerPageState {
  /// Starts [controller], [mediaId]'s new player, at the followed species'
  /// first sighting in it. A player the diver has already started or moved
  /// is left where it is: the lookup may land after a tap on play. Nothing
  /// without a followed species, or for a video with no timed sighting.
  Future<void> _seekToFirstSighting(
    String mediaId,
    VideoPlayerController controller,
  ) async {
    final speciesId = widget.focusSpeciesId;
    if (speciesId == null) return;
    final provider = videoSpeciesSightingsProvider((
      mediaId: mediaId,
      speciesId: speciesId,
    ));
    // Held while it resolves: nothing else may watch it yet, and an
    // auto-disposed provider would be released mid-read.
    final hold = ref.listenManual(provider, (_, _) {});
    try {
      final stretches = await ref.read(provider.future);
      if (!mounted || stretches.isEmpty) return;
      // Paged away (released) or replaced since.
      if (!identical(_videoControllers[mediaId], controller)) return;
      final value = controller.value;
      if (!value.isInitialized || value.hasError || value.isPlaying) return;
      if (diverMoved(controller)) return;
      if (value.position > const Duration(milliseconds: 250)) return;
      await controller.seekTo(Duration(milliseconds: stretches.first.startMs));
    } catch (e, stackTrace) {
      _log.warning(
        'Could not start video $mediaId at its sighting',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      hold.close();
    }
  }
}
