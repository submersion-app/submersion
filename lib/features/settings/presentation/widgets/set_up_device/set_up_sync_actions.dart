import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/replace_join_page.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_settings_section.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';

/// How pointing sync at the chosen account ended.
enum SetUpConnect {
  /// Sync now names the account.
  connected,

  /// Sync already named the account and this device has synced with it:
  /// the library is the one the device shares, with nothing to choose.
  inStep,

  /// Sync does not name the account: the switch stopped short.
  failed,
}

/// How the first sync of step 2 ended.
enum SetUpFirstSync {
  /// In step: the library is uploaded or downloaded.
  synced,

  /// Stopped for something the step reads again: the library is locked, or
  /// it was replaced and awaits adoption.
  blocked,

  /// Failed; the sync state says why.
  failed,
}

/// What step 2 of Set up this device does (issue #3482, spec 6.4), each
/// through the code path the Sync page already uses; nothing new is
/// invented about libraries. One object so a test can stand in for it.
class SetUpSyncActions {
  const SetUpSyncActions();

  /// Points sync at [account] (plan ruling 3): the same write the Sync
  /// page's Change makes, with no sync run. Connected only when sync then
  /// names [account] itself: the switch can stop short (an account with no
  /// keys here, a cancelled sign-in) and leave the previous account
  /// selected. The step keeps the account groups watched while it shows.
  Future<SetUpConnect> connect(
    BuildContext context,
    WidgetRef ref,
    AccountGroup account,
  ) async {
    final groups = await ref.read(accountGroupsProvider.future);
    if (!context.mounted) return SetUpConnect.failed;
    final current = currentSyncGroup(groups);
    if (current?.key == account.key &&
        ref.read(selectedCloudProviderTypeProvider) != null) {
      return ref.read(syncStateProvider).lastSync == null
          ? SetUpConnect.connected
          : SetUpConnect.inStep;
    }
    await useAccountForSync(context, ref, account, current: current);
    if (ref.read(selectedCloudProviderTypeProvider) == null) {
      return SetUpConnect.failed;
    }
    // Read again: the switch changes which account carries sync. The usages
    // too, not only the groups: they refresh on the sync event bus, which
    // may not have delivered the switch yet.
    refreshAccountState(ref.invalidate);
    final after = await ref.read(accountGroupsProvider.future);
    return currentSyncGroup(after)?.key == account.key
        ? SetUpConnect.connected
        : SetUpConnect.failed;
  }

  /// The first sync, as Sync now runs it once its Combine question has been
  /// answered (here, by the step's own choice). With [keepInStep], automatic
  /// sync and its launch and resume companions are turned on once it
  /// succeeds; with [realignDiver] (a library downloaded onto an empty
  /// device), the active diver follows the downloaded library.
  Future<SetUpFirstSync> firstSync(
    WidgetRef ref, {
    required bool keepInStep,
    required bool realignDiver,
  }) async {
    await ref.read(syncStateProvider.notifier).performSync();
    final state = ref.read(syncStateProvider);
    if (state.needsPassphrase || state.replaceAwaitingAdoption) {
      return SetUpFirstSync.blocked;
    }
    if (state.status == SyncStatus.error) return SetUpFirstSync.failed;
    if (keepInStep) await _keepInStep(ref);
    if (realignDiver) {
      await realignActiveDiverAfterDataReplace(
        ref.read(sharedPreferencesProvider),
      );
      ref.invalidate(allDiversProvider);
    }
    return SetUpFirstSync.synced;
  }

  /// Automatic sync with its launch and resume companions, as Sync's Keep
  /// devices in step turns them on.
  Future<void> _keepInStep(WidgetRef ref) async {
    final behavior = ref.read(syncBehaviorProvider.notifier);
    await behavior.setAutoSyncEnabled(true);
    await behavior.setSyncOnLaunch(true);
    await behavior.setSyncOnResume(true);
  }

  /// Unlocks an encrypted library; throws for a wrong secret.
  Future<void> unlock(WidgetRef ref, String secret) =>
      unlockSyncLibrary(ref, secret);

  /// Adopts a replaced library through the Sync page's own dialog (a backup
  /// first). True when the library no longer waits for adoption.
  Future<bool> adopt(
    BuildContext context,
    WidgetRef ref,
    LibraryEpochMarker marker,
  ) async {
    await showAdoptReplacedLibraryDialog(context, ref, marker);
    return await ref.read(syncStateProvider.notifier).libraryReplaceInfo() ==
        null;
  }

  /// Replace and join, behind its full-screen page; with [keepInStep],
  /// automatic sync is turned on once the library has replaced the dives,
  /// before the reload.
  Future<ReplaceJoinEnd?> replace(
    BuildContext context,
    WidgetRef ref, {
    required int diveCount,
    required String backupNote,
    required bool keepInStep,
  }) => ReplaceJoinPage.show(
    context,
    diveCount: diveCount,
    backupNote: backupNote,
    onReplaced: keepInStep ? () => _keepInStep(ref) : null,
  );
}
