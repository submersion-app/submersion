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
  /// Which handle is currently being dragged
  _DragTarget? _activeDrag;

  /// The dragged handle's position in seconds, accumulated across the drag.
  /// Held here (not recomputed from the widget) so a drag stays smooth when
  /// the caller clamps or rounds the value it is handed back.
  double _dragSeconds = 0;

  @override
  void dispose() {
    // Leaving range mode mid-drag takes the handle away without a drag-end,
    // so release the caller's hold here or the chart would stay unpannable.
    if (_activeDrag != null) widget.onDragActiveChanged?.call(false);
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
            if (axis.isVisible(widget.startSeconds))
              _buildHandle(
                context,
                axis: axis,
                position: startX,
                plotTop: plotTop,
                plotHeight: plotHeight,
                isStart: true,
                colorScheme: colorScheme,
              ),
            if (axis.isVisible(widget.endSeconds))
              _buildHandle(
                context,
                axis: axis,
                position: endX,
                plotTop: plotTop,
                plotHeight: plotHeight,
                isStart: false,
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
    required ColorScheme colorScheme,
  }) {
    final target = isStart ? _DragTarget.start : _DragTarget.end;
    final isActive = _activeDrag == target;

    return Positioned(
      left: position - 16, // Center the handle on the position
      top: plotTop,
      height: plotHeight,
      width: 32,
      child: Semantics(
        key: isStart
            ? RangeSelectionOverlay.startHandleKey
            : RangeSelectionOverlay.endHandleKey,
        label: context.l10n.diveLog_rangeSelection_semantics_adjust,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _startDrag(target, isStart),
          onHorizontalDragUpdate: (details) =>
              _updateDrag(details.delta.dx, isStart, axis),
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
                              color: colorScheme.primary.withValues(alpha: 0.4),
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
    );
  }

  void _startDrag(_DragTarget target, bool isStart) {
    setState(() {
      _activeDrag = target;
      _dragSeconds = (isStart ? widget.startSeconds : widget.endSeconds)
          .toDouble();
    });
    widget.onDragActiveChanged?.call(true);
  }

  void _updateDrag(double deltaX, bool isStart, RangePlotAxis axis) {
    // Pixels convert through the visible window, so a drag covers less time
    // the further the chart is zoomed in.
    final lower = isStart
        ? 0.0
        : math.min(widget.startSeconds + 1, widget.maxSeconds).toDouble();
    final upper = isStart
        ? math.max(widget.endSeconds - 1, 0).toDouble()
        : widget.maxSeconds.toDouble();
    if (upper < lower) return;

    _dragSeconds = (_dragSeconds + deltaX * axis.secondsPerPixel).clamp(
      lower,
      upper,
    );
    final seconds = _dragSeconds.round();
    widget.onRangeChanged(
      isStart ? seconds : widget.startSeconds,
      isStart ? widget.endSeconds : seconds,
    );
  }

  void _endDrag() {
    setState(() => _activeDrag = null);
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

/// Which handle is being dragged
enum _DragTarget { start, end }

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
