import 'package:flutter/widgets.dart';

/// Exposes the [ScrollController] that a [DetailScrollRetainer] owns to the
/// detail subtree below it.
///
/// A detail page opts into scroll retention by handing its primary scroll view
/// this controller:
///
/// ```dart
/// SingleChildScrollView(
///   controller: DetailScrollController.maybeOf(context),
///   ...
/// )
/// ```
///
/// When no retainer is present (e.g. the page is shown standalone on mobile),
/// [maybeOf] returns null and the scroll view falls back to its own internal
/// controller, so standalone behaviour is unchanged.
class DetailScrollController extends InheritedWidget {
  const DetailScrollController({
    super.key,
    required this.controller,
    required super.child,
  });

  /// The controller to attach to the detail's primary scroll view.
  final ScrollController controller;

  /// The nearest retainer's controller, or null if there is none.
  static ScrollController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DetailScrollController>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(DetailScrollController oldWidget) =>
      controller != oldWidget.controller;
}

/// Preserves a detail pane's scroll offset across item selections in a
/// master-detail layout.
///
/// Why this exists instead of a [PageStorageKey]: `Scrollable` auto-saves its
/// offset to [PageStorage] on *any* scroll-activity end, including the settle
/// that fires when a just-restored offset is clamped because the detail's
/// content has not finished loading its height yet. That clamped value gets
/// written back to the shared slot, ratcheting the saved offset down to zero
/// over a few selections. There is no PageStorage hook to distinguish a user
/// scroll from a transient clamp.
///
/// This retainer instead owns a controller with `keepScrollOffset: false` (so
/// PageStorage never runs), remembers the offset via [onOffsetChanged] (called
/// only for genuine user scrolls, never for its own restore jumps), and
/// re-applies [initialOffset] with a deferred, extent-guarded jump that waits
/// for the content to grow tall enough — so a still-loading viewport can never
/// corrupt the remembered value.
class DetailScrollRetainer extends StatefulWidget {
  const DetailScrollRetainer({
    super.key,
    required this.initialOffset,
    required this.onOffsetChanged,
    required this.child,
  });

  /// The offset to restore once the content can accommodate it. Read once, at
  /// mount; a fresh retainer is created per selection.
  final double initialOffset;

  /// Called with the latest user-driven scroll offset. The caller should store
  /// this without triggering a rebuild (it fires on every scroll update).
  final ValueChanged<double> onOffsetChanged;

  final Widget child;

  @override
  State<DetailScrollRetainer> createState() => _DetailScrollRetainerState();
}

class _DetailScrollRetainerState extends State<DetailScrollRetainer> {
  // keepScrollOffset:false keeps PageStorage entirely out of the loop.
  final ScrollController _controller = ScrollController(
    keepScrollOffset: false,
  );

  /// True while we are applying a restore jump, so the notification listener
  /// does not mistake our own jump for a user scroll.
  bool _restoring = false;

  static const double _epsilon = 0.5;
  static const int _maxAttempts = 120;
  static const int _maxStableFrames = 3;

  int _attempts = 0;
  int _stableFrames = 0;
  double _lastMax = -1;

  @override
  void initState() {
    super.initState();
    if (widget.initialOffset > _epsilon) {
      _scheduleRestore();
    }
  }

  /// Chase [DetailScrollRetainer.initialOffset] across frames: the content
  /// height may still be growing (async sections), so we jump to the best
  /// offset available now and re-check until the target is reachable or the
  /// content stops growing.
  void _scheduleRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_controller.hasClients) {
        if (_attempts++ < _maxAttempts) _scheduleRestore();
        return;
      }

      final double max = _controller.position.maxScrollExtent;
      final double desired = widget.initialOffset.clamp(0.0, max);
      if ((_controller.offset - desired).abs() > _epsilon) {
        _restoring = true;
        _controller.jumpTo(desired);
        _restoring = false;
      }

      final bool reachedTarget = max + _epsilon >= widget.initialOffset;
      if (reachedTarget) return;

      // Not yet reachable: keep polling while the content is still growing,
      // tolerating brief pauses, with a hard cap as a backstop.
      if (max > _lastMax + _epsilon) {
        _stableFrames = 0;
      } else {
        _stableFrames++;
      }
      _lastMax = max;
      if (_stableFrames < _maxStableFrames && _attempts++ < _maxAttempts) {
        _scheduleRestore();
      }
    });
  }

  bool _onNotification(ScrollNotification notification) {
    if (!_restoring &&
        (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification)) {
      widget.onOffsetChanged(notification.metrics.pixels);
    }
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: DetailScrollController(
        controller: _controller,
        child: widget.child,
      ),
    );
  }
}
