import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the combine dialog does with dives that do not overlap in time
/// (#552).
enum CombineMode {
  /// Join them end to end into one continuous dive.
  join,

  /// Fold them into one dive as additional dive computers.
  merge,
}

/// Below this width (a phone's dialog is about 262 pt wide, a desktop's 472)
/// the controls shorten their labels and fold the clock note, so the preview
/// chart stays on the first screen.
const double _compactMaxWidth = 360;

/// The Join / Merge choice at the top of the combine dialog, shown when a
/// non-overlapping selection could also be merged as computers.
class CombineModeSelector extends StatelessWidget {
  const CombineModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    this.showSameDiveHint = false,
  });

  final CombineMode mode;
  final ValueChanged<CombineMode> onChanged;

  /// Whether the profiles matched well enough to call the records one dive.
  final bool showSameDiveHint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _build(context, compact: constraints.maxWidth < _compactMaxWidth),
  );

  Widget _build(BuildContext context, {required bool compact}) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<CombineMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: CombineMode.join,
              label: Text(
                compact
                    ? l10n.diveLog_combine_modeJoinShort
                    : l10n.diveLog_combine_modeJoin,
              ),
            ),
            ButtonSegment(
              value: CombineMode.merge,
              label: Text(
                compact
                    ? l10n.diveLog_combine_modeMergeShort
                    : l10n.diveLog_combine_modeMerge,
              ),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => onChanged(selection.single),
        ),
        if (showSameDiveHint) ...[
          const SizedBox(height: 8),
          _Note(
            icon: Icons.lightbulb_outline,
            text: l10n.diveLog_consolidate_sameDiveHint,
          ),
        ],
      ],
    );
  }
}

/// The clock note and the Best fit / Align starts toggle, shown above the
/// consolidation preview when a secondary does not overlap the primary.
class ConsolidationAlignmentControls extends StatelessWidget {
  const ConsolidationAlignmentControls({
    super.key,
    required this.alignment,
    required this.onChanged,
    this.showFallbackNote = false,
  });

  final ConsolidationAlignment alignment;
  final ValueChanged<ConsolidationAlignment> onChanged;

  /// Whether best fit had no profile to match for some record.
  final bool showFallbackNote;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _build(context, compact: constraints.maxWidth < _compactMaxWidth),
  );

  Widget _build(BuildContext context, {required bool compact}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          // One short line; the full explanation is a tap away.
          Tooltip(
            message: l10n.diveLog_consolidate_clockNote,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 8),
            child: _Note(
              icon: Icons.info_outline,
              text: l10n.diveLog_consolidate_clockNoteShort,
            ),
          )
        else ...[
          _Note(icon: Icons.schedule, text: l10n.diveLog_consolidate_clockNote),
          const SizedBox(height: 12),
          Text(
            l10n.diveLog_consolidate_alignmentLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SegmentedButton<ConsolidationAlignment>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: ConsolidationAlignment.bestFit,
              label: Text(l10n.diveLog_consolidate_alignBestFit),
            ),
            ButtonSegment(
              value: ConsolidationAlignment.starts,
              label: Text(
                compact
                    ? l10n.diveLog_consolidate_alignStartsShort
                    : l10n.diveLog_consolidate_alignStarts,
              ),
            ),
          ],
          selected: {alignment},
          onSelectionChanged: (selection) => onChanged(selection.single),
        ),
        if (showFallbackNote) ...[
          const SizedBox(height: 8),
          _Note(
            icon: Icons.info_outline,
            text: l10n.diveLog_consolidate_noProfileFallback,
          ),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
