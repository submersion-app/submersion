import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Context-sensitive control panel for the profile editor.
///
/// Renders different controls based on the current [EditorMode]:
/// - Select: range shift/delete/smooth operations
/// - Smooth: window size selection and apply buttons
/// - Cleanup: detect and remove outlier controls, trim, profile deletion,
///   and removal of the source being edited
/// - Draw: waypoint management and profile generation
class EditorContextPanel extends StatefulWidget {
  final EditorMode mode;
  final ProfileEditorNotifier notifier;
  final int? outlierCount;
  final ({int start, int end})? selectedRange;
  final bool hasWaypoints;
  final VoidCallback? onDeleteProfile;
  final bool canDeleteProfile;

  /// Why Delete Entire Profile is disabled, shown under the Cleanup buttons
  /// (issue #4972). Null when it is enabled or the reason is not known yet.
  final String? deleteProfileHint;

  /// Whether Cleanup offers Remove This Source: only for a source of a dive
  /// with more than one, which the removal can take away (issue #4972).
  final bool showRemoveSource;

  /// Removes the source being edited. Null disables the button, as while
  /// the session has unsaved edits.
  final VoidCallback? onRemoveSource;

  const EditorContextPanel({
    super.key,
    required this.mode,
    required this.notifier,
    this.outlierCount,
    this.selectedRange,
    this.hasWaypoints = false,
    this.onDeleteProfile,
    this.canDeleteProfile = false,
    this.deleteProfileHint,
    this.showRemoveSource = false,
    this.onRemoveSource,
  });

  @override
  State<EditorContextPanel> createState() => _EditorContextPanelState();
}

class _EditorContextPanelState extends State<EditorContextPanel> {
  int _smoothWindowSize = 5;

  void _showRefusal(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _shiftTime(int timeDelta) {
    if (widget.notifier.shiftSegmentTime(timeDelta)) return;
    _showRefusal(context.l10n.diveLog_profileEditor_timeShiftBlocked);
  }

  void _deleteSelection() {
    if (widget.notifier.deleteSegment(interpolateGap: true)) return;
    _showRefusal(context.l10n.diveLog_profileEditor_deleteAllBlocked);
  }

  void _smoothSelection({int windowSize = 5}) {
    if (widget.notifier.applySmoothingToRange(windowSize: windowSize)) return;
    _showRefusal(context.l10n.diveLog_profileEditor_smoothTooFewBlocked);
  }

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

  Widget _buildRangeHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        context.l10n.diveLog_profileEditor_selectRangeHint,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
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
        if (!hasRange) _buildRangeHint(context),
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
              onPressed: hasRange ? () => _shiftTime(5) : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(
                context.l10n.diveLog_profileEditor_timePlusFiveSeconds,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange ? () => _shiftTime(-5) : null,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                context.l10n.diveLog_profileEditor_timeMinusFiveSeconds,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange ? _deleteSelection : null,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(context.l10n.common_action_delete),
            ),
            FilledButton.tonalIcon(
              onPressed: hasRange ? _smoothSelection : null,
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
        if (widget.selectedRange == null) _buildRangeHint(context),
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
                  ? () => _smoothSelection(windowSize: _smoothWindowSize)
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
              context.l10n.diveLog_profileEditor_cleanup,
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
        // Four buttons do not fit one line on a phone, so they wrap.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => widget.notifier.detectOutliers(),
              icon: const Icon(Icons.search, size: 18),
              label: Text(context.l10n.diveLog_profileEditor_detectOutliers),
            ),
            FilledButton.icon(
              onPressed: count > 0
                  ? () => widget.notifier.removeAllOutliers()
                  : null,
              icon: const Icon(Icons.cleaning_services, size: 18),
              label: Text(context.l10n.diveLog_profileEditor_removeOutliers),
            ),
            FilledButton.tonalIcon(
              onPressed: () => widget.notifier.trimEndZeros(),
              icon: const Icon(Icons.content_cut, size: 18),
              label: Text(context.l10n.diveLog_profileEditor_trimEnd),
            ),
            FilledButton.icon(
              onPressed: widget.canDeleteProfile
                  ? widget.onDeleteProfile
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(
                context.l10n.diveLog_profileEditor_deleteProfile_title,
              ),
            ),
            if (widget.showRemoveSource)
              FilledButton.tonalIcon(
                onPressed: widget.onRemoveSource,
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: Text(context.l10n.diveLog_profileEditor_removeSource),
              ),
          ],
        ),
        if (widget.deleteProfileHint case final hint?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
}
