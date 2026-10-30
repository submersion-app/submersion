import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_upload_progress_provider.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_row_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_row_status_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/device_kind.dart';

/// The screen after the last step of Set up this device (issue #3482, spec
/// 6.4): one line per outcome, in the words the Data page's rows use so the
/// two can never disagree, how the other devices join, and Done.
class SetUpDoneView extends ConsumerStatefulWidget {
  const SetUpDoneView({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<SetUpDoneView> createState() => _SetUpDoneViewState();
}

class _SetUpDoneViewState extends ConsumerState<SetUpDoneView> {
  bool _busy = false;
  bool _queued = false;

  /// Queues every attached photo not yet copied, as Photos' Advanced does
  /// (plan ruling 11), once.
  Future<void> _uploadAll() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final count = await ref.read(mediaBackfillServiceProvider).enqueueAll();
      if (mounted) setState(() => _queued = true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.settings_mediaStorage_backfill_enqueued(count)),
        ),
      );
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      unawaited(runtime?.worker?.drain());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final groups = ref.watch(accountGroupsProvider).value ?? const [];
    final AccountGroup? account =
        ref.watch(setUpFlowProvider) ?? groups.syncing;
    final attached = ref.watch(mediaStoreAttachedProvider).value ?? false;
    final progress = attached
        ? ref.watch(mediaUploadProgressProvider).value
        : null;
    final offerUpload =
        !_queued && progress != null && progress.total > progress.copied;

    Widget outcome(IconData icon, String title, DataRowStatus status) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(dataRowStatusText(l10n, status, now)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.settings_setUpDevice_done_title(
                  deviceKindArg(deviceKindOf(context)),
                ),
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              outcome(
                Icons.account_circle_outlined,
                l10n.settings_connectedAccounts_title,
                ref.watch(accountsRowStatusProvider),
              ),
              outcome(
                Icons.cloud_sync,
                l10n.settings_sync_title,
                ref.watch(syncRowStatusProvider),
              ),
              outcome(
                Icons.backup,
                l10n.settings_backups_title,
                ref.watch(backupsRowStatusProvider),
              ),
              outcome(
                Icons.perm_media_outlined,
                l10n.settings_photosVideos_title,
                ref.watch(photosRowStatusProvider),
              ),
              if (account != null) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.settings_setUpDevice_done_otherDevices(account.label),
                  style: textTheme.bodyMedium,
                ),
              ],
              if (offerUpload) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _uploadAll,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(l10n.settings_photos_uploadAll),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: widget.onDone,
              child: Text(l10n.common_action_done),
            ),
          ),
        ),
      ],
    );
  }
}
