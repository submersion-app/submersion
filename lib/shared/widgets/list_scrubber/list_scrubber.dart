import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_panel.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_thumb_style.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

/// A draggable thumb over [child]'s end edge that scrubs through
/// [slotCount] positions, of which the first [loadedSlotCount] are rows
/// [child] already holds.
class ListScrubber extends StatefulWidget {
  const ListScrubber({
    super.key,
    required this.controller,
    required this.slotCount,
    required this.loadedSlotCount,
    required this.labelFor,
    required this.markers,
    required this.onScrubEnd,
    required this.child,
    this.detailFor,
    this.busyLabel,
    this.onActiveChanged,
    this.highlightSlot,
    this.highlightTicks = const [],
    this.highlightTickColor,
    this.segments = const [],
    this.contextTicks = const [],
    this.density = const [],
  });

  final ScrollController controller;
  final int slotCount;
  final int loadedSlotCount;
  final String Function(int slot) labelFor;

  /// A second line under the dragged slot's label, or null for none.
  final String? Function(int slot)? detailFor;
  final List<ScrubberMarker> markers;
  final void Function(int slot) onScrubEnd;

  /// Shown as the current value in the panel, and keeps the scrubber
  /// visible, while the caller works toward a dropped slot.
  final String? busyLabel;

  /// Called after a frame in which the scrubber became active (its thumb
  /// hovered, dragged or busy) or idle again.
  final ValueChanged<bool>? onActiveChanged;

  /// The slot of the item the caller shows as selected, marked with a dot.
  final int? highlightSlot;

  /// Slots marked with a short tick beside the thumb track while active,
  /// in slot order.
  final List<int> highlightTicks;

  /// The ticks' colour; `primary` when null.
  final Color? highlightTickColor;

  /// Stripes in the panel's context column while active, in slot order.
  final List<ScrubberSegment> segments;

  /// Ticks in the panel's context column while active, in slot order.
  final List<ScrubberTick> contextTicks;

  /// Item counts along the track, drawn as bars in their own column of the
  /// panel while active, in slot order.
  final List<ScrubberDensityBin> density;
  final Widget child;

  static const thumbKey = ValueKey('listScrubber.thumb');
  static const currentValueKey = ListScrubberPanel.currentValueKey;
  static const currentMarkerKey = ListScrubberPanel.currentMarkerKey;
  static const currentBandKey = ListScrubberPanel.currentBandKey;
  static const panelKey = ValueKey('listScrubber.panel');
  static const highlightKey = ValueKey('listScrubber.highlight');
  static const idleHide = Duration(milliseconds: 1500);

  /// How long the panel takes to fade in or out.
  static const reveal = Duration(milliseconds: 250);

  /// The column at the end edge where a hover shows the thumb, and the
  /// thumb's hover target within it; wider when the themed thumb is.
  static const gripWidth = 16.0;

  @override
  State<ListScrubber> createState() => _ListScrubberState();
}

class _ListScrubberState extends State<ListScrubber> {
  static const _thumbHeight = ListScrubberHandle.height;
  static const _strip = 48.0;

  bool _scrolling = false;

  /// The pointer reached the thumb; the panel stays open while it is over
  /// the hover region.
  bool _hovering = false;

  /// The pointer is over the end edge's column, which shows the thumb.
  bool _edgeHover = false;

  /// A mouse is over the hover region, button held or not, so a drag that
  /// ends there leaves the panel open.
  bool _inside = false;

  /// The edge column's width: [ListScrubber.gripWidth], or the themed
  /// thumb's when that is wider.
  double _grip = ListScrubber.gripWidth;

  /// How far in from the end edge the drawn thumb reaches: its margin plus
  /// its thickness. Only a hover this close to the edge opens the panel.
  double _thumbReach = ListScrubber.gripWidth;

  /// Where the thumb and the hover region were last laid out, for placing a
  /// hover against them.
  double _thumbTop = 0;
  double _regionWidth = _strip;

  List<ScrubberMarker>? _columnMarkers;
  double? _columnInset;
  TextScaler? _columnScaler;
  TextStyle? _columnStyle;
  double _column = ListScrubberPanel.width;
  String? _bandValue;
  String? _bandDetail;
  double? _bandHost;
  double? _bandPanel;
  ThemeData? _bandTheme;
  TextDirection? _bandDirection;
  TextScaler? _bandScaler;
  Size? _band;
  int? _dragSlot;
  int? _lastSlot;

