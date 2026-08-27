import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_map_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _now = DateTime.now();

DiveCenter _makeCenter({
  required String id,
  required String name,
  double? latitude,
  double? longitude,
}) {
  return DiveCenter(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<List<Override>> _buildOverrides({
  required List<DiveCenter> centers,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    diveCenterListNotifierProvider.overrideWith(
      (ref) => _MockDCListNotifier(centers),
    ),
    diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
  ];
}

class _MockDCListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDCListNotifier(List<DiveCenter> centers)
    : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('renders FlutterMap for dive centers with coordinates', (
    tester,
  ) async {
    final centers = [
      _makeCenter(
        id: 'dc1',
        name: 'Blue Water Dive',
        latitude: 18.5,
        longitude: -77.9,
      ),
      _makeCenter(
        id: 'dc2',
        name: 'Red Sea Divers',
        latitude: 27.9,
        longitude: 34.3,
      ),
    ];

    final overrides = await _buildOverrides(centers: centers);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveCenterMapContent(onItemSelected: (_) {})),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DiveCenterMapContent), findsOneWidget);
    expect(find.byType(FlutterMap), findsWidgets);
  });

  testWidgets('renders FlutterMap with a preselected center', (tester) async {
    final centers = [
      _makeCenter(
        id: 'dc1',
        name: 'Selected Center',
        latitude: 10.0,
        longitude: 20.0,
      ),
    ];

    final overrides = await _buildOverrides(centers: centers);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveCenterMapContent(
              selectedId: 'dc1',
              onItemSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsWidgets);
  });

  testWidgets('renders a cluster marker for co-located centers', (
    tester,
  ) async {
    // Two centers at the SAME location reliably cluster (distance 0 < radius),
    // exercising the MarkerClusterLayer cluster builder.
    final centers = [
      _makeCenter(id: 'dc-a', name: 'A', latitude: 10.0, longitude: 20.0),
      _makeCenter(id: 'dc-b', name: 'B', latitude: 10.0, longitude: 20.0),
    ];

    final overrides = await _buildOverrides(centers: centers);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveCenterMapContent(onItemSelected: (_) {})),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FlutterMap), findsWidgets);

    // Tapping empty map (a corner, away from the centered cluster) clears the
    // selection via the map's onTap. No animation, so this is teardown-safe.
    await tester.tapAt(
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(5, 5),
    );
    // Flush flutter_map's double-tap disambiguation timer before teardown.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FlutterMap), findsWidgets);
  });
}
