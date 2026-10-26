// Issue #3513: logbook rules live under Settings > Manage, after Saved
// queries.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('Manage lists Rules after Saved Queries and opens it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final opened = <String>[];
    final router = GoRouter(
      initialLocation: '/settings?selected=manage',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/rules',
          builder: (context, state) {
            opened.add('/rules');
            return const Scaffold(body: Text('rules page'));
          },
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

    expect(find.text('Rules'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Saved Queries')).dy,
      lessThan(tester.getTopLeft(find.text('Rules')).dy),
    );
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    expect(opened, ['/rules']);
  });
}