  /// The slot the drag last scrolled the list to, or found it showing.
  int? _followedSlot;
  double _dragTop = 0;
  Timer? _hideTimer;
  bool _active = false;
  bool _reportedActive = false;
  bool _reportPending = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ListScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    if (oldWidget.busyLabel != null && widget.busyLabel == null) {
      _scheduleHide();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_dragSlot != null || !mounted) return;
    _scrolling = true;
    _scheduleHide();
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(ListScrubber.idleHide, () {
      if (mounted) setState(() => _scrolling = false);
    });
  }

  int get _maxSlot => math.max(0, widget.slotCount - 1);

  void _noteActive(bool active) {
    if (active == _active) return;
    _active = active;
    if (widget.onActiveChanged == null || _reportPending) return;
    _reportPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportPending = false;
      if (!mounted || _active == _reportedActive) return;
      _reportedActive = _active;
      widget.onActiveChanged?.call(_active);
    });
  }

  /// The label column for the markers beside a thumb [inset] wide, measured
  /// again only when they or the text style change.
  double _labelColumn(BuildContext context, double inset) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = ListScrubberPanel.markerStyle(Theme.of(context));
    if (!identical(_columnMarkers, widget.markers) ||
        _columnInset != inset ||
        _columnScaler != scaler ||
        _columnStyle != style) {
      _columnMarkers = widget.markers;
      _columnInset = inset;
      _columnScaler = scaler;
      _columnStyle = style;
      _column = ListScrubberPanel.labelColumnFor(
        context,
        widget.markers,
        thumbInset: inset,
      );
    }
    return _column;
  }

  /// The current band for [value] and [detail], laid out again only when
  /// they or what sizes them change, not on every pixel of a drag.
  Size _bandFor(
    BuildContext context, {
    required String value,
    required String? detail,
    required double hostWidth,
    required double panelWidth,
  }) {
    final theme = Theme.of(context);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    if (_band == null ||
        _bandValue != value ||
        _bandDetail != detail ||
        _bandHost != hostWidth ||
        _bandPanel != panelWidth ||
        !identical(_bandTheme, theme) ||
        _bandDirection != direction ||
        _bandScaler != scaler) {
      _bandValue = value;
      _bandDetail = detail;
      _bandHost = hostWidth;
      _bandPanel = panelWidth;
      _bandTheme = theme;
      _bandDirection = direction;
      _bandScaler = scaler;
      _band = ListScrubberPanel.bandSize(
        context,
        value: value,
        detail: detail,
        hostWidth: hostWidth,
        panelWidth: panelWidth,
      );
    }
    return _band!;
  }

  /// Tracks a hover over the region: the end edge's column shows the thumb,
  /// and the drawn thumb itself (or the margin between it and the edge)
  /// opens the panel, which then stays open until the
  /// pointer leaves the region.
  void _hover(PointerEvent event) {
    _inside = true;
    if (event.down) return;
    final x = event.localPosition.dx;
    final fromEnd = Directionality.of(context) == TextDirection.rtl
        ? x
        : _regionWidth - x;
    final edge = fromEnd <= _grip;
    final y = event.localPosition.dy;
    final onThumb =
        fromEnd <= _thumbReach &&
        y >= _thumbTop &&
        y <= _thumbTop + _thumbHeight;
    final hovering = _hovering || onThumb;
    if (hovering == _hovering && edge == _edgeHover) return;
    setState(() {
      _hovering = hovering;
      _edgeHover = edge;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scrollBehavior = ScrollConfiguration.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final ScrollPosition? position = controller.hasClients
            ? controller.position
            : null;
        final wanted =
            position != null &&
            position.hasContentDimensions &&
            scrubberWanted(
              slotCount: widget.slotCount,
              loadedSlotCount: widget.loadedSlotCount,
              maxScrollExtent: position.maxScrollExtent,
              viewportDimension: position.viewportDimension,
            );
        if (!wanted) {
          // The region unmounts without an exit.
          _hovering = false;
          _edgeHover = false;
          _inside = false;
          _noteActive(false);
          if (_dragSlot != null) {
            _dragSlot = null;
            _scrolling = false;
            _hideTimer?.cancel();
          }
          if (position == null || !position.hasContentDimensions) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && controller.hasClients) setState(() {});
            });
          }
          return Stack(
            fit: StackFit.passthrough,
            children: [
              ScrollConfiguration(
                behavior: scrollBehavior,
                child: widget.child,
              ),
            ],
          );
        }

        final trackExtent = math.max(0.0, constraints.maxHeight - _thumbHeight);
        final dragSlot = _dragSlot == null
            ? null
            : math.min(_dragSlot!, _maxSlot);
        final busySlot = widget.busyLabel != null ? _lastSlot : null;
        // Between slots, so the thumb follows every pixel of scrolling.
        final scrolled = slotPositionForScroll(
          pixels: position.pixels,
          maxScrollExtent: position.maxScrollExtent,
          loadedSlotCount: widget.loadedSlotCount,
        );
        final slot = dragSlot ?? busySlot ?? scrolled.round();
        // A dragged thumb stays under the pointer.
        final thumbTop = dragSlot != null
            ? math.min(_dragTop, trackExtent)
            : trackForSlot(
                slot: math.min(busySlot ?? scrolled, _maxSlot),
                trackExtent: trackExtent,
                slotCount: widget.slotCount,
              );
        _thumbTop = thumbTop;
        final active =
            _hovering || dragSlot != null || widget.busyLabel != null;
        _noteActive(active);
        final visible = _scrolling || _edgeHover || active;
        final thumbStyle = ListScrubberThumbStyle.resolve(
          context,
          ListScrubberThumbStyle.statesFor(
            active: active,
            dragging: dragSlot != null,
          ),
        );
        // The column is sized for the hovered thumb, so it holds still
        // between hovering and dragging.
        final hoverStyle = ListScrubberThumbStyle.resolve(
          context,
          ListScrubberThumbStyle.statesFor(active: true, dragging: false),
        );
        final thumbInset = hoverStyle.crossAxisMargin + hoverStyle.thickness;
        _thumbReach = thumbInset;
        _grip = math.max(
          ListScrubber.gripWidth,
          hoverStyle.thickness + hoverStyle.crossAxisMargin * 2,
        );
        final labelColumn = _labelColumn(context, thumbInset);
        final highlight = widget.highlightSlot;
        final busy = widget.busyLabel;
        final value =
            busy ?? (dragSlot == null ? null : widget.labelFor(dragSlot));
        final detail = busy != null || dragSlot == null
            ? null
            : widget.detailFor?.call(dragSlot);
        final panelWidth = ListScrubberPanel.widthFor(
          labelColumn: labelColumn,
          density: widget.density.isNotEmpty,
        );
        // Laid out once here; the panel takes the height from it.
        final band = value == null
            ? null
            : _bandFor(
                context,
                value: value,
                detail: detail,
                hostWidth: constraints.maxWidth,
                panelWidth: panelWidth,
              );
        _regionWidth = active ? math.max(panelWidth, _strip) : _strip;

        return Stack(
          fit: StackFit.passthrough,
          children: [
            ScrollConfiguration(
              behavior: scrollBehavior.copyWith(scrollbars: false),
              child: widget.child,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        top: 0,
                        bottom: 0,
                        end: 0,
                        width: panelWidth,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: active ? 1 : 0),
                          duration: ListScrubber.reveal,
                          curve: Curves.easeOut,
                          builder: (context, reveal, _) =>
                              reveal == 0 && !active
                              ? const SizedBox.shrink()
                              : ListScrubberPanel(
                                  key: ListScrubber.panelKey,
                                  markers: widget.markers,
                                  slotCount: widget.slotCount,
                                  trackExtent: trackExtent,
                                  thumbHeight: _thumbHeight,
                                  thumbTop: thumbTop,
                                  currentLabel: value,
                                  currentDetail: detail,
                                  currentHeight: band?.height,
                                  currentWidth: band?.width ?? panelWidth,
                                  labelColumn: labelColumn,
                                  reveal: reveal,
                                  ticks: widget.highlightTicks,
                                  tickColor: widget.highlightTickColor,
                                  segments: widget.segments,
                                  contextTicks: widget.contextTicks,
                                  density: widget.density,
                                  thumbInset: thumbInset,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              width: _regionWidth,
              child: MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                onEnter: _hover,
                onHover: _hover,
                onExit: (_) {
                  _inside = false;
                  if (_hovering || _edgeHover) {
                    setState(() {
                      _hovering = false;
                      _edgeHover = false;
                    });
                  }
                  _scheduleHide();
                },
                child: ExcludeSemantics(
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        top: thumbTop,
                        end: 0,
                        child: IgnorePointer(
                          ignoring: !visible,
                          child: AnimatedOpacity(
                            opacity: visible ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              key: ListScrubber.thumbKey,
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragStart: (_) {
                                _hideTimer?.cancel();
                                _dragTop = thumbTop;
                                // A busy thumb rests on a dropped slot the
                                // list is not showing yet.
                                _followedSlot = widget.busyLabel == null
                                    ? slot
                                    : null;
                                setState(() => _dragSlot = slot);
                              },
                              onVerticalDragUpdate: (details) =>
                                  _dragTo(details.delta.dy, trackExtent),
                              onVerticalDragEnd: (_) => _endDrag(),
                              onVerticalDragCancel: _endDrag,
                              child: SizedBox(
                                width: _strip,
                                height: _thumbHeight,
                                child: Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      end: thumbStyle.crossAxisMargin,
                                    ),
                                    child: ListScrubberHandle(
                                      style: thumbStyle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (highlight != null && highlight < widget.slotCount)
              _highlightDot(
                thumbStyle,
                trackForSlot(
                  slot: highlight,
                  trackExtent: trackExtent,
                  slotCount: widget.slotCount,
                ),
                visible,
              ),
          ],
        );
      },
    );
  }

  /// A dot on the thumb's column at [track], drawn above the thumb.
  Widget _highlightDot(
    ListScrubberThumbStyle thumb,
    double track,
    bool visible,
  ) {
    const size = 6.0;
    return PositionedDirectional(
      top: track + _thumbHeight / 2 - size / 2,
      end: thumb.crossAxisMargin + thumb.thickness / 2 - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: DecoratedBox(
              key: ListScrubber.highlightKey,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _dragTo(double dy, double trackExtent) {
    final top = (_dragTop + dy).clamp(0.0, trackExtent);
    final position = slotPositionForTrack(
      dy: top,
      trackExtent: trackExtent,
      slotCount: widget.slotCount,
    );
    final slot = math.min(position.round(), _maxSlot);
    final target = _followTarget(position);
    // An update that would move neither the thumb nor the list, like one
    // past either end of the track, rebuilds nothing. Rows that loaded
    // under a held thumb change the target, so they are still followed.
    if (top == _dragTop &&
        slot == _dragSlot &&
        (target == null ||
            (target == widget.controller.offset && slot == _followedSlot))) {
      return;
    }
    _dragTop = top;
    // The thumb moves with every update, even within one slot.
    setState(() => _dragSlot = slot);
    _follow(position);
  }

  /// The scroll offset showing [position], which may fall between two
  /// slots, or null when it rounds past the loaded rows.
  double? _followTarget(num position) {
    final controller = widget.controller;
    if (position.round() >= widget.loadedSlotCount || !controller.hasClients) {
      return null;
    }
    return scrollForSlot(
      slot: position,
      maxScrollExtent: controller.position.maxScrollExtent,
      loadedSlotCount: widget.loadedSlotCount,
    );
  }

  /// Scrolls the list to [position] when it rounds to a loaded row.
  void _follow(num position) {
    final target = _followTarget(position);
    if (target == null) return;
    _followedSlot = position.round();
    widget.controller.jumpTo(target);
  }

  void _endDrag() {
    final slot = _dragSlot;
    if (slot == null) return;
    final clamped = math.min(slot, _maxSlot);
    // Rows that loaded while the thumb held still past them were never
    // scrolled to; a drop leaves the list showing the dropped row. The jump
    // waits a frame so the list's extent includes those rows.
    if (clamped != _followedSlot) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dragSlot == null) _follow(clamped);
      });
    }
    _followedSlot = null;
    setState(() {
      _dragSlot = null;
      _lastSlot = clamped;
      // A mouse released over the panel keeps it open, as a hover would.
      if (_inside) _hovering = true;
    });
    _scheduleHide();
    widget.onScrubEnd(clamped);
  }
}
