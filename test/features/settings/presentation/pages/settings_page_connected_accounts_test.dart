// Issue #3388: Connected Accounts is its own entry on Settings > Data, in the
// Backup & Sync group with the features that use the accounts, not only
// inside Photos & Media.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pumpDataSection(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/settings?selected=data',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
          routes: [
            GoRoute(
              path: 'connected-accounts',
              builder: (context, state) =>
                  const Scaffold(body: Text('accounts page')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: await getBaseOverrides(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('Connected Accounts sits in the Backup & Sync group', (
    tester,
  ) async {
    await pumpDataSection(tester);

    // The Data page is flat (issue #3390): the group is the rows between
    // the Backup & Sync and Storage headers.
    expect(find.text('Connected Accounts'), findsOneWidget);
    expect(
      topOf(tester, 'Connected Accounts'),
      greaterThan(topOf(tester, 'Photos & Media')),
    );
    expect(
      topOf(tester, 'Connected Accounts'),
      lessThan(topOf(tester, 'Storage')),
    );
  });

  testWidgets('tapping it opens the Connected Accounts page', (tester) async {
    await pumpDataSection(tester);

    await tester.tap(find.text('Connected Accounts'));
    await tester.pumpAndSettle();

    expect(find.text('accounts page'), findsOneWidget);
  });
}
