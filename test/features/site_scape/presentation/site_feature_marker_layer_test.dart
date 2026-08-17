import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_marker_layer.dart';
import 'package:submersion/features/wrecks/presentation/providers/wreck_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

const _feature = SiteFeature(
  id: 'f-1',
  siteId: 'site-1',
  typeName: 'current',
  name: 'Ebb runs north',
  latitude: 12.15,
  longitude: -68.3,
  bearingDeg: 90,
);

Future<void> _pumpMap(
  WidgetTester tester, {
  required String? siteId,
  List<SiteFeature> features = const [_feature],
  SiteFeatureRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(const AppSettings()),
        ),
        siteFeaturesProvider('site-1').overrideWith((ref) async => features),
        // The edit sheet loads the wreck catalogue for its picker.
        wrecksProvider.overrideWith((ref) async => const []),
        if (repository != null)
          siteFeatureRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(12.15, -68.3),
              initialZoom: 14,
            ),
            children: [SiteFeatureMarkerLayer(siteId: siteId)],
          ),
        ),
      ),
    ),
  );
  // Bounded pumps: flutter_map never settles under flutter_test.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Records what the edit flow asks the repository to do.
class _RecordingFeatureRepository implements SiteFeatureRepository {
  final List<SiteFeature> updated = [];
  final List<String> deleted = [];

  @override
  Future<void> updateFeature(SiteFeature feature) async => updated.add(feature);

  @override
  Future<void> deleteFeature(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('saving from a marker tap writes the edit through', (
    tester,
  ) async {
    final repo = _RecordingFeatureRepository();
    await _pumpMap(tester, siteId: 'site-1', repository: repo);

    await tester.tap(find.byKey(const ValueKey('siteFeatureMarker-f-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.byKey(const ValueKey('siteFeatureNameField')),
      'Flood tide',
    );
    await tester.tap(find.byKey(const ValueKey('siteFeatureSaveButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.updated, hasLength(1));
    expect(repo.updated.single.id, 'f-1');
    expect(repo.updated.single.name, 'Flood tide');
    expect(repo.deleted, isEmpty);
  });

  testWidgets('deleting from a marker tap removes the feature', (tester) async {
    final repo = _RecordingFeatureRepository();
    await _pumpMap(tester, siteId: 'site-1', repository: repo);

    await tester.tap(find.byKey(const ValueKey('siteFeatureMarker-f-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('siteFeatureDeleteButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('siteFeatureDeleteConfirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.deleted, ['f-1']);
    expect(repo.updated, isEmpty);
  });

  testWidgets('dismissing the sheet from a marker writes nothing', (
    tester,
  ) async {
    final repo = _RecordingFeatureRepository();
    await _pumpMap(tester, siteId: 'site-1', repository: repo);

    await tester.tap(find.byKey(const ValueKey('siteFeatureMarker-f-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    Navigator.of(
      tester.element(find.byKey(const ValueKey('siteFeatureSaveButton'))),
    ).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.updated, isEmpty);
    expect(repo.deleted, isEmpty);
  });

  testWidgets('an unknown type still renders a marker', (tester) async {
    await _pumpMap(
      tester,
      siteId: 'site-1',
      features: const [
        SiteFeature(
          id: 'f-1',
          siteId: 'site-1',
          // A type this build does not know, synced from a newer one.
          typeName: 'lavaTube',
          latitude: 12.15,
          longitude: -68.3,
        ),
      ],
    );

    expect(find.byKey(const ValueKey('siteFeatureMarker-f-1')), findsOneWidget);
    expect(find.byIcon(Icons.place), findsOneWidget);
  });

  testWidgets('renders one rotated marker per feature and edits on tap', (
    tester,
  ) async {
    await _pumpMap(tester, siteId: 'site-1');

    final marker = find.byKey(const ValueKey('siteFeatureMarker-f-1'));
    expect(marker, findsOneWidget);
    // A bearing of 90 degrees rotates the glyph a quarter turn.
    final rotate = tester.widget<Transform>(
      find.descendant(of: marker, matching: find.byType(Transform)).first,
    );
    expect(rotate.transform.storage[0], closeTo(math.cos(math.pi / 2), 1e-9));

    await tester.tap(marker);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The shared edit sheet opened for this feature.
    expect(find.byKey(const ValueKey('siteFeatureSaveButton')), findsOneWidget);
  });

  testWidgets('null siteId renders nothing', (tester) async {
    await _pumpMap(tester, siteId: null);
    expect(find.byKey(const ValueKey('siteFeatureMarker-f-1')), findsNothing);
  });

  testWidgets('an empty feature list renders nothing', (tester) async {
    await _pumpMap(tester, siteId: 'site-1', features: const []);
    expect(find.byKey(const ValueKey('siteFeatureMarker-f-1')), findsNothing);
  });
}
