// Issue #3482 phase 2: the WebDAV settings page's form tests, ported to the
// one My own server form that replaced it (spec section 7.5).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/own_server_form.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/fake_webdav_server.dart';
import '../../../../../helpers/test_database.dart';
import '../../../../../support/fake_keychain_storage.dart';

/// Remembers which account the form last wrote, so a test reads its config
/// back from the keychain without a database query racing the form's own.
class _RecordingCredentials extends AccountCredentialsStore {
  _RecordingCredentials() : super(storage: InMemoryKeychain());
  String? lastWritten;

  @override
  Future<void> write(String accountId, String json) {
    lastWritten = accountId;
    return super.write(accountId, json);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeWebDavServer server;
  late WebDavStorageProvider provider;
  late _RecordingCredentials credentials;

  setUp(() async {
    await setUpTestDatabase();
    server = FakeWebDavServer();
    credentials = _RecordingCredentials();
    provider = WebDavStorageProvider(
      store: WebDavCredentialsStore(storage: InMemoryKeychain()),
      clientFactory: (c) => WebDavClient(
        c,
        httpClient: server.client,
        backoff: (_) => Duration.zero,
      ),
    );
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    WebDavConfig? existing,
    WebDavCheck? webdavCheck,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    AccountGroup? group;
    if (existing != null) {
      group = await tester.runAsync(() async {
        final row = await ConnectedAccountsRepository().ensure(
          kind: AccountKind.webdav,
          naturalKey: webdavNaturalKey(existing),
          label: existing.displayLabel,
        );
        await credentials.write(row.id, jsonEncode(existing.toJson()));
        credentials.lastWritten = null;
        return groupAccounts(
          rows: [row],
          statusById: {row.id: AccountStatus.signedIn},
          localLocationById: const {},
          usagesOf: (_) => const [],
        ).single;
      });
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountCredentialsStoreProvider.overrideWithValue(credentials),
          webdavStorageProviderInstanceProvider.overrideWithValue(provider),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: OwnServerForm(
                existing: group,
                kinds: const {AccountKind.webdav},
                webdavCheck: webdavCheck,
                onSaved: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(
    WidgetTester tester, {
    String password = 'secret',
  }) async {
    await tester.enterText(
      find.byKey(const Key('account-webdav-server-url')),
      'https://dav.test/dav',
    );
    await tester.enterText(
      find.byKey(const Key('account-webdav-username')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const Key('account-webdav-password')),
      password,
    );
    await tester.pump();
  }

  testWidgets('asks for the WebDAV address with no server type to pick', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('account-webdav-preset')), findsNothing);
    expect(find.byKey(const Key('account-webdav-server-url')), findsOneWidget);
    expect(find.text('WebDAV address'), findsOneWidget);
    expect(
      find.text(
        "The full WebDAV address from your server's settings, including its path",
      ),
      findsOneWidget,
    );
    expect(
      find.text('Use an app password if the account has two-factor sign-in'),
      findsOneWidget,
    );
  });

  testWidgets('http shows the warning', (tester) async {
    await pumpPage(tester);
    await tester.enterText(
      find.byKey(const Key('account-webdav-server-url')),
      'http://nas.local/dav',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('account-webdav-http-warning')),
      findsOneWidget,
    );
  });

  testWidgets('an address with a query is refused before any request', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('account-webdav-server-url')),
      'https://dav.test/dav?tenant=x',
    );
    await tester.tap(find.byKey(const Key('own-server-check')));
    await tester.pumpAndSettle();
    expect(
      find.text('Remove the part of the address after ? or #'),
      findsOneWidget,
    );
    expect(server.captured, isEmpty);
  });

  testWidgets('a missing, malformed or credentialed address is refused', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    const messages = {
      '': 'Required',
      'dav.test/dav': 'Enter an address starting with https:// or http://',
      'https://alice:secret@dav.test/dav':
          'Put the username and password in their own fields, not in the address',
    };
    for (final MapEntry(key: address, value: message) in messages.entries) {
      await tester.enterText(
        find.byKey(const Key('account-webdav-server-url')),
        address,
      );
      await tester.tap(find.byKey(const Key('own-server-check')));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget, reason: address);
    }
    expect(server.captured, isEmpty);
  });

  testWidgets('Test connection probes the server and reports success', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester); // server https://dav.test/dav, alice, secret
    await tester.tap(find.byKey(const Key('own-server-check')));
    await tester.pumpAndSettle();
    expect(find.text('Connection successful'), findsOneWidget);
    expect(server.collections, contains('/dav/Submersion'));
  });

  testWidgets('a wrong password shows the localized 401 text', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester, password: 'nope');
    await tester.tap(find.byKey(const Key('own-server-check')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The server rejected the username or password'),
      findsOneWidget,
    );
  });

  testWidgets('Save checks the server, then stores it as an account', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('own-server-save')));
    await settle(tester);
    final id = credentials.lastWritten;
    expect(id, isNotNull);
    final raw = await tester.runAsync(() => credentials.read(id!));
    expect(raw, contains('alice'));
    expect(find.text('Account saved'), findsOneWidget);
  });

  // Review of #3527: a library hands out logins that may not write, so
  // the library flows pass a read-only check, and Save must use it instead
  // of the sync settings' write probe.
  testWidgets('Save uses the check it is given, writing nothing', (
    tester,
  ) async {
    final checked = <WebDavConfig>[];
    await pumpPage(
      tester,
      webdavCheck: (config) async {
        checked.add(config);
        return config;
      },
    );
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('own-server-save')));
    await settle(tester);

    expect(checked, hasLength(1));
    expect(server.captured, isEmpty);
    expect(credentials.lastWritten, isNotNull);
  });

  testWidgets('a stored pin shows and can be forgotten', (tester) async {
    await pumpPage(
      tester,
      existing: WebDavConfig(
        serverUrl: 'https://dav.test/dav',
        username: 'alice',
        password: 'secret',
        pinnedCertSha256: 'ab' * 32,
      ),
    );
    expect(find.byKey(const Key('account-webdav-pin-row')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-webdav-forget-pin')));
    await tester.pump();
    expect(find.byKey(const Key('account-webdav-pin-row')), findsNothing);
  });
}
