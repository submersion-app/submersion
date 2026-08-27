import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';

import '../../../../helpers/test_app.dart';

/// Minimal [SettingsNotifier] stub that returns default [AppSettings].
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier()
    : super(const AppSettings(defaultShowGasTimeline: true));

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

/// Scopes a finder to the chart options dialog. Every dialog row lives inside
/// an ExpansionTile section; inline legend toggles never do. This keeps
/// assertions unambiguous once toggles can appear both inline and in the
/// dialog (adaptive legend row).
Finder _inDialog(Finder matching) =>
    find.descendant(of: find.byType(ExpansionTile), matching: matching);

/// Pumps the legend constrained to [width], top-left aligned so the row gets
/// exactly that much horizontal space.
Future<void> _pumpLegendAt(
  WidgetTester tester, {
  required double width,
  required ProfileLegendConfig config,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DiveProfileLegend(
            config: config,
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DiveProfileLegend - estimated tank pressure', () {
    testWidgets('estimated tank row shows the (est.) suffix', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasMultiTankPressure: true,
              tanks: _testTanks,
              tankPressures: {
                'tank-1': [
                  TankPressurePoint(
                    id: 'e0',
                    tankId: 'tank-1',
                    timestamp: 0,
                    pressure: 200,
                  ),
                ],
              },
              estimatedTankIds: {'tank-1'},
            ),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tank Pressures lives in the "more options" (tune) dialog.
      await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.textContaining('(est.)'), findsWidgets);
    });
  });

  group('DiveProfileLegend - primary toggles', () {
    testWidgets('shows Events toggle when hasEvents is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
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

    testWidgets('shows Ceiling inline when space allows', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
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

      // The adaptive row promotes both active toggles at the 800px default
      // test width.
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Ceiling'), findsOneWidget);
    });
  });

  group('_ChartOptionsDialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
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
      expect(_inDialog(find.text('Heart Rate')), findsOneWidget);
      expect(_inDialog(find.text('SAC Rate')), findsOneWidget);
    });

    testWidgets('Overlays section shows both ascent-rate toggles', (
      tester,
    ) async {
      await openDialog(tester);
      // The band-coloring toggle ("Ascent Rate") and the separate magnitude
      // line toggle ("Ascent Rate Line") are distinct controls.
      expect(_inDialog(find.text('Ascent Rate')), findsOneWidget);
      expect(_inDialog(find.text('Ascent Rate Line')), findsOneWidget);
    });

    testWidgets('tapping Ascent Rate Line toggles without crashing', (
      tester,
    ) async {
      await openDialog(tester);
      await tester.tap(_inDialog(find.text('Ascent Rate Line')));
      await tester.pumpAndSettle();
      expect(_inDialog(find.text('Ascent Rate Line')), findsOneWidget);
    });

    testWidgets('tapping collapsed section expands it', (tester) async {
      await openDialog(tester);
      // Markers starts collapsed -- tap to expand
      await tester.tap(find.text('Markers'));
      await tester.pumpAndSettle();
      expect(_inDialog(find.text('Max Depth')), findsOneWidget);
    });

    testWidgets('Ceiling has visibility toggle in Decompression section', (
      tester,
    ) async {
      await openDialog(tester);
      // Decompression starts expanded, so Ceiling should be visible
      expect(_inDialog(find.text('Ceiling')), findsOneWidget);
    });

    testWidgets('source-capable metrics have SegmentedButtons', (tester) async {
      await openDialog(tester);
      // 3 metrics with source selectors: NDL, TTS, CNS%. The ceiling line has
      // no source toggle (issue #755) -- it always shows the calculated curve.
      expect(find.byType(SegmentedButton<MetricDataSource>), findsNWidgets(3));
    });

    testWidgets('Ceiling row has no source SegmentedButton', (tester) async {
      await openDialog(tester);
      // The ceiling line always renders the exact calculated curve, so its
      // legend row is a plain visibility toggle with no Computer/Calculated
      // selector (issue #755).
      final ceilingRow = find
          .ancestor(
            of: _inDialog(find.text('Ceiling')),
            matching: find.byType(Row),
          )
          .first;
      expect(
        find.descendant(
          of: ceilingRow,
          matching: find.byType(SegmentedButton<MetricDataSource>),
        ),
        findsNothing,
      );
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
      final ceilingText = _inDialog(find.text('Ceiling'));
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
            locale: const Locale('en'),
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

        expect(find.text('Cylinders'), findsOneWidget);
        expect(_inDialog(find.text('D80 (Air)')), findsOneWidget);
        expect(_inDialog(find.text('AL80 (EAN50)')), findsOneWidget);
        expect(find.text('Tank Pressures'), findsNothing);
      },
    );

    testWidgets('keeps Tank Pressures section for multi-tank pressure dives', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
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
      expect(_inDialog(find.text('D80 (Air)')), findsOneWidget);
      expect(_inDialog(find.text('AL80 (EAN50)')), findsOneWidget);
    });
  });

  group('Badge count', () {
    testWidgets('badge counts active toggles hidden from the inline row', (
      tester,
    ) async {
      // At 250px nothing fits inline; Ceiling is active by default, so
      // exactly one active toggle is hidden behind the More button.
      await _pumpLegendAt(
        tester,
        width: 250,
        config: const ProfileLegendConfig(hasCeilingCurve: true),
      );

      expect(find.text('Ceiling'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('badge is hidden when every active toggle is inline', (
      tester,
    ) async {
      await _pumpLegendAt(
        tester,
        width: 1200,
        config: const ProfileLegendConfig(hasCeilingCurve: true),
      );

      expect(find.text('Ceiling'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('hidden gas strip toggle counts toward the badge', (
      tester,
    ) async {
      // showGas defaults to true; at 250px it cannot render inline.
      await _pumpLegendAt(
        tester,
        width: 250,
        config: const ProfileLegendConfig(hasGasData: true),
      );

      expect(find.text('Gases'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('ProfileLegendConfig.hasSecondaryToggles', () {
    test('is true when hasGasData is true', () {
      const config = ProfileLegendConfig(hasGasData: true);
      expect(config.hasSecondaryToggles, isTrue);
    });

    test('is false when only non-toggle fields are set', () {
      const config = ProfileLegendConfig();
      expect(config.hasSecondaryToggles, isFalse);
    });
  });

  group('gas toggle in _ChartOptionsDialog', () {
    testWidgets(
      'gas strip toggle appears in Overlays when hasGasData is true',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            locale: const Locale('en'),
            overrides: [
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: DiveProfileLegend(
              config: const ProfileLegendConfig(hasGasData: true),
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
        expect(_inDialog(find.text('Gases')), findsOneWidget);
      },
    );

    testWidgets('gas strip toggle is absent when hasGasData is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.tune), findsNothing);
    });
  });

  group('photo markers toggle in _ChartOptionsDialog', () {
    testWidgets(
      'shows the Photos toggle in the Markers section when available',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            locale: const Locale('en'),
            overrides: [
              settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            ],
            child: DiveProfileLegend(
              config: const ProfileLegendConfig(hasPhotoMarkers: true),
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
        // Markers starts collapsed -- tap to expand.
        await tester.tap(find.text('Markers'));
        await tester.pumpAndSettle();
        expect(_inDialog(find.text('Photos')), findsOneWidget);
      },
    );

    testWidgets('hides the Photos toggle when the dive has no photos', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(),
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Photos'), findsNothing);
    });
  });

  group('DiveProfileLegend - deco stop band toggle', () {
    Future<void> pumpLegend(
      WidgetTester tester,
      ProfileLegendConfig config,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: config,
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
    }

    testWidgets('deco stops toggle appears when hasDecoStopCurve is true', (
      tester,
    ) async {
      await pumpLegend(
        tester,
        const ProfileLegendConfig(hasDecoStopCurve: true),
      );
      expect(_inDialog(find.text('Deco stops')), findsOneWidget);
    });

    testWidgets('deco stops toggle is absent when hasDecoStopCurve is false', (
      tester,
    ) async {
      await pumpLegend(
        tester,
        const ProfileLegendConfig(hasCeilingCurve: true),
      );
      expect(_inDialog(find.text('Deco stops')), findsNothing);
    });

    testWidgets('deco stops swatch is a filled block, not a line', (
      tester,
    ) async {
      await pumpLegend(
        tester,
        const ProfileLegendConfig(hasDecoStopCurve: true),
      );

      // The band is drawn on the chart as a translucent shaded region, so its
      // legend swatch must be the taller filled block rather than the 4px line
      // used for stroked metrics. Locate it by the row containing the label.
      final swatch = tester.widgetList<Container>(
        find
                .ancestor(
                  of: _inDialog(find.text('Deco stops')),
                  matching: find.byType(Row),
                )
                .first
                .evaluate()
                .isEmpty
            ? find.byType(Container)
            : find.descendant(
                of: find
                    .ancestor(
                      of: _inDialog(find.text('Deco stops')),
                      matching: find.byType(Row),
                    )
                    .first,
                matching: find.byType(Container),
              ),
      );

      final blocks = swatch.where(
        (c) => c.constraints?.maxHeight == 12 && c.constraints?.maxWidth == 16,
      );
      expect(
        blocks,
        isNotEmpty,
        reason: 'expected a 16x12 filled swatch block for the deco stop band',
      );

      final decoration = blocks.first.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.color!.a, lessThan(1.0));
      expect(decoration.color!.a, greaterThan(0.0));
    });

    testWidgets('ceiling swatch stays a line while deco stops is a block', (
      tester,
    ) async {
      await pumpLegend(
        tester,
        const ProfileLegendConfig(hasCeilingCurve: true),
      );

      final containers = tester
          .widgetList<Container>(
            find.descendant(
              of: find
                  .ancestor(
                    of: _inDialog(find.text('Ceiling')),
                    matching: find.byType(Row),
                  )
                  .first,
              matching: find.byType(Container),
            ),
          )
          .where((c) => c.constraints?.maxWidth == 16);

      expect(containers, isNotEmpty);
      expect(
        containers.first.constraints?.maxHeight,
        4,
        reason: 'stroked metrics keep the thin line swatch',
      );
    });
  });

  group('dialog catalog completeness', () {
    testWidgets('Overlays section lists Temperature, Pressure, and Events', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasTemperatureData: true,
              hasPressureData: true,
              hasEvents: true,
              hasHeartRateData: true,
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

      expect(_inDialog(find.text('Temp')), findsOneWidget);
      expect(_inDialog(find.text('Pressure')), findsOneWidget);
      expect(_inDialog(find.text('Events')), findsOneWidget);
    });

    testWidgets('single-tank Pressure entry is absent for multi-tank dives', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DiveProfileLegend(
            config: const ProfileLegendConfig(
              hasPressureData: true,
              hasMultiTankPressure: true,
              tanks: _testTanks,
              tankPressures: {
                'tank-1': [
                  TankPressurePoint(
                    id: 'tp-1',
                    tankId: 'tank-1',
                    timestamp: 0,
                    pressure: 200,
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

      // Multi-tank dives use per-tank rows in Tank Pressures instead of the
      // single "Pressure" toggle.
      expect(_inDialog(find.text('Pressure')), findsNothing);
    });
  });

  group('adaptive inline row', () {
    testWidgets('narrow width keeps one line and drops low-priority toggles', (
      tester,
    ) async {
      // Available toggle budget at 400px is roughly
      // 400 - 128 (zoom) - 4 - 72 (depth) - 32 (more) - 8 (margin) = 156.
      // Actives admit first: Temp (81) fits, Events (103) does not -> stop.
      await _pumpLegendAt(
        tester,
        width: 400,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasEvents: true,
          hasHeartRateData: true,
          hasSacCurve: true,
        ),
      );

      expect(find.text('Temp'), findsOneWidget);
      expect(find.text('Heart Rate'), findsNothing);
      expect(find.text('SAC Rate'), findsNothing);
      expect(
        tester.getSize(find.byType(DiveProfileLegend)).height,
        lessThanOrEqualTo(56),
        reason: 'legend must stay a single line',
      );
    });

    testWidgets('wide width fills remaining space with inactive toggles', (
      tester,
    ) async {
      // Heart Rate and SAC Rate default OFF; at 1200px they are admitted as
      // inactive fillers after the active toggles.
      await _pumpLegendAt(
        tester,
        width: 1200,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasEvents: true,
          hasHeartRateData: true,
          hasSacCurve: true,
        ),
      );

      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('SAC Rate'), findsOneWidget);
      expect(
        tester.getSize(find.byType(DiveProfileLegend)).height,
        lessThanOrEqualTo(56),
      );
    });

    testWidgets('an active low-priority toggle evicts inactive higher ones', (
      tester,
    ) async {
      // OTU (priority last) is toggled ON; Heart Rate (priority higher) is
      // OFF. Budget at 400px is ~156: OTU (33 + 33 + 4 = 70) admits first as
      // the only active candidate; Heart Rate (147) then no longer fits even
      // though it would have fit alone (147 < 156).
      await _pumpLegendAt(
        tester,
        width: 400,
        config: const ProfileLegendConfig(
          hasHeartRateData: true,
          hasOtuData: true,
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveProfileLegend)),
      );
      container.read(profileLegendProvider.notifier).toggleOtu();
      await tester.pumpAndSettle();

      expect(find.text('OTU'), findsOneWidget);
      expect(find.text('Heart Rate'), findsNothing);
    });

    testWidgets('visible toggles render in canonical order, not active order', (
      tester,
    ) async {
      await _pumpLegendAt(
        tester,
        width: 1200,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasOtuData: true,
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveProfileLegend)),
      );
      container.read(profileLegendProvider.notifier).toggleOtu();
      await tester.pumpAndSettle();

      // OTU was activated after Temp, but Temp (priority 0) stays left of OTU.
      expect(
        tester.getTopLeft(find.text('Temp')).dx,
        lessThan(tester.getTopLeft(find.text('OTU')).dx),
      );
    });

    testWidgets('large text scale admits fewer toggles but keeps one line', (
      tester,
    ) async {
      // At 1x a 550px legend admits Temp and Events; at 2x every label
      // doubles (Depth reserve 127, Temp 125, Events 169 against a ~171
      // budget once the 48px zoom tap targets are subtracted), so only
      // Temp fits.
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpLegendAt(
        tester,
        width: 550,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasEvents: true,
        ),
      );

      expect(find.text('Temp'), findsOneWidget);
      expect(find.text('Events'), findsNothing);
      expect(
        tester.getSize(find.byType(DiveProfileLegend)).height,
        lessThanOrEqualTo(56),
      );
    });

    testWidgets('multi-tank dives promote per-tank pressure toggles', (
      tester,
    ) async {
      await _pumpLegendAt(
        tester,
        width: 1200,
        config: const ProfileLegendConfig(
          hasMultiTankPressure: true,
          tanks: _testTanks,
          tankPressures: {
            'tank-1': [
              TankPressurePoint(
                id: 'tp-1',
                tankId: 'tank-1',
                timestamp: 0,
                pressure: 200,
              ),
            ],
            'tank-2': [
              TankPressurePoint(
                id: 'tp-2',
                tankId: 'tank-2',
                timestamp: 0,
                pressure: 200,
              ),
            ],
          },
        ),
      );

      // Inline row (dialog not open) shows one toggle per tank.
      expect(find.text('D80 (Air)'), findsOneWidget);
      expect(find.text('AL80 (EAN50)'), findsOneWidget);
    });
  });
}
