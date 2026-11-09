import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/change_log/data/services/change_log_operation_undo.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/remove_source_dialog.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
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
