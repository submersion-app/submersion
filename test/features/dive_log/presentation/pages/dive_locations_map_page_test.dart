import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_locations_map_page.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('renders an interactive map with entry/exit/site markers', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveLocationsMapPage(
            title: 'Dive Locations',
            entry: GeoPoint(12.34567, 98.76543),
            exit: GeoPoint(12.34612, 98.76489),
            site: GeoPoint(12.34000, 98.76000),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Dive Locations'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-site-marker')), findsOneWidget);
  });
}
