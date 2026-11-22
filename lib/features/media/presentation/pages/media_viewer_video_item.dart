part of 'media_viewer_page.dart';

/// Releases [controller] without waiting on it, logging a failure rather
/// than leaving it unhandled. Never awaited: a controller whose platform
/// create() threw (no player on this platform, #3548) never finishes
/// creating, and its dispose() waits on that forever.
void _releaseController(VideoPlayerController controller, String mediaId) {
  unawaited(
    controller.dispose().catchError((Object e) {
      _log.warning('Video $mediaId release failed', error: e);
    }),
  );
}

/// Video player item that loads and plays video files.
class _VideoItem extends ConsumerStatefulWidget {
  final MediaItem item;

  /// Whether this is the page on screen. The pager keeps each neighbour
  /// built so it loads ahead of a swipe (#3298), so a video can be mounted
  /// while off screen: it must neither keep playing nor hold keyboard focus.
  final bool isCurrent;
  final bool showOverlay;

  /// The viewer's fullscreen mode: the centre play indicator follows the
  /// controls' visibility, and this page draws the controls bar at the
  /// bottom edge. Outside it the bar is the top row of the viewer's bottom
  /// panel (issue #4762).
  final bool fullscreen;
  final ValueChanged<bool> onSetOverlay;

  /// The controls bar asks for the controls to be held up (a scrub, or the
  /// mouse on it), or lets them go.
  final void Function(VideoPlayerController video, bool held) onHoldChanged;

  /// Reports the live controller (or null on dispose) so the page can drive
  /// page-level overlays from playback position.
  final void Function(String mediaId, VideoPlayerController? controller)
  onControllerChanged;

  /// The viewer's sound: this page's player plays at it and follows each
  /// change, and M toggles it (issue #4817).
  final ViewerAudio audio;

  /// The viewer's people tag mode (issue #1745).
  final PeopleTagSession people;

  /// Whether the fish labels take taps, and whether they are hidden (issue
  /// #4675).
  final bool identificationsEditable;
  final bool hideIdentifications;

  /// How far up from the bottom the viewer's panel and its scrub bar reach
  /// outside fullscreen; the fish labels keep above it (issue #4762).
  final double controlsInset;

  const _VideoItem({
    required this.item,
    required this.isCurrent,
    required this.showOverlay,
    this.fullscreen = false,
    required this.onSetOverlay,
    required this.onHoldChanged,
    required this.onControllerChanged,
    required this.audio,
    required this.people,
    this.identificationsEditable = true,
    this.hideIdentifications = false,
    this.controlsInset = 0,
  });

  @override
  ConsumerState<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends ConsumerState<_VideoItem> {
  VideoPlayerController? _controller;

  /// The file [_controller] plays, for the colour track's frames; null
  /// for a video streamed from the media store in a browser.
  String? _playbackPath;

  /// The item the player resolved its playback for. Held while the video
  /// is on screen, so the fish scan reads this same resolution rather than
  /// fetching a file of its own (issue #4675).
  MediaItem? _resolvedFor;

  /// Opens [_controller] and, for a streamed video, reopens it once when
  /// its link goes stale (issue #4162). Disposed with the load it belongs
  /// to, which also ends a reopen still in flight.
  VideoPlaybackOpener? _opener;

  /// Whether this page has taken keyboard focus since it became current.
  bool _focusTaken = false;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;
  final FocusNode _focusNode = FocusNode();

  /// Bumped whenever a load starts or the page leaves the screen, so a load
  /// that finishes after its page moved on knows to release its player.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.audio.addListener(_applyAudio);
    // A neighbour built ahead holds no native player: only the page on
    // screen gets a decoder and texture, as before neighbours stayed built
    // (#1175 is the memory budget this protects).
    if (widget.isCurrent) _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant _VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // One sound for the viewer's whole life: the page owns it, so the
    // listener added in initState stays on the right one.
    assert(
      identical(oldWidget.audio, widget.audio),
      'a video page keeps the ViewerAudio it was built with',
    );
    if (!oldWidget.isCurrent && widget.isCurrent) {
      _initializeVideo();
    } else if (oldWidget.isCurrent && !widget.isCurrent) {
      _release();
    }
  }

