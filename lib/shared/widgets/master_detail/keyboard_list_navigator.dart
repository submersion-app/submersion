import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// The move policy every master list shares (#3065).
///
/// Beside a detail pane an Up or Down press opens the row it lands on, the
/// way a click does, so the pane follows the cursor. At phone width there is
/// no pane to follow, and while rows are being checked a move must not open
/// anything, so the press only [highlight]s and Enter opens. [canOpen] is
/// false while checking rows, or when the list has nowhere to open into.
void moveListCursor(
  BuildContext context, {
  required bool canOpen,
  required VoidCallback open,
  required VoidCallback highlight,
}) {
  if (canOpen && ResponsiveBreakpoints.isMasterDetail(context)) {
    open();
  } else {
    highlight();
  }
}

/// Gives a master list one keyboard cursor, shared with the mouse (#3065).
///
/// Without this the rows' own focus nodes were the only keyboard model: the
/// arrow keys walked focus from card to card through Flutter's directional
/// traversal, a cursor of their own that a click never moved; Enter tapped
/// whichever card held focus; Right walked focus out into the detail pane;
/// and Tab stopped on every card in turn.
///
/// Here the list is a single focus stop. Up and Down move one cursor through
/// [keys], starting from [currentKey] (the row a click opened or highlighted)
/// and reporting each move through [onMove]. Enter calls [onActivate]. Right
/// and Left go to [onExpand] and [onCollapse] for lists with collapsible
/// groups, and do nothing otherwise rather than letting focus wander off.
///
/// Rows go inside a [KeyboardListItem], which takes them out of the focus
/// order, gives the list focus and the cursor when one is clicked, scrolls a
/// newly reached row into view and draws the focus ring on the cursor's row.
class KeyboardListNavigator extends StatefulWidget {
  const KeyboardListNavigator({
    super.key,
    required this.keys,
    required this.currentKey,
    required this.onMove,
    required this.child,
    this.onActivate,
    this.onExpand,
    this.onCollapse,
  });

  /// The debug label of the list's focus node, for tests.
  static const focusDebugLabel = 'KeyboardListNavigator';

  /// Every row the cursor can rest on, in display order. Rows the diver cannot
  /// see (folded into a collapsed group) are left out.
  final List<String> keys;

  /// The row the list itself considers current: the open or highlighted one.
  /// A change here, from a click or from outside the list, moves the cursor.
  final String? currentKey;

  /// The cursor moved to a row by keyboard.
  final ValueChanged<String> onMove;

  /// Enter was pressed on the cursor's row.
  final ValueChanged<String>? onActivate;

  /// Right was pressed on the cursor's row.
  final ValueChanged<String>? onExpand;

  /// Left was pressed on the cursor's row. Returns the row the cursor moves to
  /// afterwards, typically the group header the row folded into, or null to
  /// leave it where it is.
  final String? Function(String key)? onCollapse;

  final Widget child;

  @override
  State<KeyboardListNavigator> createState() => _KeyboardListNavigatorState();
}

class _KeyboardListNavigatorState extends State<KeyboardListNavigator> {
  final FocusNode _focusNode = FocusNode(
    debugLabel: KeyboardListNavigator.focusDebugLabel,
  );

  /// Built rows by key, registered by their [KeyboardListItem]s.
  final Map<String, BuildContext> _rows = {};

  late String? _cursor = widget.currentKey;

  /// Keys reported through [KeyboardListNavigator.onMove], oldest first, that
  /// have not come back as the current key yet. A split view's selection
  /// travels through the router and lands a frame or two after the move, so
  /// fast presses can be ahead of it.
  ///
  /// A move that never comes back (a group header, or a list with nothing to
  /// highlight at phone width) expires after [_echoWindow], so a much later
  /// selection of that row from elsewhere is not mistaken for it. Times are
  /// frame timestamps, the clock a widget test's pump advances.
  final List<({String key, Duration at})> _unconfirmedMoves = [];

  /// How long a move's selection may take to come back.
  static const _echoWindow = Duration(seconds: 1);

