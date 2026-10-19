// Issue #3522: storage accounts read by a short name. A row shows the
// diver's nickname or the shortened label, keeps the full address below,
// and Rename sets or clears the nickname.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/features/settings/presentation/pages/connected_accounts_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

const _r2Label =
    'submersion-sync @ 149b84f66d5479265f3e4d4ad4740926.r2.cloudflarestorage.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ConnectedAccountsRepository accounts;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    accounts = ConnectedAccountsRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountProviderRegistryProvider.overrideWithValue(
            AccountProviderRegistry(const []),
          ),
        ],
        child: const MaterialApp(
          // Pinned: the assertions match English strings.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ConnectedAccountsPage(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<domain.ConnectedAccount> addR2(
    WidgetTester tester, {
    String? nickname,
  }) async {
    late domain.ConnectedAccount account;
    await tester.runAsync(() async {
      account = await accounts.create(kind: AccountKind.s3, label: _r2Label);
      if (nickname != null) await accounts.setNickname(account.id, nickname);
    });
    return account;
  }

  Future<void> rename(WidgetTester tester, String name) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await settle(tester);
  }

  Future<String?> nicknameOf(WidgetTester tester, String id) async {
    String? nickname;
    await tester.runAsync(
      () async => nickname = (await accounts.getById(id))!.nickname,
    );
    return nickname;
  }

  testWidgets('an S3 row reads by its short name, the address below', (
    tester,
  ) async {
    await addR2(tester);
    await pumpPage(tester);

    expect(find.text('submersion-sync @ Cloudflare R2'), findsOneWidget);
    expect(find.text(_r2Label), findsOneWidget);
  });

  testWidgets('a nicknamed row reads by its nickname', (tester) async {
    await addR2(tester, nickname: 'Club bucket');
    await pumpPage(tester);

    expect(find.text('Club bucket'), findsOneWidget);
    expect(find.text('submersion-sync @ Cloudflare R2'), findsNothing);
  });

  testWidgets('Rename saves the nickname and the row shows it', (tester) async {
    final account = await addR2(tester);
    await pumpPage(tester);

    await rename(tester, '  Club bucket ');

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Club bucket'), findsOneWidget);
    expect(await nicknameOf(tester, account.id), 'Club bucket');
  });

  testWidgets('Rename starts from the current nickname and offers the '
      'default', (tester) async {
    await addR2(tester, nickname: 'Club bucket');
    await pumpPage(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Club bucket');
    expect(
      find.text('Leave empty to use submersion-sync @ Cloudflare R2'),
      findsOneWidget,
    );
  });

  testWidgets('an empty name goes back to the short name', (tester) async {
    final account = await addR2(tester, nickname: 'Club bucket');
    await pumpPage(tester);

    await rename(tester, '');

    expect(find.text('submersion-sync @ Cloudflare R2'), findsOneWidget);
    expect(await nicknameOf(tester, account.id), isNull);
  });

  testWidgets('the keyboard done action saves the name', (tester) async {
    final account = await addR2(tester);
    await pumpPage(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Club bucket');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(await nicknameOf(tester, account.id), 'Club bucket');
  });

  testWidgets('Cancel leaves the name alone', (tester) async {
    final account = await addR2(tester, nickname: 'Club bucket');
    await pumpPage(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Other');
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Club bucket'), findsOneWidget);
    expect(await nicknameOf(tester, account.id), 'Club bucket');
  });
}

/// The page's providers read the database off the fake clock; let them
/// finish, then rebuild.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}
