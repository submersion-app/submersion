import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/features/change_log/presentation/change_log_value_format.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Why part of a revert cannot happen, in a sentence.
String changeLogBlockText(AppLocalizations l, ChangeLogBlock block) =>
    switch (block) {
      ChangeLogBlock.recordGone => l.changeLog_block_recordGone,
      ChangeLogBlock.columnGone => l.changeLog_block_columnGone,
      ChangeLogBlock.rewritten => l.changeLog_block_rewritten,
      ChangeLogBlock.parentGone => l.changeLog_block_parentGone,
      ChangeLogBlock.alreadyRestored => l.changeLog_block_alreadyRestored,
      ChangeLogBlock.inUse => l.changeLog_block_inUse,
    };

enum _Choice { rest, all }

final _log = LoggerService.forClass(ChangeLogRevertService);

/// Plans, asks where it must, and reverts. A bulk action always asks first,
/// since it can remove records. An edit asks only when something changed
/// since, because a revert is itself logged and can be reverted.
Future<void> runChangeLogRevert(
  BuildContext context,
  WidgetRef ref, {
  required Future<ChangeLogRevertPlan> Function(ChangeLogRevertService service)
  plan,
  bool bulk = false,
}) async {
  final l = context.l10n;
  final service = ref.read(changeLogRevertServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final formatter = ChangeLogValueFormatter(
    l10n: l,
    units: ref.read(unitFormatterProvider),
  );
  try {
    final planned = await plan(service);
    if (!context.mounted) return;

    final field = planned.items.length == 1 ? planned.items.single : null;
    var includeChangedSince = true;
    if (bulk) {
      final choice = await _askBulk(context, planned);
      if (choice == null) return;
      includeChangedSince = choice == _Choice.all;
    } else if (field != null && field.column != null && field.changedSince) {
      if (!await _askField(context, field, formatter)) return;
    } else if (planned.hasChangedSince) {
      final choice = await _askBulk(context, planned);
      if (choice == null) return;
      includeChangedSince = choice == _Choice.all;
    }

    final result = await service.execute(
      planned,
      includeChangedSince: includeChangedSince,
    );
    if (!context.mounted) return;
    if (result.keptItems.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.changeLog_result_reverted(result.reverted))),
      );
    } else {
      await _showKept(context, ref, result);
    }
  } catch (error, stackTrace) {
    _log.error(
      'Could not revert a change log entry',
      error: error,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(SnackBar(content: Text(l.changeLog_revert_failed)));
  }
}

Future<bool> _askField(
  BuildContext context,
  ChangeLogRevertItem item,
  ChangeLogValueFormatter formatter,
) async {
  final l = context.l10n;
  final table = item.event.table;
  final column = item.column!;
  String show(Object? value) =>
      formatter.value(table, column, value, clip: kChangeLogFeedClip);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.changeLog_revert_title(formatter.label(table, column))),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.changeLog_revert_changedSince),
            const SizedBox(height: 12),
            Text(l.changeLog_revert_setInEntry(show(item.logged))),
            Text(l.changeLog_revert_now(show(item.current))),
            Text(l.changeLog_revert_after(show(item.target))),
            const SizedBox(height: 12),
            Text(
              l.changeLog_revert_note,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.changeLog_revert_anyway),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<_Choice?> _askBulk(BuildContext context, ChangeLogRevertPlan plan) {
  final l = context.l10n;
  final changed = plan.changedSinceCount;
  return showDialog<_Choice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.changeLog_bulk_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (changed > 0) ...[
            Text(l.changeLog_bulk_changedSince(changed)),
            const SizedBox(height: 12),
          ],
          Text(l.changeLog_undo_explain),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.common_action_cancel),
        ),
        if (changed > 0)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_Choice.rest),
            child: Text(l.changeLog_bulk_revertRest),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_Choice.all),
          child: Text(l.changeLog_bulk_revertAll),
        ),
      ],
    ),
  );
}

/// What a bulk undo left behind, each with its reason.
Future<void> _showKept(
  BuildContext context,
  WidgetRef ref,
  ChangeLogRevertResult result,
) async {
  final l = context.l10n;
  final units = ref.read(unitFormatterProvider);
  // A kept dive's tanks stay with it, so naming the dive says it all.
  final roots = [
    for (final item in result.keptItems)
      if (item.event.root == _recordOf(item)) item,
  ];
  final kept = roots.isEmpty ? result.keptItems : roots;
  final names = await ref.read(changeLogRepositoryProvider).describeRoots({
    for (final item in kept) _recordOf(item),
  });
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.changeLog_result_kept(kept.length)),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (result.reverted > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.changeLog_result_reverted(result.reverted)),
              ),
            for (final item in kept)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(switch (names[_recordOf(item)]) {
                  final name? when !name.isMissing => conflictReferenceValue(
                    l,
                    units,
                    name,
                  ),
                  _ => changeLogTableLabel(l, item.event.table),
                }),
                subtitle: Text(
                  item.block == null
                      ? l.changeLog_action_edited
                      : changeLogBlockText(l, item.block!),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.common_action_ok),
        ),
      ],
    ),
  );
}

ChangeLogRoot _recordOf(ChangeLogRevertItem item) =>
    (table: item.event.table, id: item.event.recordId);
