import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/cross_device_retention_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/cross_device_retention_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Turns "count backups from all devices" on or off (issue #3503). Turning it
/// on lists what the folder would lose and, once the diver confirms, removes
/// exactly that right away. Off just turns it off.
Future<void> setCrossDeviceRetention(
  BuildContext context,
  WidgetRef ref,
  bool on,
) async {
  final notifier = ref.read(backupSettingsProvider.notifier);
  if (!on) return notifier.setCrossDeviceRetentionAccount(null);
  final service = ref.read(backupServiceProvider);
  final key = await service.crossDeviceRetentionAccountKey();
  if (!context.mounted) return;
  await _confirmThenPrune(
    context,
    ref,
    keepCount: ref.read(backupSettingsProvider).retentionCount,
    save: () => notifier.setCrossDeviceRetentionAccount(key),
  );
}

/// Saves a new "Keep" number. Lowering it while the switch is on asks first,
/// with the same list, and prunes right away on confirm; anything else is
/// saved as before.
Future<void> changeRetentionCount(
  BuildContext context,
  WidgetRef ref,
  int count,
) async {
  final notifier = ref.read(backupSettingsProvider.notifier);
  final lowering = count < ref.read(backupSettingsProvider).retentionCount;
  final service = ref.read(backupServiceProvider);
  if (!lowering || !await service.crossDeviceRetentionActive()) {
    return notifier.setRetentionCount(count);
  }
  if (!context.mounted) return;
  await _confirmThenPrune(
    context,
    ref,
    keepCount: count,
    save: () => notifier.setRetentionCount(count),
  );
}

/// Previews a prune to [keepCount], asks when it would remove anything, and
/// on a yes (or when there is nothing to remove) calls [save], then removes
/// exactly the listed backups. A folder that cannot be read changes nothing.
///
/// One at a time: a change started while another is still listing or
/// pruning does nothing, so two plans can never both apply.
Future<void> _confirmThenPrune(
  BuildContext context,
  WidgetRef ref, {
  required int keepCount,
  required Future<void> Function() save,
}) async {
  final busy = ref.read(crossDeviceRetentionBusyProvider.notifier);
  if (ref.read(crossDeviceRetentionBusyProvider)) return;
  busy.set(true);
  try {
    await _confirmThenPruneOnce(context, ref, keepCount: keepCount, save: save);
  } finally {
    busy.set(false);
  }
}

Future<void> _confirmThenPruneOnce(
  BuildContext context,
  WidgetRef ref, {
  required int keepCount,
  required Future<void> Function() save,
}) async {
  final service = ref.read(backupServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final plan = await service.previewCrossDeviceRetention(keepCount);
  if (!context.mounted) return;
  if (plan == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.backup_retention_listFailed)),
    );
    return;
  }
  if (!plan.isEmpty) {
    if (!await showCrossDeviceRetentionDialog(context, plan)) return;
  }
  await save();
  final removed = await service.applyCrossDeviceRetention(plan);
  if (removed > 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.backup_retention_removed(removed))),
    );
  }
  // The page may have closed while the folder was pruned.
  if (context.mounted) ref.invalidate(backupHistoryProvider);
}
