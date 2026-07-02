import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/presentation/widgets/dive_sparkline.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/dive_merge_builder.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dialog that classifies the current dive selection and either previews a
/// sequential combine, explains why an overlapping selection can't be
/// combined yet, or reports an error (mixed divers).
///
/// See dive_merge_builder.dart / dive_merge_service.dart for the underlying
/// classification and persistence logic (#449).
class CombineDivesDialog extends ConsumerStatefulWidget {
  const CombineDivesDialog({super.key, required this.diveIds});
  final List<String> diveIds;
  @override
  ConsumerState<CombineDivesDialog> createState() => _CombineDivesDialogState();
}

class _CombineDivesDialogState extends ConsumerState<CombineDivesDialog> {
  /// A surface interval longer than this suggests the two dives are really
  /// separate dives rather than one that a computer split; the preview warns
  /// (but does not block) when any gap exceeds it.
  static const _longSurfaceInterval = Duration(minutes: 30);

  List<domain.Dive>? _dives;
  DiveMergeClassification? _classification;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dives = await ref
        .read(diveRepositoryProvider)
        .getDivesByIds(widget.diveIds);
    if (!mounted) return;
    setState(() {
      _dives = dives;
      _classification = const DiveMergeBuilder().classify(dives);
    });
  }

  Future<void> _confirm() async {
    setState(() => _working = true);
    // Captured before the await so nothing touches [context] after the pop.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final outcome = await ref
          .read(diveMergeServiceProvider)
          .apply(widget.diveIds);
      if (mounted) Navigator.of(context).pop(outcome);
    } catch (_) {
      // The transaction rolled back -- nothing changed. Surface the failure
      // to the user instead of rethrowing (#449 design spec).
      if (mounted) {
        setState(() => _working = false);
        Navigator.of(context).pop(null);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.diveLog_combine_error),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: switch (_classification) {
          null => const Center(child: CircularProgressIndicator()),
          final MergeSequential seq => _buildPreview(context, seq),
          MergeOverlapping() => _buildOverlapPanel(context),
          final MergeInvalid invalid => _buildErrorPanel(
            context,
            invalid.reason,
          ),
        },
      ),
    );
  }

  Widget _buildPreview(BuildContext context, MergeSequential seq) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final timePattern = ref.watch(timeFormatProvider).pattern;

    // Pure preview computation -- never persisted. Reusing build() here
    // (rather than re-deriving the merged runtime/depth inline) means the
    // preview and the eventual persisted result can never drift apart.
    final result = const DiveMergeBuilder().build(_dives!);

    final rows = <Widget>[];
    for (var i = 0; i < seq.sortedDives.length; i++) {
      rows.add(_diveRow(context, seq.sortedDives[i], timePattern, units));
      if (i < seq.gaps.length) {
        rows.add(_gapRow(context, seq.gaps[i].duration));
      }
    }

    final hasLongSurface = seq.gaps.any(
      (g) => g.duration > _longSurfaceInterval,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Everything except the action buttons scrolls, so a chart plus a
          // long-surface warning can never overflow the dialog.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.call_merge,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          context.l10n.diveLog_combine_title,
                          style: textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.diveLog_combine_previewIntro(
                      seq.sortedDives.length,
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (result.previewProfile.isNotEmpty) ...[
                    Text(
                      context.l10n.diveLog_combine_profilePreview,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Depth-line-only preview of the merged timeline (surface
                    // gaps included) so the user can visually confirm the seam
                    // before committing. Higher maxPoints than the list
                    // thumbnails keeps a mid-dive surface interval crisp; the
                    // inserted surface gaps are highlighted so they read apart
                    // from the real dive data.
                    DiveSparkline(
                      profile: result.previewProfile,
                      width: double.infinity,
                      height: 120,
                      color: colorScheme.primary,
                      maxPoints: 200,
                      highlightColor: Colors.green,
                      highlightBands: [
                        for (final gap in result.gaps)
                          if (gap.endSeconds > gap.startSeconds)
                            (
                              startX: gap.startSeconds.toDouble(),
                              endX: gap.endSeconds.toDouble(),
                            ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...rows,
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.diveLog_combine_resultSummary(
                      _formatDuration(
                        result.mergedDive.runtime ?? Duration.zero,
                      ),
                      units.formatDepth(result.mergedDive.maxDepth),
                      result.mergedDive.bottomTime != null
                          ? _formatDuration(result.mergedDive.bottomTime!)
                          : '--',
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.diveLog_combine_dataNote,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (hasLongSurface) ...[
                    const SizedBox(height: 12),
                    _longSurfaceWarning(context),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _working
                    ? null
                    : () => Navigator.of(context).pop(null),
                child: Text(context.l10n.common_action_cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _working ? null : _confirm,
                child: Text(context.l10n.diveLog_combine_confirm),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _diveRow(
    BuildContext context,
    domain.Dive dive,
    String timePattern,
    UnitFormatter units,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final timeStr = DateFormat(timePattern).format(dive.effectiveEntryTime);
    final durationStr = dive.effectiveRuntime != null
        ? _formatDuration(dive.effectiveRuntime!)
        : null;
    final label = [
      if (dive.diveNumber != null) '#${dive.diveNumber}',
      timeStr,
      ?durationStr,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(label, style: textTheme.bodyMedium),
    );
  }

  Widget _gapRow(BuildContext context, Duration gapDuration) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = context.l10n.diveLog_combine_gapLabel(
      _formatDuration(gapDuration),
    );
    final isLong = gapDuration > _longSurfaceInterval;

    if (!isLong) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Long surface interval -- flag the specific gap in the error colour.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A prominent banner shown when any surface interval exceeds
  /// [_longSurfaceInterval], cautioning that the dives may be separate.
  Widget _longSurfaceWarning(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.diveLog_combine_longSurfaceWarning,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlapPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  context.l10n.diveLog_combine_overlapTitle,
                  style: textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.diveLog_combine_overlapBody,
            style: textTheme.bodyMedium,
          ),
          if (widget.diveIds.length == 2) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.diveLog_combine_overlapHintTwoDives,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(context.l10n.common_action_close),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPanel(BuildContext context, DiveMergeInvalidReason reason) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // tooFewDives is reachable when a selected dive was deleted (locally or
    // via sync) before the dialog finished loading; the mixed-divers text
    // would mislead there, so fall back to the generic combine error.
    final message = switch (reason) {
      DiveMergeInvalidReason.mixedDivers =>
        context.l10n.diveLog_combine_mixedDivers,
      DiveMergeInvalidReason.tooFewDives => context.l10n.diveLog_combine_error,
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.error_outline, color: colorScheme.error),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  context.l10n.diveLog_combine_title,
                  style: textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(message, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(context.l10n.common_action_close),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) return '${minutes}min';
    final hours = duration.inHours;
    final remaining = minutes - hours * 60;
    return remaining > 0 ? '${hours}h ${remaining}min' : '${hours}h';
  }
}

/// Shows the combine-dives dialog and returns the merge outcome on success,
/// or null on cancel/close/error.
Future<DiveMergeOutcome?> showCombineDivesDialog({
  required BuildContext context,
  required List<String> diveIds,
}) => showDialog<DiveMergeOutcome>(
  context: context,
  builder: (_) => CombineDivesDialog(diveIds: diveIds),
);