  /// Swiped away: release the player, which also stops playback, rather
  /// than keep it one page off screen. Keyboard focus goes back too: a swipe
  /// on to a photo requests none, so the space bar would otherwise still
  /// reach this page. The previously focused node is the viewer's own, which
  /// keeps the arrow keys working.
  void _release() {
    _loadGeneration++;
    _focusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    final controller = _controller;
    // Plain assignments: didUpdateWidget is always followed by a build.
    _controller = null;
    _isInitialized = false;
    _isLoading = true;
    _error = null;
    _opener?.dispose();
    _opener = null;
    if (controller == null) return;
    widget.onControllerChanged(widget.item.id, null);
    _releaseController(controller, widget.item.id);
  }

  /// Gives the live player the viewer's sound: after the sound changes, and
  /// when a player is handed over. The opener sets it before any play; this
  /// catches a change made while the player was still being readied.
  void _applyAudio() {
    final controller = _controller;
    if (controller == null ||
        controller.value.volume == widget.audio.effectiveVolume) {
      return;
    }
    unawaited(
      widget.audio.applyTo(controller).catchError((Object e) {
        _log.warning('Video ${widget.item.id} volume change failed', error: e);
      }),
    );
  }

  /// Handle keyboard events for video playback
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // M mutes or unmutes, in tag mode too: it does not move the frame. A
    // chord with Ctrl, Cmd or Alt is some other shortcut's to take.
    final keyboard = HardwareKeyboard.instance;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyM &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isAltPressed) {
      widget.audio.toggleMute();
      return KeyEventResult.handled;
    }
    // In people tag mode the video stays on the frame its boxes are drawn
    // on (issue #1745), so Space does not play it.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        !widget.people.active) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _initializeVideo() async {
    final generation = ++_loadGeneration;
    // Gone, or swiped away and released while this load was in flight.
    bool stale() => !mounted || generation != _loadGeneration;
    final mediaId = widget.item.id;
    _resolvedFor = widget.item;
    try {
      final playback = await ref.read(
        videoPlaybackProvider(widget.item).future,
      );
      if (stale()) return;
      if (playback is NoPlayback) {
        setState(() {
          _error = playback.reason == NoPlaybackReason.needsNormalWindow
              ? 'videoNeedsNormalWindow'
              : 'videoFileNotFound';
          _isLoading = false;
        });
        return;
      }
      _playbackPath = playback is FilePlayback ? playback.path : null;
      // The opener releases every player that fails to start, so a throw
      // below leaves no native decoder or texture behind.
      final opener = VideoPlaybackOpener(
        playback,
        release: (controller) => _releaseController(controller, mediaId),
        // Read at each open, a reopen included: never a moment of sound
        // while the viewer is muted.
        volume: () => widget.audio.effectiveVolume,
      );
      final controller = await opener.open();

      if (stale()) {
        _releaseController(controller, mediaId);
        opener.dispose();
        return;
      }

      _opener?.dispose();
      _opener = opener;
      setState(() {
        _controller = controller;
        _isInitialized = true;
        _isLoading = false;
      });
      // As for a reopen: any toggle since the opener set its volume.
      _applyAudio();
      // Ownership has moved to _controller; dispose() owns it from here.
      widget.onControllerChanged(mediaId, controller);
      opener.watch(controller, onReplaced: _onReplaced);
    } catch (e, stackTrace) {
      _log.warning(
        'Video $mediaId failed to load',
        error: e,
        stackTrace: stackTrace,
      );
      if (!stale()) {
        setState(() {
          _error = 'failedToLoadVideo';
          _isLoading = false;
        });
      }
    }
  }

  /// A streamed player failed after it started (an expired link, a relay
  /// that lost its page) and the opener reopened it: [next] plays on where
  /// the failed one was, or is null when nothing more could be opened. The
  /// opener releases the failed player once this returns.
  void _onReplaced(VideoPlayerController? next) {
    final mediaId = widget.item.id;
    // Unregistered before the opener disposes it, as in dispose().
    widget.onControllerChanged(mediaId, null);
    if (next == null) {
      _log.warning('Video $mediaId failed and could not be reopened');
      setState(() {
        _controller = null;
        _isInitialized = false;
        _error = 'failedToLoadVideo';
      });
      return;
    }
    setState(() => _controller = next);
    // It took the viewer's sound when it opened; a toggle since, while it
    // seeked and resumed, reached only the failed player.
    _applyAudio();
    widget.onControllerChanged(mediaId, next);
  }

  @override
  void dispose() {
    widget.audio.removeListener(_applyAudio);
    final controller = _controller;
    _opener?.dispose();
    if (controller != null) {
      // Unregister before disposing so the page never holds a dead
      // controller; guarded by mounted on the page side.
      widget.onControllerChanged(widget.item.id, null);
      _releaseController(controller, widget.item.id);
    }
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
      case 'videoNeedsNormalWindow':
        return context.l10n.media_photoViewer_videoNeedsNormalWindow;
      case 'failedToLoadVideo':
        return context.l10n.media_photoViewer_failedToLoadVideo;
      default:
        return errorKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedFor;
    if (widget.isCurrent && resolved != null) {
      ref.listen(videoPlaybackProvider(resolved), (_, _) {});
    }
    // A neighbour built ahead never starts loading, so it would spin forever,
    // and an indeterminate indicator one page off screen keeps scheduling
    // frames. The black gallery behind it is all there is to see.
    if (!widget.isCurrent && _controller == null) {
      return const SizedBox.expand();
    }

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

    // Request focus when video is ready to enable keyboard controls. Only on
    // screen: a neighbour built ahead would otherwise take the space bar.
    // Once per arrival on screen, not on every rebuild: a save from the
    // Adjust color panel rebuilds this page, and taking focus back then
    // would leave the slider's next arrow key turning the page (#3520).
    if (!widget.isCurrent) {
      _focusTaken = false;
    } else if (!_focusTaken) {
      _focusTaken = true;
      _focusNode.requestFocus();
    }

    // Fullscreen draws its bar here, at the bottom edge; elsewhere the bar
    // is the top row of the viewer's bottom panel (issue #4762). Not in
    // tag mode: the video stays on the frame its boxes are drawn on.
    final barBottom = MediaQuery.paddingOf(context).bottom + 24;
    final showBar =
        widget.fullscreen && widget.showOverlay && !widget.people.active;
    final controlsInset = widget.fullscreen
        ? (showBar ? barBottom + VideoControlsBar.height : 0.0)
        : widget.controlsInset;

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
                  child: VideoColorFilter(
                    // The live row, so a saved adjustment shows (#3520);
                    // in its sitting, the item as the sitting has it
                    // (issue #4527).
                    item: sittingIsOver(widget.people.sitting, widget.item.id)
                        ? widget.item
                        : ref.watch(mediaByIdProvider(widget.item.id)).value ??
                              widget.item,
                    player: controller,
                    path: _playbackPath,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          ),

          // People tags (issue #1745).
          VideoPeopleLayer(
            controller: controller,
            item: widget.item,
            people: widget.people,
            showOverlay: widget.showOverlay,
          ),

          // Name pills and dots on the fish (issue #4675). Out of tag mode
          // and white-point picking, which take the taps.
          if (marineLifeLabelsShown &&
              widget.isCurrent &&
              !widget.people.active &&
              !widget.hideIdentifications)
            Positioned.fill(
              child: VideoIdentificationLayer(
                playback: controller,
                item: widget.item,
                sitting: widget.people.sitting,
                editable: widget.identificationsEditable,
                bottomInset: controlsInset,
              ),
            ),

          // Tells the scan where the diver is watching (issue #4709), in tag
          // mode and white-point picking too: the scan follows the playhead
          // while the labels are hidden. Draws nothing. Keyed: the labels
          // just before it come and go, and a reporter rebuilt then would
          // forget what it reported.
          if (marineLifeIdEnabled && widget.isCurrent)
            Positioned(
              key: const ValueKey('video_playhead_reporter'),
              left: 0,
              top: 0,
              child: VideoPlayheadReporter(
                playback: controller,
                item: widget.item,
              ),
            ),

          // Play/pause button overlay (center) - visual indicator only when
          // paused. It follows the player itself: the player reports its
          // state on its own schedule, and nothing else rebuilds this page
          // when it does, so a read at build time could leave it stuck.
          if (!widget.fullscreen || widget.showOverlay)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) => value.isPlaying
                  ? const SizedBox.shrink()
                  : IgnorePointer(
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
            ),

          // Fullscreen's controls bar, at the bottom edge.
          if (showBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: barBottom,
              child: VideoControlsBar(
                controller: controller,
                mediaId: widget.item.id,
                audio: widget.audio,
                // The controls hide 3 s after a reveal: hold them up while
                // scrubbing or under the mouse, so the bar is not pulled from
                // under the pointer, then restart the clock only if the video
                // plays on.
                onHoldChanged: (held) => widget.onHoldChanged(controller, held),
              ),
            ),
        ],
      ),
    );
  }
}
