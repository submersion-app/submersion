// The Visibility scale row in Settings > Units says what the setting controls
// before the diver opens it, instead of showing only the preset name.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Widget buildUnitsSection(List<Override> overrides) {
    final router = GoRouter(
      initialLocation: '/settings?selected=units',
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

  testWidgets('the Visibility scale row describes what it controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildUnitsSection(await getBaseOverrides()));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Visibility scale'),
        matching: find.byType(ListTile),
      ),
    );
    expect(
      (tile.subtitle! as Text).data,
      'How dive details and statistics describe the visibility you measured',
    );
    // The active preset still shows as the row's value.
    expect(find.text('Tropical'), findsOneWidget);
  });
}
