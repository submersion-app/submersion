import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_map_page.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';

import '../../../../helpers/mock_providers.dart';

// Exercises only the built-in layer's presence under the toggle. A phone-sized
// surface keeps MapListScaffold in mobile mode (map pane only), and data
// providers are overridden so no database is needed.
void main() {
  testWidgets('built-in pins appear only when the toggle is on', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final base = await getBaseOverrides();
    late final ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          sitesWithCountsProvider.overrideWith((ref) async => []),
          siteCoverageHeatMapProvider.overrideWith(
            (ref) async => <HeatMapPoint>[],
          ),
          visibleBuiltInSitesProvider.overrideWith(
            (ref) async => const [
              // At the page's default center so it is within the zoom-3
              // viewport (the marker cluster layer culls off-screen markers).
              ExternalDiveSite(
                externalId: 'a',
                name: 'A',
                latitude: 20,
                longitude: -157,
                source: 't',
              ),
            ],
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SiteMapPage(),
            );
          },
        ),
      ),
    );

    // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('builtInPin_a')), findsNothing);

    container.read(showBuiltInSitesProvider.notifier).state = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);
  });
}
