import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_row_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

const _pinnedCopy = {
  'backup_enabled': true,
  'backup_cloud_enabled': true,
  'backup_copy_account_id': 'acc-1',
  'backup_copy_account_kind': 'googledrive',
};

void main() {
  late SharedPreferences prefs;

  Future<ProviderContainer> container({
    Map<String, Object> prefValues = const {},
    bool syncEnabled = false,
    DateTime? lastSync,
    bool customFolder = false,
    bool folderDeviceOnly = false,
    bool attached = false,
    bool attachLoading = false,
    bool attachFails = false,
    bool copyRowOnRoster = true,
    bool storageLoaded = true,
    bool restoringSyncAccount = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefValues);
    prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isSyncEnabledProvider.overrideWithValue(syncEnabled),
        lastSyncTimeProvider.overrideWithValue(lastSync),
        isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(
          customFolder,
        ),
        syncFolderIsDeviceOnlyProvider.overrideWithValue(folderDeviceOnly),
        storageConfigLoadedProvider.overrideWithValue(storageLoaded),
        restoreLastProviderProvider.overrideWith(
          (ref) =>
              restoringSyncAccount ? Completer<void>().future : Future.value(),
        ),
        copyRowOnRosterProvider.overrideWith(
          (ref, id) async => copyRowOnRoster,
        ),
        mediaStoreAttachedProvider.overrideWith(
          (ref) => attachLoading
              ? Completer<bool>().future
              : attachFails
              ? Future<bool>.error(StateError('prefs'))
              : Future<bool>.value(attached),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Reads the progress once every input has loaded.
  Future<SetUpProgress> settle(ProviderContainer c) async {
    final sub = c.listen(setUpProgressProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(restoreLastProviderProvider.future);
    await c.read(mediaStoreAttachedProvider.future);
    final pinned = c.read(pinnedCopyAccountIdProvider);
    if (pinned != null) await c.read(copyRowOnRosterProvider(pinned).future);
    final progress = c.read(setUpProgressProvider);
    expect(progress, isNotNull);
    return progress!;
  }

  group('is null while an input is still loading', () {
    test('the attach state', () async {
      final c = await container(attachLoading: true);
      expect(c.read(setUpProgressProvider), isNull);
    });

    // Issue #3482 review: the storage location and the restored sync account
    // start out unloaded; reading them early would show a done step as
    // outstanding for a moment.
    test('the storage location', () async {
      final c = await container(storageLoaded: false);
      await c.read(restoreLastProviderProvider.future);
      await c.read(mediaStoreAttachedProvider.future);
      expect(c.read(setUpProgressProvider), isNull);
    });

    test('the restored sync account', () async {
      final c = await container(restoringSyncAccount: true);
      await c.read(mediaStoreAttachedProvider.future);
      expect(c.read(setUpProgressProvider), isNull);
    });
  });

  test('nothing set up opens at the account step', () async {
    final progress = await settle(await container());
    expect(progress.next, SetUpStep.account);
    expect(progress.settled, 0);
    expect(progress.showsSteps, isTrue);
  });

  test('an account in use here does the account step: sync names one, the '
      'backup copy is pinned to one, or photos are attached', () async {
    final sync = await settle(await container(syncEnabled: true));
    expect(sync.marks[SetUpStep.account], SetUpMark.done);

    final pinned = await settle(await container(prefValues: _pinnedCopy));
    expect(pinned.marks[SetUpStep.account], SetUpMark.done);

    final attached = await settle(await container(attached: true));
    expect(attached.marks[SetUpStep.account], SetUpMark.done);
  });

  // Issue #3482 review: a pin left from before the copy was turned off never
  // counts, as for every other reader of the pin.
  test('a pin left with the copy off is no account in use', () async {
    final progress = await settle(
      await container(
        prefValues: {
          'backup_cloud_enabled': false,
          'backup_copy_account_id': 'acc-1',
          'backup_copy_account_kind': 'googledrive',
        },
      ),
    );
    expect(progress.marks[SetUpStep.account], SetUpMark.next);
  });

  // The card sits on the Settings root and the Data page, which never ask an
  // account for its sign-in state.
  test('no account is probed', () async {
    final c = await container(syncEnabled: true);
    await settle(c);
    expect(c.exists(accountGroupsProvider), isFalse);
  });

  test('a failed attach read counts as not attached, and still shows the '
      'card', () async {
    final c = await container(attachFails: true);
    final sub = c.listen(setUpProgressProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(restoreLastProviderProvider.future);
    await expectLater(
      c.read(mediaStoreAttachedProvider.future),
      throwsA(anything),
    );
    final progress = c.read(setUpProgressProvider);
    expect(progress, isNotNull);
    expect(progress!.marks[SetUpStep.photos], isNot(SetUpMark.done));
  });

  test('sync needs an account selected and a completed sync', () async {
    final selectedOnly = await settle(await container(syncEnabled: true));
    expect(selectedOnly.marks[SetUpStep.sync], isNot(SetUpMark.done));

    final synced = await settle(
      await container(syncEnabled: true, lastSync: DateTime(2026, 10, 1)),
    );
    expect(synced.marks[SetUpStep.sync], SetUpMark.done);
  });

  test('a custom database folder settles account and sync', () async {
    final progress = await settle(await container(customFolder: true));
    expect(progress.marks[SetUpStep.account], SetUpMark.done);
    expect(progress.marks[SetUpStep.sync], SetUpMark.done);
  });

  // Issue #3482 review: on Android a custom folder is a device volume that
  // no service keeps in step; the Sync row reads "Only on this device".
  test('a device-only custom folder settles neither', () async {
    final progress = await settle(
      await container(customFolder: true, folderDeviceOnly: true),
    );
    expect(progress.marks[SetUpStep.account], SetUpMark.next);
    expect(progress.marks[SetUpStep.sync], SetUpMark.notYet);
  });

  test('backups need automatic backups and a copy off this device', () async {
    final autoOnly = await settle(
      await container(prefValues: {'backup_enabled': true}),
    );
    expect(autoOnly.marks[SetUpStep.backups], isNot(SetUpMark.done));

    final nowhere = await settle(
      await container(
        prefValues: {'backup_enabled': true, 'backup_cloud_enabled': true},
      ),
    );
    expect(
      nowhere.marks[SetUpStep.backups],
      isNot(SetUpMark.done),
      reason: 'a copy that follows sync, with sync off, goes nowhere',
    );

    final followsSync = await settle(
      await container(
        syncEnabled: true,
        prefValues: {'backup_enabled': true, 'backup_cloud_enabled': true},
      ),
    );
    expect(followsSync.marks[SetUpStep.backups], SetUpMark.done);

    final pinned = await settle(await container(prefValues: _pinnedCopy));
    expect(pinned.marks[SetUpStep.backups], SetUpMark.done);

    final folder = await settle(
      await container(
        prefValues: {'backup_enabled': true, 'backup_location': '/backups'},
      ),
    );
    expect(folder.marks[SetUpStep.backups], SetUpMark.done);
  });

  // Issue #3482 review: a copy pinned to an account the roster no longer has
  // uploads nowhere (the backup reports its copy missing).
  test(
    'a copy pinned to a removed account does not leave the device',
    () async {
      final progress = await settle(
        await container(prefValues: _pinnedCopy, copyRowOnRoster: false),
      );
      expect(progress.marks[SetUpStep.backups], isNot(SetUpMark.done));
      expect(progress.marks[SetUpStep.account], SetUpMark.next);
    },
  );

  test('photos are done when attached here, settled when skipped', () async {
    final attached = await settle(await container(attached: true));
    expect(attached.marks[SetUpStep.photos], SetUpMark.done);

    final skipped = await settle(
      await container(prefValues: {SetUpCardPrefs.photosSkippedKey: true}),
    );
    expect(skipped.marks[SetUpStep.photos], SetUpMark.skipped);
  });

  test('a hidden card shows no steps', () async {
    final c = await container(prefValues: {SetUpCardPrefs.hiddenKey: true});
    expect((await settle(c)).showsSteps, isFalse);
  });

  // Issue #3482 review: opening Settings > Data reloads the backup settings
  // from disk, which assigns a new but equal value; that must not rebuild the
  // card or the page.
  test('a reload that changes nothing notifies no one', () async {
    final c = await container(prefValues: {'backup_enabled': true});
    await settle(c);
    var notified = 0;
    final sub = c.listen(setUpProgressProvider, (_, _) => notified++);
    addTearDown(sub.close);

    await c.read(backupSettingsProvider.notifier).reloadFromDisk();
    await Future<void>.delayed(Duration.zero);

    expect(notified, 0);
  });
}
