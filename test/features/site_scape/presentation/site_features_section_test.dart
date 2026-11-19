import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_features_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

const _features = [
  SiteFeature(
    id: 'f-1',
    siteId: 'site-1',
    typeName: 'mooring',
    latitude: 12.15,
    longitude: -68.3,
    depthMeters: 6,
  ),
  SiteFeature(
    id: 'f-2',
    siteId: 'site-1',
    typeName: 'wreck',
    name: 'Hilma Hooker',
    latitude: 12.16,
    longitude: -68.31,
  ),
];

/// Pumps the section.
Future<void> _pumpSection(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  List<SiteFeature> features = _features,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
        siteFeaturesProvider('site-1').overrideWith((ref) async => features),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SiteFeaturesSection(siteId: 'site-1')),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('lists features with type labels and depth in display units', (
    tester,
  ) async {
    await _pumpSection(tester);

    // A named feature shows its name; an unnamed one falls back to the
    // type label.
    expect(find.text('Hilma Hooker'), findsOneWidget);
    expect(find.text('Mooring'), findsOneWidget);
    // Depth rides the subtitle in the diver's unit.
    expect(find.textContaining('6 m'), findsOneWidget);
  });

  testWidgets('an unknown type shows its raw name rather than vanishing', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      features: const [
        SiteFeature(
          id: 'f-9',
          siteId: 'site-1',
          // Synced from a newer build whose vocabulary this one lacks.
          typeName: 'lavaTube',
          latitude: 12.15,
          longitude: -68.3,
        ),
      ],
    );

    expect(find.text('lavaTube'), findsWidgets);
  });

  testWidgets('a feet diver reads depths in feet', (tester) async {
    await _pumpSection(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
    // 6 m is 19.7 ft.
    expect(find.textContaining('19.7 ft'), findsOneWidget);
  });

  // The Features card's editor adds and changes them, in a sitting (issue
  // #4527, phase 2): the list itself offers neither.
  testWidgets('the list offers no add and no edit', (tester) async {
    await _pumpSection(tester);
    expect(find.text('Hilma Hooker'), findsOneWidget);
    expect(find.byKey(const ValueKey('siteFeatureAddButton')), findsNothing);
    await tester.tap(find.text('Hilma Hooker'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
