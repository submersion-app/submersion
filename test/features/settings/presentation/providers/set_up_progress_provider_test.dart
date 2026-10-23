import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

AccountGroup _group(AccountKind kind, AccountStatus status) => AccountGroup(
  key: '${kind.name}|row',
  kind: kind,
  label: kind.name,
  rows: const [],
  status: status,
  usages: const [],
  locations: const {},
  roles: const {},
  usagesKnown: true,
  address: kind.name,
  usageRoles: const {},
  rowStatuses: {'row': status},
);

void main() {
  late SharedPreferences prefs;

  Future<ProviderContainer> container({
    Map<String, Object> prefValues = const {},
    List<AccountGroup> groups = const [],
    bool syncEnabled = false,
    DateTime? lastSync,
    bool customFolder = false,
    bool attached = false,
    bool attachLoading = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefValues);
    prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accountGroupsProvider.overrideWith((ref) async => groups),
        isSyncEnabledProvider.overrideWithValue(syncEnabled),
        lastSyncTimeProvider.overrideWithValue(lastSync),
        isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(
          customFolder,
        ),
        mediaStoreAttachedProvider.overrideWith(
          (ref) => attachLoading
              ? Completer<bool>().future
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
    await c.read(accountGroupsProvider.future);
    await c.read(mediaStoreAttachedProvider.future);
    final progress = c.read(setUpProgressProvider);
    expect(progress, isNotNull);
    return progress!;
  }

  test('is null while an input is still loading', () async {
    final c = await container(attachLoading: true);
    expect(c.read(setUpProgressProvider), isNull);
  });

  test('nothing set up opens at the account step', () async {
    final progress = await settle(await container());
    expect(progress.next, SetUpStep.account);
    expect(progress.settled, 0);
    expect(progress.showsSteps, isTrue);
  });

  test('an account sync can use, signed in here, does the account '
      'step', () async {
    final progress = await settle(
      await container(
        groups: [_group(AccountKind.googledrive, AccountStatus.signedIn)],
      ),
    );
    expect(progress.marks[SetUpStep.account], SetUpMark.done);
  });

  test('an account that needs signing in, or one sync cannot use, does '
      'not', () async {
    final progress = await settle(
      await container(
        groups: [
          _group(AccountKind.googledrive, AccountStatus.needsSignIn),
          _group(AccountKind.adobeLightroom, AccountStatus.signedIn),
        ],
      ),
    );
    expect(progress.marks[SetUpStep.account], SetUpMark.next);
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

  test('backups need automatic backups and a copy off this device', () async {
    final autoOnly = await settle(
      await container(prefValues: {'backup_enabled': true}),
    );
    expect(autoOnly.marks[SetUpStep.backups], isNot(SetUpMark.done));

    final cloud = await settle(
      await container(
        prefValues: {'backup_enabled': true, 'backup_cloud_enabled': true},
      ),
    );
    expect(cloud.marks[SetUpStep.backups], SetUpMark.done);

    final folder = await settle(
      await container(
        prefValues: {'backup_enabled': true, 'backup_location': '/backups'},
      ),
    );
    expect(folder.marks[SetUpStep.backups], SetUpMark.done);
  });

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
}
