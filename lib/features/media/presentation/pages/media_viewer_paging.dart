part of 'media_viewer_page.dart';

/// Which items the viewer pages through, and stepping between them.
extension _ViewerPaging on _MediaViewerPageState {
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
}
