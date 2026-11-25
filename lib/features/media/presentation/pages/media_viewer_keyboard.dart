part of 'media_viewer_page.dart';

/// The viewer's keyboard handling, kept beside the page so the page stays
/// within the project's file size limit.
extension _ViewerKeyboard on _MediaViewerPageState {
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
}
