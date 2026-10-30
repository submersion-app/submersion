import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Ticks on every SyncEventBus event (repository writes that mark records
/// pending: store attach, account create/delete, subscription edits).
///
/// Each tick is a new number: a provider whose value does not change
/// notifies no one, so a stream of identical nulls refreshed the card once
/// after it opened and never again (issue #2304).
final _syncBusTickProvider = StreamProvider.autoDispose<int>((ref) {
  var tick = 0;
  return SyncEventBus.changes.map((_) => ++tick);
});

/// Ticks when the media store marker mismatch flag may have changed, which
/// is device-local and so never reaches the sync event bus. Each tick is a
/// new number: a provider whose value does not change notifies no one, so a
/// stream of identical nulls would refresh the card once and never again.
final _markerMismatchTickProvider = StreamProvider.autoDispose<int>((ref) {
  var tick = 0;
  return MediaStoreAttachState.markerMismatchChanges.map((_) => ++tick);
});

/// This device's pending setup items ("finish setting up this device").
/// Recomputes on every local data write (SyncEventBus watch), whenever the
/// media store marker mismatch flag changes, and on each fresh listen
/// (autoDispose), so reopening Settings after a sync always reflects newly
/// arrived descriptors and a mismatch found while it is open shows at once;
/// dismiss actions invalidate explicitly for an immediate refresh.
///
/// Not retried: Riverpod retries a thrown Exception (a keychain
/// PlatformException) for about 38 seconds, and every Settings > Data row
/// that waits on these items would read "Checking..." all that time. The
/// next tick or visit computes them again anyway.
final pendingSetupItemsProvider =
    FutureProvider.autoDispose<List<PendingSetupItem>>((ref) async {
      ref.watch(_syncBusTickProvider);
      ref.watch(_markerMismatchTickProvider);
      // The backup copy decides which accounts this device uses, and a copy
      // change is a preferences write that fires no bus event.
      ref.watch(
        backupSettingsProvider.select(
          (s) => (s.cloudBackupEnabled, s.copyAccountId),
        ),
      );
      final service = PendingSetupService(
        prefs: ref.watch(sharedPreferencesProvider),
        registry: ref.watch(accountProviderRegistryProvider),
      );
      return service.compute();
    }, retry: (_, _) => null);
