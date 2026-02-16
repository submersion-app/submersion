import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';

/// Context-sensitive control panel for the profile editor.
///
/// Renders different controls based on the current [EditorMode]:
/// - Select: range shift/delete/smooth operations
/// - Smooth: window size selection and apply buttons
/// - Outlier: detect and remove outlier controls
/// - Draw: waypoint management and profile generation
class EditorContextPanel extends StatefulWidget {
  final EditorMode mode;
  final ProfileEditorNotifier notifier;
  final int? outlierCount;
  final ({int start, int end})? selectedRange;
  final bool hasWaypoints;

  const EditorContextPanel({
    super.key,
    required this.mode,
    required this.notifier,
    this.outlierCount,
    this.selectedRange,
    this.hasWaypoints = false,
  });

  @override
  State<EditorContextPanel> createState() => _EditorContextPanelState();
}

class _EditorContextPanelState extends State<EditorContextPanel> {
  int _smoothWindowSize = 5;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: switch (widget.mode) {
        EditorMode.select => _buildSelectPanel(context),
        EditorMode.smooth => _buildSmoothPanel(context),
        EditorMode.outlier => _buildOutlierPanel(context),
        EditorMode.draw => _buildDrawPanel(context),
      },
    );
  }

  Widget _buildSelectPanel(BuildContext context) {
    final hasRange = widget.selectedRange != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Range Operations', style: Theme.of(context).textTheme.titleSmall),
        if (!hasRange)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Select a range on the chart to enable operations',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.shiftSegmentDepth(1.0)
                  : null,
              icon: const Icon(Icons.arrow_upward, size: 18),
              label: const Text('Depth +1m'),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.shiftSegmentDepth(-1.0)
                  : null,
              icon: const Icon(Icons.arrow_downward, size: 18),
              label: const Text('Depth -1m'),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.shiftSegmentTime(5)
                  : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Time +5s'),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.shiftSegmentTime(-5)
                  : null,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Time -5s'),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.deleteSegment(interpolateGap: true)
                  : null,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.applySmoothingToRange()
                  : null,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('Smooth'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmoothPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Smoothing', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 3, label: Text('Light')),
            ButtonSegment(value: 5, label: Text('Medium')),
            ButtonSegment(value: 7, label: Text('Heavy')),
          ],
          selected: {_smoothWindowSize},
          onSelectionChanged: (selected) {
            setState(() => _smoothWindowSize = selected.first);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () =>
                  widget.notifier.applySmoothing(windowSize: _smoothWindowSize),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Apply to All'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: widget.selectedRange != null
                  ? () => widget.notifier.applySmoothingToRange(
                      windowSize: _smoothWindowSize,
                    )
                  : null,
              icon: const Icon(Icons.done, size: 18),
              label: const Text('Apply to Selection'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutlierPanel(BuildContext context) {
    final count = widget.outlierCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'Outlier Detection',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Badge(
                label: Text('$count'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => widget.notifier.detectOutliers(),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Detect'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: count > 0
                  ? () => widget.notifier.removeAllOutliers()
                  : null,
              icon: const Icon(Icons.cleaning_services, size: 18),
              label: const Text('Remove All'),
            ),
          ],
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$count potential outlier${count == 1 ? '' : 's'} detected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDrawPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Manual Drawing', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Tap on the chart to place waypoints',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: widget.hasWaypoints
                  ? () => widget.notifier.clearWaypoints()
                  : null,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: widget.hasWaypoints
                  ? () => widget.notifier.generateProfileFromWaypoints()
                  : null,
              icon: const Icon(Icons.auto_graph, size: 18),
              label: const Text('Generate Profile'),
            ),
          ],
        ),
      ],
    );
  }
}
