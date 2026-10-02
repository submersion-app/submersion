import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('Manage lists Underwater Routes and opens the routes area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const SettingsSectionDetailPage(sectionId: 'manage'),
        ),
        GoRoute(
          path: '/nav-routes',
          builder: (context, state) =>
              const Scaffold(body: Text('NAV-ROUTES-PAGE')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('settings-manage-nav-routes'));
    await tester.scrollUntilVisible(
      tile,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Underwater Routes')),
      findsOneWidget,
    );
    expect(find.text('Import, align and link recorded routes'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('NAV-ROUTES-PAGE'), findsOneWidget);
  });
}
