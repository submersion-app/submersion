import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_selection_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Draggable start/end handles for the profile chart's range statistics.
///
/// Rendered as a widget layer inside the chart's Stack (like the photo and
/// safety-finding overlays) so it shares the chart's plot rect and visible
/// time window. That is what keeps a handle on the same pixel as the depth
/// trace at its timestamp: positions come from the chart's own axis gutters
/// and zoom window rather than from an approximation of them (issue #1579).
class RangeSelectionOverlay extends StatefulWidget {
  static const Key startHandleKey = Key('rangeSelection.startHandle');
  static const Key endHandleKey = Key('rangeSelection.endHandle');
  static const Key leadingShadeKey = Key('rangeSelection.leadingShade');
  static const Key trailingShadeKey = Key('rangeSelection.trailingShade');

  /// Selected range, in seconds from the start of the dive.
  final int startSeconds;
  final int endSeconds;

  /// Last timestamp of the profile; the end handle stops here.
  final int maxSeconds;

  /// The chart's visible time window in seconds (narrows as it zooms).
  final double visibleMinSeconds;
  final double visibleMaxSeconds;

  /// Reserved axis gutters around the plot rect (the chart's _plotInsets).
  final ({double left, double top, double right, double bottom}) insets;

  /// Called with the new range while a handle is dragged.
  final void Function(int startSeconds, int endSeconds) onRangeChanged;

  /// Called when a handle drag starts and ends, so the chart can hold off
  /// panning while the pointer belongs to a handle.
  final void Function(bool active)? onDragActiveChanged;

  const RangeSelectionOverlay({
    super.key,
    required this.startSeconds,
    required this.endSeconds,
    required this.maxSeconds,
    required this.visibleMinSeconds,
    required this.visibleMaxSeconds,
    required this.insets,
    required this.onRangeChanged,
    this.onDragActiveChanged,
  });

  @override
  State<RangeSelectionOverlay> createState() => _RangeSelectionOverlayState();
}

class _RangeSelectionOverlayState extends State<RangeSelectionOverlay> {
  /// Whether the dragged handle is currently the start of the range; null
  /// while no handle is dragged. It flips when the dragged handle passes the
  /// other one, so the highlight stays on the handle under the finger.
  bool? _draggingStart;

  /// Whether the drag belongs to the start handle's slot (the one the finger
  /// went down on); null while no handle is dragged. Unlike [_draggingStart]
  /// it never flips, because the gesture stays with the slot it started on.
  bool? _ownerIsStart;

  /// The dragged handle's position in seconds, accumulated across the drag.
  /// Held here (not recomputed from the widget) so a drag stays smooth when
  /// the caller clamps or rounds the value it is handed back.
  double _dragSeconds = 0;

  /// The handle that is not being dragged, in seconds. It stays put for the
  /// whole drag, so the dragged handle can pass it and the two swap roles
  /// (issue #1584).
  int _anchorSeconds = 0;

  @override
  void dispose() {
    // Leaving range mode mid-drag takes the handle away without a drag-end,
    // so release the caller's hold here or the chart would stay unpannable.
    if (_draggingStart != null) widget.onDragActiveChanged?.call(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final axis = RangePlotAxis(
          plotLeft: widget.insets.left,
          plotWidth:
              (constraints.maxWidth - widget.insets.left - widget.insets.right)
                  .clamp(0.0, double.infinity),
          visibleMinSeconds: widget.visibleMinSeconds,
          visibleMaxSeconds: widget.visibleMaxSeconds,
        );
        final plotTop = widget.insets.top;
        final plotHeight =
            (constraints.maxHeight - widget.insets.top - widget.insets.bottom)
                .clamp(0.0, double.infinity);
        if (axis.plotWidth <= 0 || plotHeight <= 0) {
          return const SizedBox.shrink();
        }

        final startX = axis.clampedXForSeconds(widget.startSeconds);
        final endX = axis.clampedXForSeconds(widget.endSeconds);
        final shade = colorScheme.surface.withValues(alpha: 0.7);

        return Stack(
          children: [
            // Out-of-range areas, shaded only across the plot rect so the
            // axis labels stay legible.
            if (startX > axis.plotLeft)
              Positioned(
                key: const ValueKey('rangeSelection.leadingShadeSlot'),
                left: axis.plotLeft,
                width: startX - axis.plotLeft,
                top: plotTop,
                height: plotHeight,
                child: IgnorePointer(
                  key: RangeSelectionOverlay.leadingShadeKey,
                  child: ColoredBox(color: shade),
                ),
              ),
            if (endX < axis.plotRight)
              Positioned(
                key: const ValueKey('rangeSelection.trailingShadeSlot'),
                left: endX,
                width: axis.plotRight - endX,
                top: plotTop,
                height: plotHeight,
                child: IgnorePointer(
                  key: RangeSelectionOverlay.trailingShadeKey,
                  child: ColoredBox(color: shade),
                ),
              ),
            // Selected area highlight border
            if (endX > startX)
              Positioned(
                key: const ValueKey('rangeSelection.highlightSlot'),
                left: startX,
                width: endX - startX,
                top: plotTop,
                height: plotHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        vertical: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Handles are drawn only where they have an honest position: one
            // scrolled out of the visible window is left undrawn rather than
            // pinned to an edge that would misreport its time.
            //
            // Every child of this Stack is keyed. The shades and highlight
            // come and go as the handles move, and unkeyed siblings are
            // matched by position, so a shade vanishing mid-drag would hand
            // the dragged handle's element to another child and drop the
            // drag.
            //
            // The slot that owns a drag stays mounted, though hidden, while
            // the drag takes its handle out of the window: unmounting it
            // would drop the drag without a drag-end and leave the chart
            // unpannable.
            if (axis.isVisible(widget.startSeconds) || _ownerIsStart == true)
              _buildHandle(
                context,
                axis: axis,
                position: startX,
                plotTop: plotTop,
                plotHeight: plotHeight,
                isStart: true,
                hidden: !axis.isVisible(widget.startSeconds),
                colorScheme: colorScheme,
              ),
            if (axis.isVisible(widget.endSeconds) || _ownerIsStart == false)
              _buildHandle(
                context,
                axis: axis,
                position: endX,
                plotTop: plotTop,
                plotHeight: plotHeight,
                isStart: false,
                hidden: !axis.isVisible(widget.endSeconds),
                colorScheme: colorScheme,
              ),
          ],
        );
      },
    );
  }

