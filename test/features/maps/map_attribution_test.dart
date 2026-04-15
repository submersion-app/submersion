import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

/// Widget tests for [MapAttribution].
///
/// Covers PR review feedback items:
/// 1. Attribution widget must be rendered on each FlutterMap (shipping blocker
///    per OSM, OpenTopoMap, and Esri tile usage policies).
/// 7. A ProviderContainer-style test that flips `mapStyle` and asserts the
///    attribution text reacts accordingly, proving the reactive wiring works.
void main() {
  Widget wrapInMap(List<Override> overrides) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(0, 0),
              initialZoom: 2,
            ),
            children: const [MapAttribution()],
          ),
        ),
      ),
    );
  }

  group('MapAttribution', () {
    testWidgets('renders a RichAttributionWidget', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(wrapInMap(overrides));
      await tester.pumpAndSettle();

      expect(find.byType(RichAttributionWidget), findsOneWidget);
    });

    testWidgets('shows OpenStreetMap attribution by default', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(wrapInMap(overrides));
      await tester.pumpAndSettle();

      final richWidget = tester.widget<RichAttributionWidget>(
        find.byType(RichAttributionWidget),
      );
      final textSource = richWidget.attributions
          .whereType<TextSourceAttribution>()
          .single;
      expect(textSource.text, contains('OpenStreetMap'));
    });

    testWidgets(
      'attribution text updates when mapStyle switches to OpenTopoMap',
      (tester) async {
        final settings = MockSettingsNotifier();
        final overrides = [
          settingsProvider.overrideWith((ref) => settings),
        ];

        await tester.pumpWidget(wrapInMap(overrides));
        await tester.pumpAndSettle();

        // Default is OpenStreetMap.
        var richWidget = tester.widget<RichAttributionWidget>(
          find.byType(RichAttributionWidget),
        );
        expect(
          richWidget.attributions
              .whereType<TextSourceAttribution>()
              .single
              .text,
          contains('OpenStreetMap'),
        );

        // Flip to OpenTopoMap; attribution must react.
        await settings.setMapStyle(MapStyle.openTopoMap);
        await tester.pumpAndSettle();

        richWidget = tester.widget<RichAttributionWidget>(
          find.byType(RichAttributionWidget),
        );
        expect(
          richWidget.attributions
              .whereType<TextSourceAttribution>()
              .single
              .text,
          contains('OpenTopoMap'),
        );
      },
    );

    testWidgets(
      'attribution text updates when mapStyle switches to Esri',
      (tester) async {
        final settings = MockSettingsNotifier();
        final overrides = [
          settingsProvider.overrideWith((ref) => settings),
        ];

        await tester.pumpWidget(wrapInMap(overrides));
        await tester.pumpAndSettle();

        await settings.setMapStyle(MapStyle.esriSatellite);
        await tester.pumpAndSettle();

        final richWidget = tester.widget<RichAttributionWidget>(
          find.byType(RichAttributionWidget),
        );
        expect(
          richWidget.attributions
              .whereType<TextSourceAttribution>()
              .single
              .text,
          contains('Esri'),
        );
      },
    );
  });
}
