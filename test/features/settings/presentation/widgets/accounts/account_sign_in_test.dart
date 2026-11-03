// Issue #3482 phase 2: Sign in again and Add account run each kind's own
// sign-in (spec sections 7.4 and 7.6).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/google_web_client_id_provider.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_web_client_id_store.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/cloud_provider_authenticate.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../../helpers/test_database.dart';
import '../../../../../support/fake_keychain_storage.dart';

class _CancellingProvider extends FakeCloudStorageProvider {
  @override
  Future<void> authenticate() async => throw const CloudAuthCancelled();
}

class _FailingProvider extends FakeCloudStorageProvider {
  @override
  Future<void> authenticate() async =>
      throw const CloudStorageException('network unreachable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  Future<(BuildContext, WidgetRef)> pumpHost(
    WidgetTester tester,
    FakeCloudStorageProvider drive, {
    bool browser = false,
    InMemoryKeychain? keychain,
    String? builtInClientId,
  }) async {
    late BuildContext context;
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudStorageProviderForProvider(
            CloudProviderType.googledrive,
          ).overrideWithValue(drive),
          if (browser) ...[
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
            googleWebClientIdStoreProvider.overrideWithValue(
              GoogleWebClientIdStore(storage: keychain ?? InMemoryKeychain()),
            ),
            googleBuiltInWebClientIdProvider.overrideWithValue(builtInClientId),
          ],
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (c, r, _) {
              context = c;
              ref = r;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    return (context, ref);
  }

  testWidgets('iCloud has no sign in of its own', (tester) async {
    final (context, ref) = await pumpHost(tester, FakeCloudStorageProvider());
    final at = DateTime.utc(2026);
    final group = groupAccounts(
      rows: [
        ConnectedAccount(
          id: 'ic',
          kind: AccountKind.icloud,
          label: 'iCloud',
          createdAt: at,
          updatedAt: at,
        ),
      ],
      statusById: const {'ic': AccountStatus.unavailable},
      localLocationById: const {},
      usagesOf: (_) => const [],
    ).single;
    expect(await signInToGroup(context, ref, group), isFalse);
  });

  testWidgets('adding Google Drive signs in, then records the account', (
    tester,
  ) async {
    final (context, ref) = await pumpHost(tester, FakeCloudStorageProvider());
    final row = await tester.runAsync(
      () => addAccountRow(context, ref, AccountKindOffer.googleDrive),
    );
    expect(row, isNotNull);
    expect(row!.kind, AccountKind.googledrive);
    // Which Google account, as the provider tile showed it (review of
    // #3527).
    final stored = await tester.runAsync(
      () => ConnectedAccountsRepository().getById(row.id),
    );
    expect(stored!.accountIdentifier, 'tester@example.com');
  });

  // Review of #3527: a failed sign-in is said, as the provider tile said
  // it; before, the sheet just came back with nothing.
  testWidgets('a failed Google sign-in says why', (tester) async {
    final (context, ref) = await pumpHost(tester, _FailingProvider());
    final row = await tester.runAsync(
      () => addAccountRow(context, ref, AccountKindOffer.googleDrive),
    );
    await tester.pump();
    expect(row, isNull);
    expect(find.textContaining('network unreachable'), findsOneWidget);
  });

  testWidgets('a cancelled Google sign-in adds nothing', (tester) async {
    final (context, ref) = await pumpHost(tester, _CancellingProvider());
    final row = await tester.runAsync(
      () => addAccountRow(context, ref, AccountKindOffer.googleDrive),
    );
    expect(row, isNull);
    expect(
      await tester.runAsync(() => ConnectedAccountsRepository().getAll()),
      isEmpty,
    );
  });

  group('in a browser (#4121)', () {
    testWidgets('asks for the Google client id first; cancel adds nothing', (
      tester,
    ) async {
      final drive = FakeCloudStorageProvider()..authenticated = false;
      final (context, ref) = await pumpHost(tester, drive, browser: true);
      final pending = addAccountRow(context, ref, AccountKindOffer.googleDrive);
      await tester.pumpAndSettle();
      expect(find.text('Google client id'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await pending, isNull);
      expect(drive.authenticated, isFalse);
    });

    testWidgets('with a stored client id the sign-in runs without asking', (
      tester,
    ) async {
      final keychain = InMemoryKeychain()
        ..values[GoogleWebClientIdStore.key] =
            '433819313354-abc123def.apps.googleusercontent.com';
      final (context, ref) = await pumpHost(
        tester,
        FakeCloudStorageProvider(),
        browser: true,
        keychain: keychain,
      );
      final row = await tester.runAsync(
        () => addAccountRow(context, ref, AccountKindOffer.googleDrive),
      );
      expect(row, isNotNull);
      expect(find.text('Google client id'), findsNothing);
    });

    testWidgets('on the site the built-in client id belongs to, the sign-in '
        'runs without asking', (tester) async {
      final (context, ref) = await pumpHost(
        tester,
        FakeCloudStorageProvider(),
        browser: true,
        builtInClientId: '433819313354-official.apps.googleusercontent.com',
      );
      final row = await tester.runAsync(
        () => addAccountRow(context, ref, AccountKindOffer.googleDrive),
      );
      expect(row, isNotNull);
      expect(find.text('Google client id'), findsNothing);
    });
  });
}
