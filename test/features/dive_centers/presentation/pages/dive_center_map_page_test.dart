import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_map_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockDCListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDCListNotifier(List<DiveCenter> centers)
    : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('renders the DiveCenterMapPage FlutterMap with a center', (
    tester,
  ) async {
    // Phone-sized surface keeps MapListScaffold in mobile mode, which renders
    // only the map pane (no list pane providers to mock).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime(2026, 1, 1);
    final center = DiveCenter(
      id: 'dc1',
      name: 'Blue Water Dive',
      latitude: 18.5,
      longitude: -77.9,
      createdAt: now,
      updatedAt: now,
    );
    // A second center at the SAME location reliably clusters with the first,
    // exercising the MarkerClusterLayer cluster builder.
    final center2 = DiveCenter(
      id: 'dc2',
      name: 'Blue Water Annex',
      latitude: 18.5,
      longitude: -77.9,
      createdAt: now,
      updatedAt: now,
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveCenterListNotifierProvider.overrideWith(
            (ref) => _MockDCListNotifier([center, center2]),
          ),
          diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveCenterMapPage(),
        ),
      ),
    );

    // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FlutterMap), findsWidgets);
  });
}
