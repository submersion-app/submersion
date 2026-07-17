import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/divelogs/divelogs_credentials.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divelogs_sync/presentation/pages/divelogs_sync_page.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  final diver = Diver(
    id: 'diver-1',
    name: 'Eric',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  late InMemoryKeychain keychain;
  late AccountCredentialsStore credentialsStore;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    keychain = InMemoryKeychain();
    credentialsStore = AccountCredentialsStore(storage: keychain);
  });

  tearDown(() => tearDownTestDatabase());

  Widget host(http.Client mockClient) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      accountCredentialsStoreProvider.overrideWithValue(credentialsStore),
      divelogsHttpClientProvider.overrideWithValue(mockClient),
      allDiversProvider.overrideWith((ref) async => [diver]),
      currentDiverProvider.overrideWith((ref) async => diver),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DivelogsSyncPage(),
    ),
  );

  Map<String, dynamic> divelistEntry(int id, String date, String time) => {
    'id': id,
    'date': date,
    'time': time,
    'duration': 2700,
    'maxdepth': 18,
  };

  /// Seeds a signed-in divelogs account bound to diver-1. Runs BEFORE the
  /// page is pumped (the page resolves the account in initState).
  Future<void> seedAccount() async {
    await DiverRepository().createDiver(diver);
    final account = await ConnectedAccountsRepository().create(
      kind: AccountKind.divelogs,
      label: 'divelogs.de',
      accountIdentifier: 'eric',
      diverId: 'diver-1',
    );
    await credentialsStore.write(
      account.id,
      const DivelogsCredentials(
        username: 'eric',
        password: 'p',
        bearerToken: 'jwt',
      ).toJsonString(),
    );
  }

  Future<void> seedLocalDive(
    String id,
    DateTime at, {
    int? diveNumber,
    Duration runtime = const Duration(seconds: 2700),
    double maxDepth = 18,
  }) async {
    await DiveRepository().createDive(
      Dive(
        id: id,
        diverId: 'diver-1',
        diveNumber: diveNumber,
        dateTime: at,
        entryTime: at,
        runtime: runtime,
        maxDepth: maxDepth,
      ),
    );
  }

  testWidgets('shows connect prompt when no account exists', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        host(MockClient((req) async => fail('no network expected'))),
      );
      await tester.pumpAndSettle();
    });

    expect(
      find.text(
        'No divelogs.de account is connected yet. Start an import to sign in.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open divelogs.de import'), findsOneWidget);
  });

  testWidgets('compare renders pull/push/matched sections', (tester) async {
    final client = MockClient((req) async {
      if (req.url.path == '/api/divelist') {
        return http.Response(
          jsonEncode([
            divelistEntry(1, '2022-09-03', '10:00:00'),
            divelistEntry(2, '2023-01-15', '11:00:00'),
          ]),
          200,
        );
      }
      fail('unexpected request ${req.url}');
    });

    await tester.runAsync(() async {
      await seedAccount();
      await seedLocalDive('local-matched', DateTime.utc(2022, 9, 3, 10));
      await seedLocalDive(
        'local-only',
        DateTime.utc(2022, 10, 1, 9),
        diveNumber: 42,
        runtime: const Duration(seconds: 3000),
        maxDepth: 22,
      );
      await tester.pumpWidget(host(client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compare'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });

    expect(find.text('1 dives already in sync'), findsOneWidget);
    expect(find.text('Pull: 1 new on divelogs.de'), findsOneWidget);
    expect(find.text('Push: 1 dives not on divelogs.de'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });

  testWidgets('push posts selected dives and reports the count', (
    tester,
  ) async {
    var divelistCalls = 0;
    List<dynamic>? postedBody;
    final client = MockClient((req) async {
      if (req.url.path == '/api/divelist') {
        divelistCalls++;
        if (divelistCalls >= 2) {
          // After the push the remote side has the dive too.
          return http.Response(
            jsonEncode([divelistEntry(9, '2022-10-01', '09:00:00')]),
            200,
          );
        }
        return http.Response(jsonEncode([]), 200);
      }
      if (req.url.path == '/api/dives' && req.method == 'POST') {
        postedBody = jsonDecode(req.body) as List;
        return http.Response('{}', 200);
      }
      fail('unexpected request ${req.method} ${req.url}');
    });

    await tester.runAsync(() async {
      await seedAccount();
      await seedLocalDive(
        'local-only',
        DateTime.utc(2022, 10, 1, 9),
        runtime: const Duration(seconds: 3000),
        maxDepth: 22,
      );
      await tester.pumpWidget(host(client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compare'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Push selected'));
      await tester.tap(find.text('Push selected'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    });

    expect(postedBody, isNotNull);
    expect(postedBody, hasLength(1));
    expect(divelistCalls, 2, reason: 'push triggers an automatic re-compare');
    expect(find.textContaining('Pushed 1 dives'), findsOneWidget);
  });
}
