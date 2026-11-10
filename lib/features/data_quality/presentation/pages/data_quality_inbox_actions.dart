import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/change_log/data/services/change_log_operation_undo.dart';
import 'package:submersion/features/data_quality/data/services/duplicate_cylinder_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/data_quality/presentation/widgets/dive_identity_label.dart';
import 'package:submersion/features/data_quality/presentation/widgets/duplicate_cylinder_dialogs.dart';
import 'package:submersion/features/data_quality/presentation/widgets/duplicate_cylinders_sheet.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/remove_source_dialog.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Inbox actions that write through a change log operation of their own
/// rather than the repair executor (issue #4393). Kept out of the inbox page,
/// which is past the file-size budget.

/// How long a destructive action's Undo stays offered, as the page's own.
const Duration inboxDestructiveUndoWindow = Duration(seconds: 10);

/// Rescans what an action rewrote, as the repair executor does.
void rescanDives(List<String> diveIds) {
  scheduleQualityScan(diveIds);
  scheduleSensorSummaryRefresh(diveIds, force: true);
  scheduleDerivedMetricsRefresh(diveIds, force: true);
}

/// Confirms and removes a source a Conflicting sources finding names. The
/// removal opens its own change log operation, so it is called directly and
/// never inside the executor's scope; its Undo reverts that operation and
/// reopens the finding.
Future<void> runRemoveSource(
  BuildContext context,
  WidgetRef ref, {
  required QualityFinding finding,
  required String diveId,
  required String sourceId,
  required String? sourceName,
}) async {
  if (!await confirmRemoveSource(context, source: sourceName)) return;
  if (!context.mounted) return;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final findings = ref.read(qualityFindingsRepositoryProvider);
  try {
    final removal = await ref
        .read(diveSourceRemovalServiceProvider)
        .remove(diveId: diveId, sourceId: sourceId);
    await findings.setStatus(finding.id, QualityStatus.resolved);
    rescanDives([diveId]);
    final operationId = removal.operationId;
    messenger.showSnackBar(
      SnackBar(
        duration: inboxDestructiveUndoWindow,
        persist: false,
        content: Text(l10n.diveLog_sources_removeDone),
        action: operationId == null
            ? null
            : SnackBarAction(
                label: l10n.dataQuality_action_undo,
                onPressed: () => unawaited(() async {
                  await undoChangeLogOperation(operationId);
                  await findings.setStatus(finding.id, QualityStatus.open);
                  rescanDives([diveId]);
                }()),
              ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveLog_sources_removeFailed)),
    );
  }
}

/// The inbox toolbar's bulk "Remove duplicate cylinders" button.
const Key bulkRemoveDuplicatesKey = Key('quality-bulk-remove-duplicates');

/// The inbox toolbar's overflow menu (Dismiss all shown).
const Key inboxOverflowMenuKey = Key('quality-inbox-overflow');

/// The service the inbox removes duplicates through, writing findings via the
/// page's repository so a test's fake sees the resolutions.
DuplicateCylinderService duplicateCylinderServiceFor(WidgetRef ref) =>
    DuplicateCylinderService(
      findings: ref.read(qualityFindingsRepositoryProvider),
    );

/// The number of dives the bulk removal would reach among [shown].
int bulkDuplicateDiveCount(Iterable<QualityFinding> shown) => {
  for (final f in DuplicateCylinderService.candidatesIn(shown)) f.diveId,
}.length;

/// Confirms and merges one twin finding's duplicate cylinders, asking which
/// gas the cylinder held when the rows disagree.
Future<void> runRemoveDuplicate(
  BuildContext context,
  WidgetRef ref, {
  required QualityFinding finding,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final service = duplicateCylinderServiceFor(ref);
  final preview = await service.previewFor(finding);
  if (preview == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.dataQuality_repair_noChange)),
    );
    return;
  }
  if (!context.mounted) return;
  final choice = await confirmRemoveDuplicate(context, preview);
  if (choice == null) return;
  final result = await service.removeOne(preview, mix: choice.mix);
  _showRemovalResult(messenger, l10n, result);
}