  static Duration get _now =>
      SchedulerBinding.instance.currentSystemFrameTimeStamp;
  bool _hasFocus = false;
  FocusHighlightMode _highlightMode = FocusManager.instance.highlightMode;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void didUpdateWidget(KeyboardListNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.currentKey;
    if (current == oldWidget.currentKey) return;
    final now = _now;
    _unconfirmedMoves.removeWhere((move) => now - move.at > _echoWindow);
    final confirmed = current == null
        ? -1
        : _unconfirmedMoves.indexWhere((move) => move.key == current);
    if (confirmed < 0) {
      // A change from outside the keyboard: a click, or the app opening a row.
      _unconfirmedMoves.clear();
      _cursor = current;
      return;
    }
    // An earlier move catching up. Only once the latest one has landed is the
    // current key the cursor again; until then it would pull the cursor back.
    _unconfirmedMoves.removeRange(0, confirmed + 1);
    if (_unconfirmedMoves.isEmpty) _cursor = current;
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) {
    if (mounted) setState(() => _highlightMode = mode);
  }

  /// The cursor, or [KeyboardListNavigator.currentKey] when the cursor's row
  /// has gone (its group collapsed under it, or the list reloaded without it).
  String? get _effectiveCursor {
    final keys = widget.keys;
    if (_cursor != null && keys.contains(_cursor)) return _cursor;
    final current = widget.currentKey;
    if (current != null && keys.contains(current)) return current;
    return null;
  }

  static bool _anyModifierPressed() {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_anyModifierPressed()) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _step(-1);
      return KeyEventResult.handled;
    }
    // Left and Right are always swallowed: left to the default directional
    // traversal they move focus out of the list, into the detail pane.
    if (key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent) {
        final cursor = _effectiveCursor;
        if (cursor != null) widget.onExpand?.call(cursor);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) {
        final cursor = _effectiveCursor;
        final next = cursor == null ? null : widget.onCollapse?.call(cursor);
        if (next != null && next != cursor) _moveTo(next, forward: false);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final cursor = _effectiveCursor;
      if (cursor == null || widget.onActivate == null) {
        return KeyEventResult.ignored;
      }
      if (event is KeyDownEvent) widget.onActivate!(cursor);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _step(int delta) {
    final keys = widget.keys;
    if (keys.isEmpty) return;
    final cursor = _effectiveCursor;
    final String next;
    if (cursor == null) {
      next = delta > 0 ? keys.first : keys.last;
    } else {
      final index = keys.indexOf(cursor) + delta;
      if (index < 0 || index >= keys.length) return;
      next = keys[index];
    }
    _moveTo(next, forward: delta > 0);
  }

  void _moveTo(String key, {required bool forward}) {
    setState(() => _cursor = key);
    _unconfirmedMoves.add((key: key, at: _now));
    widget.onMove(key);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(key, forward: forward),
    );
  }

  /// Scrolls the cursor's row into view once it has settled.
  ///
  /// A neighbouring row is nearly always built already, inside the list's
  /// cache extent. One that is not (the cursor started from nothing and went
  /// to the far end, or the selection was set from elsewhere) has no context
  /// to scroll to. The first attempt jumps to where the row's share of the
  /// keys puts it; rows of uneven height can make that miss, so each later
  /// attempt steps a viewport towards the row, judged from the indices of
  /// the rows that did get built, until it registers or [_maxRevealAttempts]
  /// runs out.
  void _reveal(String key, {required bool forward, int attempt = 0}) {
    if (!mounted || _cursor != key) return;
    final row = _rows[key];
    if (row != null && row.mounted) {
      Scrollable.ensureVisible(
        row,
        duration: const Duration(milliseconds: 120),
        alignmentPolicy: forward
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
      return;
    }
    if (attempt >= _maxRevealAttempts) return;
    final keys = widget.keys;
    final index = keys.indexOf(key);
    final built = [
      for (final MapEntry(key: builtKey, value: context) in _rows.entries)
        if (context.mounted) (index: keys.indexOf(builtKey), context: context),
    ].where((r) => r.index >= 0).toList();
    if (built.isEmpty || index < 0) return;
    final position = Scrollable.of(built.first.context).position;

    final double target;
    if (attempt == 0) {
      final share = keys.length <= 1 ? 0.0 : index / (keys.length - 1);
      target = share * position.maxScrollExtent;
    } else {
      final firstBuilt = built.map((r) => r.index).reduce(math.min);
      final step = index < firstBuilt
          ? -position.viewportDimension
          : position.viewportDimension;
      target = position.pixels + step;
    }
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    // Pinned at an end with the row still missing: there is nowhere further
    // to look.
    if (attempt > 0 && clamped == position.pixels) return;
    position.jumpTo(clamped);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(key, forward: forward, attempt: attempt + 1),
    );
    WidgetsBinding.instance.scheduleFrame();
  }

  /// How many jumps a reveal may take to build an off-screen row. Each one is
  /// a viewport after the first estimate, which lands close on even lists.
  static const _maxRevealAttempts = 40;

  /// A pointer went down on [key]'s row: the list takes focus and the cursor
  /// moves there, so the arrows carry on from the click. The row's own tap
  /// does whatever opening or selecting it does; this only moves the cursor,
  /// which matters for rows a tap does not make current, like group headers.
  void _pointerDownOn(String key) {
    _focusNode.requestFocus();
    _unconfirmedMoves.clear();
    if (_cursor != key) setState(() => _cursor = key);
  }

  void _register(String key, BuildContext row) => _rows[key] = row;

  void _unregister(String key, BuildContext row) {
    if (identical(_rows[key], row)) _rows.remove(key);
  }

  @override
  Widget build(BuildContext context) {
    final showsRing =
        _hasFocus && _highlightMode == FocusHighlightMode.traditional;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      onFocusChange: (focused) {
        if (!focused) _unconfirmedMoves.clear();
        setState(() => _hasFocus = focused);
      },
      child: _KeyboardListScope(
        state: this,
        ringKey: showsRing ? _effectiveCursor : null,
        child: widget.child,
      ),
    );
  }
}

