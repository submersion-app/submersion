// Issue #3482 phase 2: the S3 and WebDAV forms exist once, as "My own
// server" (spec section 7.5).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/own_server_form.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/test_database.dart';
import '../../../../../support/fake_keychain_storage.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

AccountGroup _groupOf(ConnectedAccount row) => groupAccounts(
  rows: [row],
  statusById: {row.id: AccountStatus.needsSignIn},
  localLocationById: const {},
  usagesOf: (_) => const [],
).single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AccountCredentialsStore credentials;

  setUp(() async {
    await setUpTestDatabase();
    credentials = AccountCredentialsStore(storage: InMemoryKeychain());
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> pumpForm(
    WidgetTester tester, {
    AccountGroup? existing,
    Future<void> Function(ConnectedAccount row)? onSaved,
  }) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountCredentialsStoreProvider.overrideWithValue(credentials),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: OwnServerForm(
                existing: existing,
                onSaved: onSaved ?? (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

  testWidgets('saving a new server creates its sync-role account', (
    tester,
  ) async {
    ConnectedAccount? saved;
    await pumpForm(tester, onSaved: (row) async => saved = row);

    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'https://minio.home:9000',
    );
    await tester.enterText(find.byKey(const Key('account-s3-bucket')), 'dives');
    await tester.enterText(
      find.byKey(const Key('account-s3-access-key')),
      'AKIA1',
    );
    await tester.enterText(
      find.byKey(const Key('account-s3-secret-key')),
      'shh',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);

    final expected = S3Config(
      endpoint: 'https://minio.home:9000',
      bucket: 'dives',
      accessKeyId: 'AKIA1',
      secretAccessKey: 'shh',
    );
    expect(saved, isNotNull);
    expect(
      saved!.id,
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(expected)),
    );
    expect(await tester.runAsync(() => credentials.read(saved!.id)), isNotNull);
  });

  testWidgets('signing in again pre-fills everything but the secret', (
    tester,
  ) async {
    final at = DateTime.utc(2026);
    await pumpForm(
      tester,
      existing: _groupOf(
        ConnectedAccount(
          id: 'row',
          kind: AccountKind.s3,
          label: 'dives @ minio.home',
          createdAt: at,
          updatedAt: at,
          location: const S3AccountLocation(
            displayHost: 'minio.home',
            endpoint: 'https://minio.home:9000',
            bucket: 'dives',
            region: 'us-east-1',
            prefix: 'submersion-sync/',
            pathStyle: true,
          ),
        ),
      ),
    );

    expect(text(tester, 'account-s3-endpoint'), 'https://minio.home:9000');
    expect(text(tester, 'account-s3-bucket'), 'dives');
    expect(text(tester, 'account-s3-access-key'), isEmpty);
    expect(text(tester, 'account-s3-secret-key'), isEmpty);
    // The kind is fixed by the account being signed in.
    expect(find.byType(SegmentedButton<AccountKind>), findsNothing);
  });

  testWidgets('an account nothing here can place asks for every detail', (
    tester,
  ) async {
    final at = DateTime.utc(2026);
    await pumpForm(
      tester,
      existing: _groupOf(
        ConnectedAccount(
          id: 'legacy',
          kind: AccountKind.s3,
          label: 'dives @ minio.home',
          createdAt: at,
          updatedAt: at,
        ),
      ),
    );
    expect(text(tester, 'account-s3-endpoint'), isEmpty);
    expect(text(tester, 'account-s3-bucket'), isEmpty);
  });

  testWidgets('a plain-http address shows the warning', (tester) async {
    await pumpForm(tester);
    await tester.enterText(
      find.byKey(const Key('account-s3-endpoint')),
      'http://minio.home:9000',
    );
    await tester.pump();
    expect(find.byKey(const Key('account-s3-http-warning')), findsOneWidget);
  });

  testWidgets('WebDAV is one tap away', (tester) async {
    await pumpForm(tester);
    await tester.tap(find.text('WebDAV'));
    await tester.pump();
    expect(find.byKey(const Key('account-webdav-server-url')), findsOneWidget);
    expect(find.byKey(const Key('account-s3-endpoint')), findsNothing);
  });
}
