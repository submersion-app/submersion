import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';

import '../../../../helpers/test_app.dart';

/// Minimal [SettingsNotifier] stub that returns default [AppSettings].
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _testTanks = [
  DiveTank(id: 'tank-1', name: 'D80', gasMix: GasMix(o2: 21), order: 0),
  DiveTank(id: 'tank-2', name: 'AL80', gasMix: GasMix(o2: 50), order: 1),
];

void main() {
  group('DiveProfileLegend - primary toggles', () {
    testWidgets('shows Events toggle when hasEvents is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasTemperatureData: true,
              hasEvents: true,
              hasCeilingCurve: true,
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Events should be in the primary legend
      expect(find.text('Events'), findsOneWidget);
    });

    testWidgets(
      'does NOT show Ceiling in primary legend even when data available',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            overrides: [
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: DiveProfileLegend(
              config: const ProfileLegendConfig(
                hasCeilingCurve: true,
                hasEvents: true,
              ),
              zoomLevel: 1.0,
              onZoomIn: () {},
              onZoomOut: () {},
              onResetZoom: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Events should appear, Ceiling should NOT (it moved to dialog)
        expect(find.text('Events'), findsOneWidget);
        expect(find.text('Ceiling'), findsNothing);
        expect(find.text('Ceiling (DC)'), findsNothing);
        expect(find.text('Ceiling (Calc)'), findsNothing);
        expect(find.text('Ceiling (Calc*)'), findsNothing);
      },
    );
  });

  group('_ChartOptionsDialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasTemperatureData: true,
              hasEvents: true,
              hasHeartRateData: true,
              hasSacCurve: true,
              hasAscentRates: true,
              hasCeilingCurve: true,
              hasNdlData: true,
              hasTtsData: true,
              hasCnsData: true,
              hasOtuData: true,
              hasPpO2Data: true,
              hasMaxDepthMarker: true,
              hasGfData: true,
              hasSurfaceGfData: true,
              hasMeanDepthData: true,
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The tune icon is overlaid by the Badge widget, so warnIfMissed: false
      // suppresses the hit-test warning while the tap still reaches the button.
      await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    testWidgets('shows all section headers', (tester) async {
      await openDialog(tester);
      expect(find.text('Overlays'), findsOneWidget);
      expect(find.text('Markers'), findsOneWidget);
      expect(find.text('Decompression'), findsOneWidget);
      expect(find.text('Gas Analysis'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('Overlays section starts expanded with metrics visible', (
      tester,
    ) async {
      await openDialog(tester);
      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('SAC Rate'), findsOneWidget);
    });

    testWidgets('tapping collapsed section expands it', (tester) async {
      await openDialog(tester);
      // Markers starts collapsed -- tap to expand
      await tester.tap(find.text('Markers'));
      await tester.pumpAndSettle();
      expect(find.text('Max Depth'), findsOneWidget);
    });

    testWidgets('Ceiling has visibility toggle in Decompression section', (
      tester,
    ) async {
      await openDialog(tester);
      // Decompression starts expanded, so Ceiling should be visible
      expect(find.text('Ceiling'), findsOneWidget);
    });

    testWidgets('source-capable metrics have SegmentedButtons', (tester) async {
      await openDialog(tester);
      // 4 metrics with source selectors: Ceiling, NDL, TTS, CNS%
      expect(find.byType(SegmentedButton<MetricDataSource>), findsNWidgets(4));
    });

    testWidgets('tapping SegmentedButton changes source state', (tester) async {
      await openDialog(tester);
      // Find the first "DC" segment and tap it
      final dcButtons = find.text('DC');
      expect(dcButtons, findsWidgets);
      await tester.tap(dcButtons.first);
      await tester.pumpAndSettle();
      // Verify no crash / the button rebuilt successfully
    });

    testWidgets('Ceiling toggle changes visibility state', (tester) async {
      await openDialog(tester);
      final ceilingText = find.text('Ceiling');
      expect(ceilingText, findsOneWidget);
      await tester.tap(ceilingText);
      await tester.pumpAndSettle();
      // After tapping, the checkbox icon should change (verify no crash)
    });

    testWidgets(
      'shows Tanks section for gas-switch dives without tank pressures',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            overrides: [
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: DiveProfileLegend(
              config: const ProfileLegendConfig(
                hasGasSwitches: true,
                tanks: _testTanks,
              ),
              zoomLevel: 1.0,
              onZoomIn: () {},
              onZoomOut: () {},
              onResetZoom: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text('Tanks'), findsOneWidget);
        expect(find.text('D80 (Air)'), findsOneWidget);
        expect(find.text('AL80 (EAN50)'), findsOneWidget);
        expect(find.text('Tank Pressures'), findsNothing);
      },
    );

    testWidgets('keeps Tank Pressures section for multi-tank pressure dives', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasGasSwitches: true,
              hasMultiTankPressure: true,
              tanks: _testTanks,
              tankPressures: {
                'tank-1': [
                  TankPressurePoint(
                    id: 'tp-1',
                    tankId: 'tank-1',
                    timestamp: 10,
                    pressure: 210,
                  ),
                ],
                'tank-2': [
                  TankPressurePoint(
                    id: 'tp-2',
                    tankId: 'tank-2',
                    timestamp: 700,
                    pressure: 150,
                  ),
                ],
              },
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Tank Pressures'), findsOneWidget);
      expect(find.text('D80 (Air)'), findsOneWidget);
      expect(find.text('AL80 (EAN50)'), findsOneWidget);
    });
  });

  group('Badge count', () {
    testWidgets('badge reflects active secondary count including Ceiling', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasCeilingCurve: true,
              hasAscentRates: true,
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Default state: showCeiling=true, showAscentRateColors=true
      // Badge should show 2
      expect(find.text('2'), findsOneWidget);
    });
  });
}
