// Issue #3811: when Sign in again is offered, and for which account.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sign_in_again_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/sign_in_again_button.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../support/sign_in_again_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('offersSignInAgain', () {
    FeatureHealth health(DataFeature feature, HealthReason reason) =>
        FeatureHealth(
          feature: feature,
          level: HealthLevel.attention,
          reason: reason,
        );

    test('the two sign-in reasons do', () {
      expect(
        offersSignInAgain(health(DataFeature.sync, HealthReason.syncSignedOut)),
        isTrue,
      );
      expect(
        offersSignInAgain(
          health(DataFeature.backup, HealthReason.backupCloudSignIn),
        ),
        isTrue,
      );
    });

    test('a plain failure does not', () {
      expect(
        offersSignInAgain(health(DataFeature.sync, HealthReason.syncFailed)),
        isFalse,
      );
    });
  });

  group('signInAgainGroupProvider', () {
    Future<AccountGroup?> resolve(
      AccountGroup group, {
      DataFeature feature = DataFeature.sync,
      bool googleAvailable = true,
      bool dropboxConfigured = true,
      BackupCopyTarget copy = const NoCopy(),
    }) async {
      final container = ProviderContainer(
        overrides: [
          accountGroupsProvider.overrideWith((ref) async => [group]),
          backupCopyTargetProvider.overrideWith((ref) async => copy),
          googleDriveAvailableProvider.overrideWith(
            (ref) async => googleAvailable,
          ),
          dropboxConfiguredProvider.overrideWithValue(dropboxConfigured),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        signInAgainGroupProvider(feature).future,
        (_, _) {},
      );
      addTearDown(sub.close);
      return sub.read();
    }

    test('sync offers the account sync uses', () async {
      final group = accountGroup();
      expect((await resolve(group))?.key, group.key);
    });

    test('backup offers the copy account', () async {
      final group = accountGroup(syncs: false);
      expect(
        (await resolve(
          group,
          feature: DataFeature.backup,
          copy: CopyToAccount(group, group.rows.first),
        ))?.key,
        group.key,
      );
    });

    test('an account sync does not use offers nothing', () async {
      expect(await resolve(accountGroup(syncs: false)), isNull);
    });

    test('iCloud has no sign-in to offer', () async {
      expect(await resolve(accountGroup(kind: AccountKind.icloud)), isNull);
    });

    test('a build without Google or Dropbox sign-in offers nothing', () async {
      expect(await resolve(accountGroup(), googleAvailable: false), isNull);
      expect(
        await resolve(
          accountGroup(kind: AccountKind.dropbox),
          dropboxConfigured: false,
        ),
        isNull,
      );
    });

    test('an own server offers its form', () async {
      expect(await resolve(accountGroup(kind: AccountKind.s3)), isNotNull);
    });
  });

  group('SignInAgainButton', () {
    Future<void> pumpButton(
      WidgetTester tester, {
      AccountGroup? group,
      SyncState state = const SyncState(),
      List<AccountGroup>? pressed,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            signInAgainGroupProvider(
              DataFeature.sync,
            ).overrideWith((ref) async => group),
            syncStateProvider.overrideWith((ref) => FakeSyncNotifier(state)),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SignInAgainButton(
                feature: DataFeature.sync,
                onPressed: (g) => pressed?.add(g),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers the action and hands over the account', (tester) async {
      final pressed = <AccountGroup>[];
      final group = accountGroup();
      await pumpButton(tester, group: group, pressed: pressed);

      await tester.tap(find.text('Sign in again'));

      expect(pressed.single.key, group.key);
    });

    testWidgets('shows nothing without an account', (tester) async {
      await pumpButton(tester);

      expect(find.text('Sign in again'), findsNothing);
    });

    testWidgets('shows nothing while sync runs', (tester) async {
      await pumpButton(
        tester,
        group: accountGroup(),
        state: const SyncState(status: SyncStatus.syncing),
      );

      expect(find.text('Sign in again'), findsNothing);
    });
  });
}
