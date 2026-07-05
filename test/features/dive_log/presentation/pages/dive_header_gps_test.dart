import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Dive _diveWithGps({GeoPoint? entry, GeoPoint? exit}) => Dive(
  id: 'gps-dive',
  diveNumber: 1,
  dateTime: DateTime(2026, 5, 22, 9, 14),
  entryTime: DateTime(2026, 5, 22, 9, 14),
  exitTime: DateTime(2026, 5, 22, 9, 52),
  maxDepth: 30.0,
  entryLocation: entry,
  exitLocation: exit,
);

Dive _diveWithSite() => Dive(
  id: 'site-dive',
  diveNumber: 2,
  dateTime: DateTime(2026, 5, 22, 9, 14),
  maxDepth: 30.0,
  site: const DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    location: GeoPoint(17.3161, -87.5347),
  ),
);

Future<void> _pump(WidgetTester tester, Dive dive) async {
  final overrides = await getBaseOverrides();
  // These tests probe the HEADER map; collapse the Surface GPS section
  // (expanded by default) so its map does not double the FlutterMap count.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(DiveDetailUiKeys.surfaceGpsSectionExpanded, false);
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveProvider(dive.id).overrideWith((ref) async => dive),
        diveDataSourcesProvider(
          dive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: dive.id, embedded: true),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = originalOnError;
}

void main() {
  testWidgets('header renders a map with a drift polyline when entry+exit GPS '
      'present and no site', (tester) async {
    await _pump(
      tester,
      _diveWithGps(
        entry: const GeoPoint(12.34567, 98.76543),
        exit: const GeoPoint(12.34612, 98.76489),
      ),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsOneWidget);
  });

  testWidgets('header shows no map when there is neither a site nor GPS', (
    tester,
  ) async {
    await _pump(tester, _diveWithGps());

    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('entry-only dive shows the map but no drift polyline', (
    tester,
  ) async {
    await _pump(
      tester,
      _diveWithGps(entry: const GeoPoint(12.34567, 98.76543)),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsNothing);
  });

  testWidgets('exit-only dive centers on exit and shows only the exit marker', (
    tester,
  ) async {
    await _pump(tester, _diveWithGps(exit: const GeoPoint(12.34612, 98.76489)));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsNothing);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsOneWidget);
  });

  testWidgets('site without GPS renders the map with a View Site affordance', (
    tester,
  ) async {
    await _pump(tester, _diveWithSite());

    expect(find.byType(FlutterMap), findsOneWidget);
    // No drift line or GPS markers when the location comes from the site.
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsNothing);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsNothing);
    // The site affordance (badge + semantics) is present.
    expect(find.text('View Site'), findsWidgets);
  });
}
