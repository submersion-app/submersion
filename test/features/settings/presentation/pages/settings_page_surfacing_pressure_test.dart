// Issue #1092: the diver-facing control for reading cylinder end pressure at
// the moment of surfacing. It lives in Settings > Data, next to the other
// import-interpretation preference.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Widget buildDataSection(List<Override> overrides) {
    final router = GoRouter(
      initialLocation: '/settings?selected=data',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        locale: const Locale('en'),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('the tank pressure at surfacing toggle is on by default', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildDataSection(await getBaseOverrides()));
    await tester.pumpAndSettle();

    expect(find.text('Tank pressure at surfacing'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('Tank pressure at surfacing'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(toggle.value, isTrue);
  });

  testWidgets('turning it off records the diver preference', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final settings = MockSettingsNotifier();
    await tester.pumpWidget(
      buildDataSection(await getBaseOverrides(settingsNotifier: settings)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tank pressure at surfacing'));
    await tester.pumpAndSettle();

    expect(settings.state.trimTankPressureAtSurfacing, isFalse);
  });
}
