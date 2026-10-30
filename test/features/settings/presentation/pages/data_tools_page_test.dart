// Issue #3482: the four data tools moved off the Data page onto their own
// Data tools page under Advanced, each still opening its own page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/pages/data_tools_page.dart';
import 'package:submersion/features/settings/presentation/widgets/data_row_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<GoRouter> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/settings/data-tools',
      routes: [
        GoRoute(
          path: '/settings/data-tools',
          builder: (context, state) => const DataToolsPage(),
        ),
        for (final path in const [
          '/settings/fix-dive-times',
          '/settings/link-buddy-names',
          '/settings/retype-other-gear',
          '/settings/data-quality',
        ])
          GoRoute(
            path: path,
            builder: (context, state) => Scaffold(body: Text('page $path')),
          ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('lists the four tools and pushes their routes', (tester) async {
    await pumpPage(tester);

    expect(find.text('Data tools'), findsOneWidget);
    // Same row widget as the Data page, so the tools look like its rows.
    expect(find.byType(DataRowTile), findsNWidgets(4));
    for (final title in const [
      'Fix dive times',
      'Link buddy names',
      'Retype gear marked Other',
      'Data quality',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }

    await tester.tap(find.text('Fix dive times'));
    await tester.pumpAndSettle();
    expect(find.text('page /settings/fix-dive-times'), findsOneWidget);
  });

  testWidgets('each tool opens its own page', (tester) async {
    for (final (title, path) in const [
      ('Link buddy names', '/settings/link-buddy-names'),
      ('Retype gear marked Other', '/settings/retype-other-gear'),
      ('Data quality', '/settings/data-quality'),
    ]) {
      await pumpPage(tester);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text('page $path'), findsOneWidget, reason: title);
    }
  });
}