/// Tells rows which of them draws the focus ring. An [InheritedModel] keyed by
/// row, so a cursor move rebuilds the row losing the ring and the row gaining
/// it rather than every built row in the list.
class _KeyboardListScope extends InheritedModel<String> {
  const _KeyboardListScope({
    required this.state,
    required this.ringKey,
    required super.child,
  });

  final _KeyboardListNavigatorState state;

  /// The row drawing the focus ring, or null while the list is not focused
  /// from the keyboard.
  final String? ringKey;

  @override
  bool updateShouldNotify(_KeyboardListScope oldWidget) =>
      ringKey != oldWidget.ringKey || !identical(state, oldWidget.state);

  @override
  bool updateShouldNotifyDependent(
    _KeyboardListScope oldWidget,
    Set<String> dependencies,
  ) {
    if (!identical(state, oldWidget.state)) return true;
    return dependencies.contains(ringKey) ||
        dependencies.contains(oldWidget.ringKey);
  }
}

/// One row of a [KeyboardListNavigator].
///
/// Its contents keep their taps but lose their focus stops, and a pointer
/// down anywhere on the row hands focus to the list, so the arrow keys carry
/// on from a click. Outside a navigator it is a plain pass-through.
class KeyboardListItem extends StatefulWidget {
  const KeyboardListItem({
    super.key,
    required this.navigationKey,
    required this.child,
  });

  /// The row's entry in [KeyboardListNavigator.keys].
  final String navigationKey;

  final Widget child;

  @override
  State<KeyboardListItem> createState() => _KeyboardListItemState();
}

class _KeyboardListItemState extends State<KeyboardListItem> {
  _KeyboardListNavigatorState? _navigator;
  String? _registeredKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(KeyboardListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRegistration();
  }

  void _syncRegistration() {
    final navigator = context
        .getInheritedWidgetOfExactType<_KeyboardListScope>()
        ?.state;
    if (identical(navigator, _navigator) &&
        _registeredKey == widget.navigationKey) {
      return;
    }
    _unregister();
    _navigator = navigator;
    _registeredKey = widget.navigationKey;
    navigator?._register(widget.navigationKey, context);
  }

  void _unregister() {
    final key = _registeredKey;
    if (key != null) _navigator?._unregister(key, context);
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = InheritedModel.inheritFrom<_KeyboardListScope>(
      context,
      aspect: widget.navigationKey,
    );
    if (scope == null) return widget.child;
    final hasRing = scope.ringKey == widget.navigationKey;
    return Listener(
      onPointerDown: (_) => scope.state._pointerDownOn(widget.navigationKey),
      // Always a DecoratedBox, with only its decoration changing: a click
      // draws the ring while its tap is still in progress, and a box that
      // came and went with the ring would rebuild the row's contents and
      // lose that tap (#3208).
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: hasRing
            ? BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              )
            : const BoxDecoration(),
        child: ExcludeFocus(child: widget.child),
      ),
    );
  }
}
