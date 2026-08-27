import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_source_badge.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _location = GeoPoint(37.83, -122.42);

Future<Widget> _host(TideDataSource? source) async {
  final overrides = await getBaseOverrides();
  return ProviderScope(
    overrides: [
      ...overrides,
      tideDataSourceProvider(_location).overrideWith((ref) async => source),
    ],
    child: const MaterialApp(
      // Pinned: flutter_test forwards the HOST machine's locales, and
      // these tests assert English literals.
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: TideSourceBadge(location: _location)),
    ),
  );
}

void main() {
  testWidgets('station tier shows station name and distance', (tester) async {
    // Simulate a non-English host to prove the locale pin holds: without
    // `locale: Locale('en')` this run would resolve to French.
    tester.platformDispatcher.localesTestValue = const [
      Locale('fr'),
      Locale('en'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      await _host(
        const TideDataSource.noaaStation(
          stationId: '9414290',
          stationName: 'San Francisco',
          distanceKm: 5.2,
          mllwDatum: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('NOAA station'), findsOneWidget);
    expect(find.textContaining('San Francisco'), findsOneWidget);
    // Default settings are metric: 5.2 km renders via formatGeoDistance.
    expect(find.textContaining('km'), findsOneWidget);
  });

  testWidgets('model tier shows estimate label and caveat on tap', (
    tester,
  ) async {
    await tester.pumpWidget(await _host(const TideDataSource.fesModel()));
    await tester.pumpAndSettle();

    expect(find.text('Ocean-model estimate'), findsOneWidget);

    await tester.tap(find.text('Ocean-model estimate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Modeled from satellite data'), findsOneWidget);
    expect(find.textContaining('relative to mean sea level'), findsOneWidget);
  });

  testWidgets('null source renders nothing', (tester) async {
    await tester.pumpWidget(await _host(null));
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });
}
