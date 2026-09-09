import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/backup/presentation/providers/unrecognized_backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_usage_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Points at backup files the history has lost track of, from the backups
/// group of the Storage usage page.
///
/// Renders nothing at all unless the scan came back with something. A row that
/// said "0 forgotten files" would be noise on every launch for every user whose
/// backups are in order, which is nearly all of them.
///
/// It also hides while the scan is still running, when it failed, and when the
/// location cannot be listed. Hiding is the whole behaviour in those cases:
/// there is no button, so the page is not reachable and says nothing to the
/// user about them. What makes that acceptable is the backups size row directly
/// above, which measures the same directory and already reports "Not available"
/// for a location with no directory behind it and "Could not measure" when the
/// walk fails. A second line here would restate what that row just said, and
/// only for the one category that has a scan.
class UnrecognizedBackupsNotice extends ConsumerWidget {
  const UnrecognizedBackupsNotice({super.key});

  /// Where [_review] navigates. Pinned against the route tree by a test in
  /// `app_router_test.dart`, since go_router resolves an absolute location at
  /// push time and a rename on either side is a runtime failure otherwise.
  static const routeLocation = '/settings/storage-usage/unrecognized-backups';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(unrecognizedBackupsProvider).valueOrNull;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final bytes = entries.fold(0, (sum, entry) => sum + entry.sizeBytes);

    return ListTile(
      leading: Icon(Icons.help_outline, color: theme.colorScheme.primary),
      title: Text(
        context.l10n.settings_storageUsage_unrecognized_title(entries.length),
      ),
      subtitle: Text(formatBytes(bytes)),
      trailing: TextButton(
        onPressed: () => _review(context, ref),
        child: Text(context.l10n.settings_storageUsage_unrecognized_action),
      ),
      onTap: () => _review(context, ref),
    );
  }

  /// Re-measures on the way back rather than having the sub-page reach into
  /// this feature's providers: a reclaim changes what the backups row should
  /// say, and this side of the navigation is where that row lives.
  Future<void> _review(BuildContext context, WidgetRef ref) async {
    await context.push(routeLocation);
    // Checked here as well as inside the callee: the analyzer cannot see a
    // guard on the far side of a call, and use_build_context_synchronously is
    // fatal in CI. The tested guard is the one in the callee.
    if (!context.mounted) return;
    refreshAfterUnrecognizedReview(context, ref);
  }
}

/// Refreshes the rows a reclaim can change, if this notice is still on screen.
///
/// Separate from the push so the guard is reachable from a test. The await on
/// `context.push` has no bound: the sub-page stays open as long as the user
/// reads it, and the Storage usage page underneath can be torn down in that
/// window by a deep link or a shell navigation. A `WidgetRef` whose element has
/// been unmounted throws `StateError` on invalidate, so without this check a
/// tap the user made on a page they have already left surfaces as an unhandled
/// error. There is nothing to refresh in that case either: the rows are gone.
@visibleForTesting
void refreshAfterUnrecognizedReview(BuildContext context, WidgetRef ref) {
  if (!context.mounted) return;
  ref.invalidate(unrecognizedBackupsProvider);
  ref.invalidate(storageCategorySizeProvider(StorageCategoryId.backups));
}
