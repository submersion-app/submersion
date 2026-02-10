import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';

/// Overlay widget for selecting a time range on the dive profile chart.
///
/// Displays two draggable vertical handles that define the start and end
/// of a selected range. The area outside the selection is shaded.
class RangeSelectionOverlay extends ConsumerStatefulWidget {
  /// The dive ID for scoping the range selection provider
  final String diveId;

  /// The total width available for the overlay (chart width)
  final double chartWidth;

  /// Left padding to align with chart area (y-axis labels width)
  final double leftPadding;

  /// Right padding to align with chart area
  final double rightPadding;

  const RangeSelectionOverlay({
    super.key,
    required this.diveId,
    required this.chartWidth,
    this.leftPadding = 40,
    this.rightPadding = 16,
  });

  @override
  ConsumerState<RangeSelectionOverlay> createState() =>
      _RangeSelectionOverlayState();
}

class _RangeSelectionOverlayState extends ConsumerState<RangeSelectionOverlay> {
  /// Which handle is currently being dragged
  _DragTarget? _activeDrag;

  /// The usable width for range selection (excluding axis padding)
  double get _selectableWidth =>
      widget.chartWidth - widget.leftPadding - widget.rightPadding;

  @override
  Widget build(BuildContext context) {
    final rangeState = ref.watch(rangeSelectionProvider(widget.diveId));

    if (!rangeState.isEnabled) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Calculate handle positions
    final startX =
        widget.leftPadding + (rangeState.startProgress * _selectableWidth);
    final endX =
        widget.leftPadding + (rangeState.endProgress * _selectableWidth);

    return SizedBox(
      width: widget.chartWidth,
      child: Stack(
        children: [
          // Left shaded area (before selection)
          Positioned(
            left: widget.leftPadding,
            top: 0,
            bottom: 0,
            width: startX - widget.leftPadding,
            child: Container(color: colorScheme.surface.withValues(alpha: 0.7)),
          ),
          // Right shaded area (after selection)
          Positioned(
            left: endX,
            top: 0,
            bottom: 0,
            right: widget.rightPadding,
            child: Container(color: colorScheme.surface.withValues(alpha: 0.7)),
          ),
          // Selected area highlight border
          Positioned(
            left: startX,
            top: 0,
            bottom: 0,
            width: endX - startX,
            child: Container(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          // Start handle
          _buildHandle(
            context,
            position: startX,
            isStart: true,
            colorScheme: colorScheme,
          ),
          // End handle
          _buildHandle(
            context,
            position: endX,
            isStart: false,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(
    BuildContext context, {
    required double position,
    required bool isStart,
    required ColorScheme colorScheme,
  }) {
    final target = isStart ? _DragTarget.start : _DragTarget.end;
    final isActive = _activeDrag == target;

    return Positioned(
      left: position - 16, // Center the handle on the position
      top: 0,
      bottom: 0,
      width: 32,
      child: Semantics(
        label: 'Adjust range selection',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            setState(() => _activeDrag = target);
          },
          onHorizontalDragUpdate: (details) {
            _handleDrag(details.localPosition.dx + position - 16, isStart);
          },
          onHorizontalDragEnd: (_) {
            setState(() => _activeDrag = null);
          },
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

  void _handleDrag(double localX, bool isStart) {
    // Convert pixel position to progress (0.0 to 1.0)
    final progress = ((localX - widget.leftPadding) / _selectableWidth).clamp(
      0.0,
      1.0,
    );

    final notifier = ref.read(rangeSelectionProvider(widget.diveId).notifier);

    if (isStart) {
      notifier.setStartProgress(progress);
    } else {
      notifier.setEndProgress(progress);
    }
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
        label: const Text('Exit Range'),
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
      label: const Text('Select Range'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
