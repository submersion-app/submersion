import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Ticks on every SyncEventBus event (repository writes that mark records
/// pending: store attach, account create/delete, subscription edits).
final _syncBusTickProvider = StreamProvider.autoDispose<void>(
  (ref) => SyncEventBus.changes,
);

/// This device's pending setup items ("finish setting up this device").
/// Recomputes on every local data write (SyncEventBus watch) and on each
/// fresh listen (autoDispose), so reopening Settings after a sync always
/// reflects newly arrived descriptors; dismiss actions invalidate
/// explicitly for an immediate refresh.
final pendingSetupItemsProvider =
    FutureProvider.autoDispose<List<PendingSetupItem>>((ref) async {
      ref.watch(_syncBusTickProvider);
      final service = PendingSetupService(
        prefs: ref.watch(sharedPreferencesProvider),
        registry: ref.watch(accountProviderRegistryProvider),
      );
      return service.compute();
    });

/// Dismissible "finish setting up this device" card, fed by the synced
/// descriptors (store announcement, account roster). Renders nothing when
/// there is nothing to do, so it can sit permanently at the top of the
/// settings list.
class PendingSetupCard extends ConsumerWidget {
  const PendingSetupCard({super.key, this.margin});

  /// Overrides the default margin. Host surfaces that already pad their
  /// content horizontally (e.g. the Photos & Media hub) pass a
  /// vertical-only margin so the card aligns with their other cards.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pendingSetupItemsProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    return Card(
      margin: margin ?? const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.settings_setup_pendingTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final item in items)
              ListTile(
                dense: true,
                leading: Icon(
                  item.kind == SetupItemKind.mediaStoreAttach
                      ? Icons.cloud_upload_outlined
                      : Icons.account_circle_outlined,
                ),
                title: Text(switch (item.kind) {
                  SetupItemKind.mediaStoreAttach =>
                    l10n.settings_setup_mediaStoreAttach(item.label),
                  SetupItemKind.accountSignIn =>
                    l10n.settings_setup_accountSignIn(item.label),
                }),
                trailing: IconButton(
                  tooltip: l10n.settings_setup_dismiss,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    final service = PendingSetupService(
                      prefs: ref.read(sharedPreferencesProvider),
                      registry: ref.read(accountProviderRegistryProvider),
                    );
                    await service.dismiss(item.key);
                    ref.invalidate(pendingSetupItemsProvider);
                  },
                ),
                onTap: () => context.push(item.route),
              ),
          ],
        ),
      ),
    );
  }
}
