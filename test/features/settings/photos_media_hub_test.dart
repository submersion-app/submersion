import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/features/settings/presentation/pages/connected_accounts_page.dart';
import 'package:submersion/features/settings/presentation/pages/photos_media_hub_page.dart';
import 'package:submersion/features/settings/presentation/pages/photos_media_setup_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/test_database.dart';

class _FixedStatusAdapter extends AccountProviderAdapter {
  _FixedStatusAdapter(this.kind, this.result);

  @override
  final AccountKind kind;
  final AccountStatus result;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async => result;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => tearDownTestDatabase());

  Widget app(Widget home) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      accountProviderRegistryProvider.overrideWithValue(
        AccountProviderRegistry([
          _FixedStatusAdapter(AccountKind.s3, AccountStatus.needsSignIn),
        ]),
      ),
    ],
    child: MaterialApp(
      // Pinned: the assertions match English strings.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  testWidgets('hub shows the two layer groups and the accounts entry', (
    tester,
  ) async {
    await tester.pumpWidget(app(const PhotosMediaHubPage()));
    await tester.pump();

    expect(find.text('Where photos come from'), findsOneWidget);
    expect(find.text('Where copies are kept'), findsOneWidget);
    expect(find.text('Connected Accounts'), findsOneWidget);
    expect(find.text('Network sources'), findsOneWidget);
  });

  testWidgets('setup guide renders three steps with live status', (
    tester,
  ) async {
    await tester.pumpWidget(app(const PhotosMediaSetupPage()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Photo sources'), findsOneWidget);
    expect(find.text('Media storage'), findsOneWidget);
    expect(find.text('Cloud sync'), findsOneWidget);
    expect(find.text('Not set up'), findsNWidgets(3));
  });

  testWidgets('connected accounts page lists an account with status', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      final repo = container.read(connectedAccountsRepositoryProvider);
      await repo.create(kind: AccountKind.s3, label: 'My MinIO');
    });

    await tester.pumpWidget(app(const ConnectedAccountsPage()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('My MinIO'), findsOneWidget);
    expect(find.textContaining('Needs sign-in'), findsOneWidget);
  });

  testWidgets('connected accounts page shows the empty state', (tester) async {
    await tester.pumpWidget(app(const ConnectedAccountsPage()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('No accounts connected yet'), findsOneWidget);
  });
}
