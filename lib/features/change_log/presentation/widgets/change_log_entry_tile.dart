import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/features/change_log/presentation/change_log_value_format.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One entry in the feed: its record, when and where from, and enough of what
/// changed to scan without opening it.
class ChangeLogEntryTile extends StatelessWidget {
  const ChangeLogEntryTile({
    super.key,
    required this.operation,
    required this.preview,
    this.recordCount,
    required this.formatter,
    required this.units,
    required this.peerNames,
    required this.onTap,
  });

  final ChangeLogOperation operation;
  final ChangeLogPreview? preview;

  /// How many records a bulk entry touched.
  final int? recordCount;
  final ChangeLogValueFormatter formatter;
  final UnitFormatter units;
  final Map<String, String> peerNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final preview = this.preview;
    final more = (preview?.total ?? 0) - (preview?.fields.length ?? 0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.surfaceContainerHighest,
              foregroundColor: colors.onSurfaceVariant,
              child: Icon(changeLogSourceIcon(operation.source), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    changeLogTitle(l, operation),
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    changeLogSubtitle(l, units, operation, peerNames),
                    style: muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (operation.isReverted) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.changeLog_reverted,
                      style: muted?.copyWith(color: colors.primary),
                    ),
                  ],
                  for (final field in preview?.fields ?? const [])
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _FieldChangeLine(
                        field: field,
                        formatter: formatter,
                      ),
                    ),
                  if (more > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l.changeLog_moreFields(more),
                        style: muted?.copyWith(color: colors.primary),
                      ),
                    ),
                  if (_actionText(context) case final action?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(action, style: muted),
                    ),
                  if (operation.isBulk && !operation.isSummary)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l.changeLog_viewRecords(
                          recordCount ?? operation.eventCount,
                        ),
                        style: muted?.copyWith(color: colors.primary),
                      ),
                    ),
                  if (operation.isSummary && operation.summaryCount! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l.changeLog_summaryRecords(operation.summaryCount!),
                        style: muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _actionText(BuildContext context) {
    final l = context.l10n;
    if ((preview?.total ?? 0) > 0) return null;
    return switch (preview?.rootAction) {
      ChangeLogAction.insert => l.changeLog_action_added,
      ChangeLogAction.delete => l.changeLog_action_deleted,
      _ => null,
    };
  }
}

/// `Label: old new`, with the old value struck through.
class _FieldChangeLine extends StatelessWidget {
  const _FieldChangeLine({required this.field, required this.formatter});

  final ChangeLogFieldChange field;
  final ChangeLogValueFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final old = formatter.value(
      field.table,
      field.column,
      field.oldValue,
      clip: kChangeLogFeedClip,
    );
    final current = formatter.value(
      field.table,
      field.column,
      field.newValue,
      clip: kChangeLogFeedClip,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '${formatter.label(field.table, field.column)}: '),
          TextSpan(
            text: old,
            style: style?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const TextSpan(text: ' '),
          TextSpan(text: current),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
