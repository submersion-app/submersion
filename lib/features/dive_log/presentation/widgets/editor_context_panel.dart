import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Context-sensitive control panel for the profile editor.
///
/// Renders different controls based on the current [EditorMode]:
/// - Select: range shift/delete/smooth operations
/// - Smooth: window size selection and apply buttons
/// - Outlier: detect and remove outlier controls
/// - Draw: waypoint management and profile generation
/// - Trim: profile trimming controls
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
        EditorMode.trim => _buildTrimPanel(context),
      },
    );
  }

  Widget _buildSelectPanel(BuildContext context) {
    final hasRange = widget.selectedRange != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.diveLog_profileEditor_rangeOperations,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (!hasRange)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.l10n.diveLog_profileEditor_selectRangeHint,
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
              label: Text(context.l10n.diveLog_profileEditor_depthPlusOneMeter),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.shiftSegmentDepth(-1.0)
                  : null,
              icon: const Icon(Icons.arrow_downward, size: 18),
              label: Text(
                context.l10n.diveLog_profileEditor_depthMinusOneMeter,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.shiftSegmentTime(5)
                  : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(
                context.l10n.diveLog_profileEditor_timePlusFiveSeconds,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.shiftSegmentTime(-5)
                  : null,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                context.l10n.diveLog_profileEditor_timeMinusFiveSeconds,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.deleteSegment(interpolateGap: true)
                  : null,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(context.l10n.common_action_delete),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange
                  ? () => widget.notifier.applySmoothingToRange()
                  : null,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: Text(context.l10n.diveLog_profileEditor_mode_smooth),
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
        Text(
          context.l10n.diveLog_profileEditor_smoothing,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(
              value: 3,
              label: Text(context.l10n.diveLog_profileEditor_smoothLight),
            ),
            ButtonSegment(
              value: 5,
              label: Text(context.l10n.diveLog_profileEditor_smoothMedium),
            ),
            ButtonSegment(
              value: 7,
              label: Text(context.l10n.diveLog_profileEditor_smoothHeavy),
            ),
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
              label: Text(context.l10n.diveLog_profileEditor_applyToAll),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: widget.selectedRange != null
                  ? () => widget.notifier.applySmoothingToRange(
                      windowSize: _smoothWindowSize,
                    )
                  : null,
              icon: const Icon(Icons.done, size: 18),
              label: Text(context.l10n.diveLog_profileEditor_applyToSelection),
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
              context.l10n.diveLog_profileEditor_outlierDetection,
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
              label: Text(context.l10n.diveLog_profileEditor_detect),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: count > 0
                  ? () => widget.notifier.removeAllOutliers()
                  : null,
              icon: const Icon(Icons.cleaning_services, size: 18),
              label: Text(context.l10n.diveLog_profileEditor_removeAll),
            ),
          ],
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.l10n.diveLog_profileEditor_outliersDetected(count),
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
        Text(
          context.l10n.diveLog_profileEditor_manualDrawing,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.diveLog_profileEditor_drawHint,
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
              label: Text(context.l10n.diveLog_profileEditor_clearWaypoints),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: widget.hasWaypoints
                  ? () => widget.notifier.generateProfileFromWaypoints()
                  : null,
              icon: const Icon(Icons.auto_graph, size: 18),
              label: Text(context.l10n.diveLog_profileEditor_generateProfile),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrimPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.diveLog_profileEditor_trimMode,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            context.l10n.diveLog_profileEditor_trimHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => widget.notifier.trimEndZeros(),
          icon: const Icon(Icons.content_cut, size: 18),
          label: Text(context.l10n.diveLog_profileEditor_trimEnd),
        ),
      ],
    );
  }
}
