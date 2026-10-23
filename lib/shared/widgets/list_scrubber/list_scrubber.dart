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
  final List<ScrubberMarker> markers;
  final void Function(int slot) onScrubEnd;

  /// Shown as the current value in the panel, and keeps the scrubber
  /// visible, while the caller works toward a dropped slot.
  final String? busyLabel;

  /// Called after a frame in which the scrubber became active (hovered,
  /// dragged or busy) or idle again.
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

  @override
  State<ListScrubber> createState() => _ListScrubberState();
}

class _ListScrubberState extends State<ListScrubber> {
  static const _thumbHeight = ListScrubberHandle.height;
  static const _strip = 48.0;

  bool _scrolling = false;
  bool _hovering = false;
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

  /// The default fade, left unkeyed so a child that returns while its
  /// previous copy still fades out does not duplicate a key.
  static Widget _fade(Widget child, Animation<double> animation) =>
      FadeTransition(opacity: animation, child: child);

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
          _hovering = false;
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
        final slot =
            dragSlot ??
            (widget.busyLabel != null ? _lastSlot : null) ??
            slotForScroll(
              pixels: position.pixels,
              maxScrollExtent: position.maxScrollExtent,
              loadedSlotCount: widget.loadedSlotCount,
            );
        final thumbTop = trackForSlot(
          slot: math.min(slot, _maxSlot),
          trackExtent: trackExtent,
          slotCount: widget.slotCount,
        );
        final active =
            _hovering || dragSlot != null || widget.busyLabel != null;
        _noteActive(active);
        final visible = _scrolling || active;
        final thumbStyle = ListScrubberThumbStyle.resolve(
          context,
          ListScrubberThumbStyle.statesFor(
            active: active,
            dragging: dragSlot != null,
          ),
        );
        final highlight = widget.highlightSlot;
        final value =
            widget.busyLabel ??
            (dragSlot == null ? null : widget.labelFor(dragSlot));
        final panelWidth = ListScrubberPanel.widthFor(
          density: widget.density.isNotEmpty,
        );
        // Laid out once here; the panel takes the height from it.
        final valueSize = value == null
            ? null
            : ListScrubberPanel.labelSize(context, value);
        final bandWidth = valueSize == null
            ? ListScrubberPanel.width
            : ListScrubberPanel.bandWidthFor(
                valueSize.width,
                constraints.maxWidth,
              );

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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          transitionBuilder: _fade,
                          child: active
                              ? ListScrubberPanel(
                                  key: ListScrubber.panelKey,
                                  markers: widget.markers,
                                  slotCount: widget.slotCount,
                                  trackExtent: trackExtent,
                                  thumbHeight: _thumbHeight,
                                  thumbTop: thumbTop,
                                  currentLabel: value,
                                  currentLabelHeight: valueSize?.height,
                                  currentWidth: bandWidth,
                                  ticks: widget.highlightTicks,
                                  tickColor: widget.highlightTickColor,
                                  segments: widget.segments,
                                  contextTicks: widget.contextTicks,
                                  density: widget.density,
                                  thumbInset:
                                      thumbStyle.crossAxisMargin +
                                      thumbStyle.thickness,
                                )
                              : const SizedBox.shrink(),
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
              width: active ? panelWidth : _strip,
              child: MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                onEnter: (event) {
                  if (!event.down) setState(() => _hovering = true);
                },
                onHover: (_) {
                  if (!_hovering) setState(() => _hovering = true);
                },
                onExit: (_) {
                  if (_hovering) setState(() => _hovering = false);
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
    _dragTop = (_dragTop + dy).clamp(0.0, trackExtent);
    final slot = math.min(
      slotForTrack(
        dy: _dragTop,
        trackExtent: trackExtent,
        slotCount: widget.slotCount,
      ),
      _maxSlot,
    );
    if (slot != _dragSlot) setState(() => _dragSlot = slot);
    _follow(slot);
  }

  /// Scrolls the list to [slot] when it is a loaded row.
  void _follow(int slot) {
    final controller = widget.controller;
    if (slot >= widget.loadedSlotCount || !controller.hasClients) return;
    _followedSlot = slot;
    controller.jumpTo(
      scrollForSlot(
        slot: slot,
        maxScrollExtent: controller.position.maxScrollExtent,
        loadedSlotCount: widget.loadedSlotCount,
      ),
    );
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
    });
    _scheduleHide();
    widget.onScrubEnd(clamped);
  }
}
