import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/presentation/widgets/dive_sparkline.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/dive_consolidation_builder.dart';
import 'package:submersion/features/dive_log/domain/services/dive_merge_builder.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/run_dive_consolidation.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dialog that classifies the current dive selection and either previews a
/// sequential combine, previews a multi-computer consolidation (same dive
/// recorded by more than one computer), or reports an error (mixed divers,
/// same computer, non-overlapping).
///
/// See dive_merge_builder.dart / dive_merge_service.dart for the sequential
/// classification and persistence logic (#449), and
/// dive_consolidation_builder.dart / dive_consolidation_service.dart for the
/// overlapping/consolidation path.
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
  bool _loadFailed = false;

  /// Selected primary dive id for the multi-computer consolidation panel.
  /// Null until the user picks one, in which case
  /// [DiveConsolidationBuilder.classify]/`build` default to the earliest
  /// entry time.
  String? _selectedPrimaryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dives = await ref
          .read(diveRepositoryProvider)
          .getDivesByIds(widget.diveIds);
      if (!mounted) return;
      setState(() {
        _dives = dives;
        _classification = const DiveMergeBuilder().classify(dives);
      });
    } catch (_) {
      // A DB/query failure would otherwise leave the dialog stuck on the
      // loading spinner; surface the generic combine error panel instead.
      if (mounted) setState(() => _loadFailed = true);
    }
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
          _ when _loadFailed => _buildErrorPanel(
            context,
            context.l10n.diveLog_combine_error,
          ),
          null => const Center(child: CircularProgressIndicator()),
          final MergeSequential seq => _buildPreview(context, seq),
          MergeOverlapping() => _buildConsolidationPanel(context),
          final MergeInvalid invalid => _buildErrorPanel(
            context,
            switch (invalid.reason) {
              // tooFewDives is reachable when a selected dive was deleted
              // (locally or via sync) before the dialog finished loading; the
              // mixed-divers text would mislead, so use the generic error.
              DiveMergeInvalidReason.mixedDivers =>
                context.l10n.diveLog_combine_mixedDivers,
              DiveMergeInvalidReason.tooFewDives =>
                context.l10n.diveLog_combine_error,
            },
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

  /// An overlapping selection looks like the same physical dive recorded by
  /// more than one dive computer. Runs [DiveConsolidationBuilder.classify]
  /// with the currently-selected primary (defaulting to the earliest entry
  /// time) and renders either the mapped error text or the consolidation
  /// preview/selector/confirm panel.
  Widget _buildConsolidationPanel(BuildContext context) {
    final classification = const DiveConsolidationBuilder().classify(
      _dives!,
      primaryDiveId: _selectedPrimaryId,
    );

    return switch (classification) {
      final ConsolidationInvalid invalid => _buildErrorPanel(
        context,
        switch (invalid.reason) {
          ConsolidationInvalidReason.sameComputer =>
            context.l10n.diveLog_consolidate_error_sameComputer,
          ConsolidationInvalidReason.notOverlapping =>
            context.l10n.diveLog_consolidate_error_notOverlapping,
          // Unreachable in practice -- the outer DiveMergeBuilder
          // classification already rules out mixedDivers/tooFewDives before
          // this panel is reached -- but handled for completeness.
          ConsolidationInvalidReason.mixedDivers ||
          ConsolidationInvalidReason.tooFewDives =>
            context.l10n.diveLog_consolidate_error_generic,
        },
      ),
      final ConsolidationReady ready => _buildConsolidationReadyPanel(
        context,
        ready,
      ),
    };
  }

  Widget _buildConsolidationReadyPanel(
    BuildContext context,
    ConsolidationReady ready,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timePattern = ref.watch(timeFormatProvider).pattern;

    // Pure preview computation -- never persisted, same reasoning as the
    // sequential branch's build() call above.
    final plan = const DiveConsolidationBuilder().build(
      _dives!,
      primaryDiveId: _selectedPrimaryId,
    );

    // A stable (selection-independent) order for the radio tiles and chart
    // series/colors, so picking a different primary re-labels rather than
    // re-shuffling the list.
    final sortedDives = [..._dives!]
      ..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));
    final hasProfileData = plan.previewSeries.values.any(
      (series) => series.isNotEmpty,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  if (hasProfileData) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.diveLog_combine_profilePreview,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // One line per source dive on the primary's shared
                    // timeline, distinct colors matching the radio tiles
                    // below.
                    DiveSparkline(
                      profile:
                          plan.previewSeries[sortedDives.first.id] ?? const [],
                      width: double.infinity,
                      height: 120,
                      color: sourceColorAt(0),
                      maxPoints: 200,
                      extraSeries: [
                        for (var i = 1; i < sortedDives.length; i++)
                          DiveSparklineSeries(
                            profile:
                                plan.previewSeries[sortedDives[i].id] ??
                                const [],
                            color: sourceColorAt(i),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.diveLog_consolidate_selectPrimary,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  RadioGroup<String>(
                    groupValue: ready.primary.id,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedPrimaryId = value);
                    },
                    child: Column(
                      children: [
                        for (var i = 0; i < sortedDives.length; i++)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: sortedDives[i].id,
                            secondary: ExcludeSemantics(
                              child: Icon(
                                Icons.circle,
                                size: 12,
                                color: sourceColorAt(i),
                              ),
                            ),
                            title: Text(
                              _computerLabel(sortedDives[i], timePattern),
                              style: textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // OverflowBar (rather than Row, used elsewhere in this dialog)
          // because the confirm label is long enough to overflow a 520px
          // dialog alongside Cancel; OverflowBar stacks the buttons
          // vertically instead of clipping when they don't fit.
          OverflowBar(
            spacing: 8,
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(context.l10n.common_action_cancel),
              ),
              FilledButton(
                onPressed: () => _confirmConsolidation(ready),
                child: Text(context.l10n.diveLog_consolidate_confirm),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Applies the consolidation via [runDiveConsolidation] (apply + Undo
  /// SnackBar + error mapping, shared with the per-dive "Merge with another
  /// dive" flow). The dialog closes immediately; [runDiveConsolidation] only
  /// touches [context] synchronously before its first `await`, so doing that
  /// after [Navigator.pop] is safe (the dialog's element isn't actually
  /// unmounted until the pop's exit transition finishes).
  void _confirmConsolidation(ConsolidationReady ready) {
    final container = ProviderScope.containerOf(context, listen: false);
    final service = ref.read(diveConsolidationServiceProvider);
    final targetId = ready.primary.id;
    final secondaryIds = [for (final s in ready.secondaries) s.id];

    Navigator.of(context).pop(null);

    runDiveConsolidation(
      context: context,
      service: service,
      targetDiveId: targetId,
      secondaryDiveIds: secondaryIds,
      onConsolidated: () {
        // Captured via the container (rather than `ref`) so this still works
        // once this dialog's own State has been disposed.
        container.invalidate(paginatedDiveListProvider);
        container.invalidate(diveListNotifierProvider);
        container.invalidate(divesProvider);
        container.invalidate(diveStatisticsProvider);
        container.invalidate(diveNumberingInfoProvider);

        // Invalidate per-dive detail providers for all involved dive IDs
        // (target and secondaries) for parity with dive_detail_page.dart.
        for (final diveId in [targetId, ...secondaryIds]) {
          container.invalidate(diveProvider(diveId));
          container.invalidate(diveProfileProvider(diveId));
          container.invalidate(sourceProfilesProvider(diveId));
          container.invalidate(diveDataSourcesProvider(diveId));
        }
      },
    );
  }

  /// "`<model>` · `<entry time>`", or just the entry time when the dive has
  /// no recorded computer model.
  String _computerLabel(domain.Dive dive, String timePattern) {
    final timeStr = DateFormat(timePattern).format(dive.effectiveEntryTime);
    final model = dive.diveComputerModel;
    return model != null && model.isNotEmpty ? '$model · $timeStr' : timeStr;
  }

  Widget _buildErrorPanel(BuildContext context, String message) {
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

  // Matches the shared duration format (dive_field_formatter.dart): "Xh Ym"
  // for >= 1 hour, "Xmin" otherwise.
  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 60) return '${totalMinutes}min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
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