/// Shows the bulk sheet for every serial-proven twin among [shown], runs it,
/// and offers one Undo for the whole batch.
Future<void> runBulkRemoveDuplicates(
  BuildContext context,
  WidgetRef ref, {
  required List<QualityFinding> shown,
  required DiveIdentityLabel? Function(String diveId) identityOf,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final service = duplicateCylinderServiceFor(ref);
  final previews = await service.previewAll(service.bulkCandidates(shown));
  if (!context.mounted) return;
  final result = await showDuplicateCylindersSheet(
    context,
    previews: previews,
    identityOf: identityOf,
    run: (onProgress) => service.removeAll(previews, onProgress: onProgress),
  );
  if (result == null) return;
  _showRemovalResult(messenger, l10n, result);
}

void _showRemovalResult(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  DuplicateRemovalResult result,
) {
  final text = [
    l10n.dataQuality_bulk_removeDuplicates_done(result.merged),
    if (result.skippedMixes > 0)
      l10n.dataQuality_bulk_skippedMixes(result.skippedMixes),
    if (result.failed > 0) l10n.dataQuality_bulk_failed(result.failed),
  ].join('. ');
  final operationId = result.operationId;
  messenger.showSnackBar(
    SnackBar(
      duration: inboxDestructiveUndoWindow,
      persist: false,
      content: Text(text),
      action: operationId == null || result.merged == 0
          ? null
          : SnackBarAction(
              label: l10n.dataQuality_action_undo,
              onPressed: () => unawaited(() async {
                await undoChangeLogOperation(operationId);
                // The revert brings the rows back; a rescan reopens what
                // they still raise.
                rescanDives(result.diveIds);
              }()),
            ),
    ),
  );
}

/// Confirms and dismisses every finding the inbox shows, with an Undo that
/// reopens exactly those.
Future<void> runDismissAllShown(
  BuildContext context,
  WidgetRef ref, {
  required List<QualityFinding> shown,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ids = [for (final f in shown) f.id];
  if (ids.isEmpty) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.dataQuality_dismissAll_title(ids.length)),
      content: Text(l10n.dataQuality_dismissAll_body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.dataQuality_dismissAll_confirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final findings = ref.read(qualityFindingsRepositoryProvider);
  await findings.dismissAll(ids);
  messenger.showSnackBar(
    SnackBar(
      duration: inboxDestructiveUndoWindow,
      persist: false,
      content: Text(l10n.dataQuality_dismissAll_done(ids.length)),
      action: SnackBarAction(
        label: l10n.dataQuality_action_undo,
        onPressed: () => unawaited(findings.reopenAll(ids)),
      ),
    ),
  );
}

/// The toolbar's bulk removal button, or null when [shown] holds no
/// serial-proven twin.
Widget? bulkRemoveDuplicatesButton(
  BuildContext context,
  WidgetRef ref, {
  required List<QualityFinding> shown,
  required DiveIdentityLabel? Function(String diveId) identityOf,
}) {
  final dives = bulkDuplicateDiveCount(shown);
  if (dives == 0) return null;
  return IconButton(
    key: bulkRemoveDuplicatesKey,
    icon: const Icon(Icons.layers_clear_outlined),
    tooltip: context.l10n.dataQuality_bulk_removeDuplicates(dives),
    onPressed: () => runBulkRemoveDuplicates(
      context,
      ref,
      shown: shown,
      identityOf: identityOf,
    ),
  );
}

/// The toolbar's overflow menu with Dismiss all shown, or null when nothing
/// is shown.
Widget? inboxOverflowMenu(
  BuildContext context,
  WidgetRef ref, {
  required List<QualityFinding> shown,
}) {
  if (shown.isEmpty) return null;
  return PopupMenuButton<void>(
    key: inboxOverflowMenuKey,
    itemBuilder: (menuContext) => [
      PopupMenuItem<void>(
        onTap: () => runDismissAllShown(context, ref, shown: shown),
        child: Text(
          context.l10n.dataQuality_action_dismissAllShown(shown.length),
        ),
      ),
    ],
  );
}
