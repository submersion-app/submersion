import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/presentation/widgets/dive_sparkline.dart';
import 'package:submersion/features/dive_log/data/services/source_time_alignment_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver move one secondary computer of a consolidated dive in
/// time: to where its depth trace matches the primary's, or by hand for a
/// dive the fit cannot settle (#2894).
///
/// Pops with the chosen offset in seconds, or null when cancelled or when
/// nothing changed. The caller applies it.
class SourceTimeAlignmentDialog extends ConsumerStatefulWidget {
  const SourceTimeAlignmentDialog({
    super.key,
    required this.diveId,
    required this.sourceId,
    required this.sourceName,
  });

  final String diveId;
  final String sourceId;
  final String sourceName;

  static const offsetKey = Key('source-time-alignment-offset');
  static const useFitKey = Key('source-time-alignment-use-fit');
  static const applyKey = Key('source-time-alignment-apply');

  /// The span of the preview, from the dive's start: the descent, where a
  /// misalignment shows most plainly.
  static const int previewSeconds = 600;

  /// Shows the dialog and returns the chosen offset, or null.
  static Future<int?> show(
    BuildContext context, {
    required String diveId,
    required String sourceId,
    required String sourceName,
  }) => showDialog<int>(
    context: context,
    builder: (_) => SourceTimeAlignmentDialog(
      diveId: diveId,
      sourceId: sourceId,
      sourceName: sourceName,
    ),
  );

  @override
  ConsumerState<SourceTimeAlignmentDialog> createState() =>
      _SourceTimeAlignmentDialogState();
}

class _SourceTimeAlignmentDialogState
    extends ConsumerState<SourceTimeAlignmentDialog> {
  late final Future<SourceAlignmentCheck?> _check;
  int? _offset;

  @override
  void initState() {
    super.initState();
    _check = ref
        .read(sourceTimeAlignmentServiceProvider)
        .check(widget.diveId)
        .then(
          (checks) =>
              checks.where((c) => c.sourceId == widget.sourceId).firstOrNull,
        );
  }

  String _signed(int seconds) => context.l10n.diveLog_timeAlign_seconds(
    seconds > 0 ? '+$seconds' : '$seconds',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.diveLog_timeAlign_title),
      content: FutureBuilder<SourceAlignmentCheck?>(
        future: _check,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final check = snapshot.data;
          if (check == null) {
            return Text(l10n.diveLog_timeAlign_unavailable);
          }
          return _body(check);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FutureBuilder<SourceAlignmentCheck?>(
          future: _check,
          builder: (context, snapshot) {
            final check = snapshot.data;
            final chosen = _offset ?? check?.storedOffsetSeconds;
            final changed =
                check != null && chosen != check.storedOffsetSeconds;
            return FilledButton(
              key: SourceTimeAlignmentDialog.applyKey,
              onPressed: changed
                  ? () => Navigator.of(context).pop(chosen)
                  : null,
              child: Text(l10n.common_action_apply),
            );
          },
        ),
      ],
    );
  }

  Widget _body(SourceAlignmentCheck check) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final offset = _offset ?? check.storedOffsetSeconds;
    final fit = check.fit;
    final fitText = fit.isStrongMatch
        ? l10n.diveLog_timeAlign_fitSuggestion(_signed(fit.offsetSeconds))
        : l10n.diveLog_timeAlign_noFit;

    const window = SourceTimeAlignmentDialog.previewSeconds;
    final primary = [
      for (final p in check.primaryTrace)
        if (p.timestamp <= window) p,
    ];
    final shifted = [
      for (final p in check.sourceTrace)
        if (p.timestamp + offset >= 0 && p.timestamp + offset <= window)
          DiveProfilePoint(timestamp: p.timestamp + offset, depth: p.depth),
    ];

    // Read inside setState, not from this build: two taps can land before
    // the next one.
    void nudge(int by) =>
        setState(() => _offset = (_offset ?? check.storedOffsetSeconds) + by);

    return SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.diveLog_timeAlign_body(widget.sourceName)),
            const SizedBox(height: 12),
            Text(
              l10n.diveLog_timeAlign_preview,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            DiveSparkline(
              profile: primary,
              width: double.infinity,
              height: 120,
              color: sourceColorAt(0),
              maxPoints: 200,
              extraSeries: [
                DiveSparklineSeries(profile: shifted, color: sourceColorAt(1)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: l10n.diveLog_timeAlign_earlier(_signed(-10)),
                  onPressed: () => nudge(-10),
                  icon: const Icon(Icons.keyboard_double_arrow_left),
                ),
                IconButton(
                  tooltip: l10n.diveLog_timeAlign_earlier(_signed(-1)),
                  onPressed: () => nudge(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    _signed(offset),
                    key: SourceTimeAlignmentDialog.offsetKey,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.diveLog_timeAlign_later(_signed(1)),
                  onPressed: () => nudge(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: l10n.diveLog_timeAlign_later(_signed(10)),
                  onPressed: () => nudge(10),
                  icon: const Icon(Icons.keyboard_double_arrow_right),
                ),
              ],
            ),
            Text(
              l10n.diveLog_timeAlign_stored(_signed(check.storedOffsetSeconds)),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(fitText, style: theme.textTheme.bodyMedium),
            if (fit.isStrongMatch)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: SourceTimeAlignmentDialog.useFitKey,
                  onPressed: offset == fit.offsetSeconds
                      ? null
                      : () => setState(() => _offset = fit.offsetSeconds),
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(l10n.diveLog_timeAlign_useFit),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