  Widget _buildHandle(
    BuildContext context, {
    required RangePlotAxis axis,
    required double position,
    required double plotTop,
    required double plotHeight,
    required bool isStart,
    required bool hidden,
    required ColorScheme colorScheme,
  }) {
    final isActive = _draggingStart == isStart;

    return Positioned(
      key: ValueKey(
        isStart ? 'rangeSelection.startSlot' : 'rangeSelection.endSlot',
      ),
      left: position - 16, // Center the handle on the position
      top: plotTop,
      height: plotHeight,
      width: 32,
      child: Offstage(
        offstage: hidden,
        child: Semantics(
          key: isStart
              ? RangeSelectionOverlay.startHandleKey
              : RangeSelectionOverlay.endHandleKey,
          label: context.l10n.diveLog_rangeSelection_semantics_adjust,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _startDrag(isStart),
            onHorizontalDragUpdate: (details) =>
                _updateDrag(details.delta.dx, axis),
            onHorizontalDragEnd: (_) => _endDrag(),
            onHorizontalDragCancel: _endDrag,
            child: Column(
              children: [
                // Top grip circle
                _HandleGrip(isActive: isActive, color: colorScheme.primary),
                // Vertical line
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.primary.withValues(alpha: 0.7),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                // Bottom grip circle
                _HandleGrip(isActive: isActive, color: colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startDrag(bool isStart) {
    setState(() {
      _draggingStart = isStart;
      _ownerIsStart = isStart;
      _dragSeconds = (isStart ? widget.startSeconds : widget.endSeconds)
          .toDouble();
      _anchorSeconds = isStart ? widget.endSeconds : widget.startSeconds;
    });
    widget.onDragActiveChanged?.call(true);
  }

  void _updateDrag(double deltaX, RangePlotAxis axis) {
    // Pixels convert through the visible window, so a drag covers less time
    // the further the chart is zoomed in. Only the dive bounds stop the
    // handle; the other handle does not, so a drag can carry on past it.
    _dragSeconds = (_dragSeconds + deltaX * axis.secondsPerPixel).clamp(
      0.0,
      math.max(widget.maxSeconds, 0).toDouble(),
    );
    final seconds = _dragSeconds.round();
    // Sitting exactly on the other handle would be an empty range; hold the
    // last one until the drag moves off it.
    if (seconds == _anchorSeconds) return;

    final draggingStart = seconds < _anchorSeconds;
    if (draggingStart != _draggingStart) {
      setState(() => _draggingStart = draggingStart);
    }
    widget.onRangeChanged(
      math.min(seconds, _anchorSeconds),
      math.max(seconds, _anchorSeconds),
    );
  }

  void _endDrag() {
    setState(() {
      _draggingStart = null;
      _ownerIsStart = null;
    });
    widget.onDragActiveChanged?.call(false);
  }
}

/// Circular grip at the top and bottom of range selection handles.
class _HandleGrip extends StatelessWidget {
  final bool isActive;
  final Color color;

  const _HandleGrip({required this.isActive, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isActive ? 16 : 12,
      height: isActive ? 16 : 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// Button to toggle range selection mode.
///
/// Shows an outlined button when range mode is off, and a filled
/// button with close action when range mode is on.
class RangeSelectionToggle extends ConsumerWidget {
  final String diveId;

  const RangeSelectionToggle({super.key, required this.diveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeState = ref.watch(rangeSelectionProvider(diveId));
    final colorScheme = Theme.of(context).colorScheme;

    if (rangeState.isEnabled) {
      return FilledButton.icon(
        onPressed: () {
          ref.read(rangeSelectionProvider(diveId).notifier).disableRangeMode();
        },
        icon: const Icon(Icons.close, size: 18),
        label: Text(context.l10n.diveLog_rangeSelection_exitRange),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () {
        ref.read(rangeSelectionProvider(diveId).notifier).enableRangeMode();
      },
      icon: const Icon(Icons.straighten, size: 18),
      label: Text(context.l10n.diveLog_rangeSelection_selectRange),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
