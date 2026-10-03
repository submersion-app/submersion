import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  // Underwater tracks live in the Tracks nav destination (#2833), which
  // supersedes the Manage tile #2804 added (#2398); a second way in to the
  // same list must not come back with a merge.
  testWidgets('Manage has no Underwater Routes tile; Tracks is in the nav', (
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

    // Scroll to the tiles the removed one sat between, so its slot is built.
    await tester.scrollUntilVisible(
      find.text('Species'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Near-miss log'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-manage-nav-routes')),
      findsNothing,
    );
    expect(find.text('Underwater Routes'), findsNothing);
  });
}
