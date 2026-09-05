import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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

/// Pumps the legend for [config].
Future<void> _pumpLegend(
  WidgetTester tester, {
  required ProfileLegendConfig config,
}) async {
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
      expect(_inDialog(find.text('Consumption')), findsOneWidget);
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

    testWidgets(
      'Cylinders rows use the same checkbox toggle as every other row and '
      'flip that tank\'s visibility',
      (tester) async {
        await _pumpLegend(
          tester,
          config: const ProfileLegendConfig(
            hasGasSwitches: true,
            tanks: _testTanks,
          ),
        );
        await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
        await tester.pumpAndSettle();

        final label = _inDialog(find.text('D80 (Air)'));
        expect(label, findsOneWidget);
        // No static dot/dash legend chrome: the row is a checkbox like the rest.
        expect(_inDialog(find.byIcon(Icons.circle)), findsNothing);
        final row = find
            .ancestor(of: label, matching: find.byType(InkWell))
            .first;
        expect(
          find.descendant(of: row, matching: find.byIcon(Icons.check_box)),
          findsOneWidget,
        );

        await tester.tap(label);
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DiveProfileLegend)),
        );
        expect(
          container.read(profileLegendProvider).showTankPressure['tank-1'],
          isFalse,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.byIcon(Icons.check_box_outline_blank),
          ),
          findsOneWidget,
        );
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
                    tankId: 'tank-1',
                    timestamp: 10,
                    pressure: 210,
                  ),
                ],
                'tank-2': [
                  TankPressurePoint(
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

  group('options button', () {
    testWidgets('shows no active-count badge', (tester) async {
      // Ceiling and the gas strip are both active by default; the button
      // must still render as a plain icon with no count bubble.
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(
          hasCeilingCurve: true,
          hasGasData: true,
        ),
      );

      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
      expect(find.text('2'), findsNothing);
    });

    testWidgets('sits at the trailing end of the row, after zoom controls', (
      tester,
    ) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasCeilingCurve: true),
      );

      final tuneDx = tester.getCenter(find.byIcon(Icons.tune)).dx;
      final zoomDx = tester.getCenter(find.byIcon(Icons.add)).dx;
      expect(tuneDx, greaterThan(zoomDx));
    });

    testWidgets('is shown for primary-only toggles such as temperature', (
      tester,
    ) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );

      expect(find.byIcon(Icons.tune), findsOneWidget);
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

    testWidgets('deco stops shows a checkbox indicator', (tester) async {
      await pumpLegend(
        tester,
        const ProfileLegendConfig(hasDecoStopCurve: true),
      );

      // Deco stops defaults active.
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: _inDialog(find.text('Deco stops')),
                matching: find.byType(Row),
              )
              .first,
          matching: find.byIcon(Icons.check_box),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ceiling shows a checkbox indicator', (tester) async {
      await pumpLegend(
        tester,
        const ProfileLegendConfig(hasCeilingCurve: true),
      );

      // Ceiling defaults active.
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: _inDialog(find.text('Ceiling')),
                matching: find.byType(Row),
              )
              .first,
          matching: find.byIcon(Icons.check_box),
        ),
        findsOneWidget,
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

  group('inline legend', () {
    testWidgets('lists active metrics with a dash in the line colour and '
        'no checkbox', (tester) async {
      // Temperature is on by default; heart rate is off by default.
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasHeartRateData: true,
        ),
      );

      expect(find.text('Temp'), findsOneWidget);
      expect(find.text('Heart Rate'), findsNothing);
      expect(find.byIcon(Icons.check_box), findsNothing);
      expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);

      final dash = tester.widget<Container>(
        find.descendant(
          of: find.byType(LegendDash),
          matching: find.byType(Container),
        ),
      );
      final decoration = dash.decoration! as BoxDecoration;
      expect(
        decoration.color,
        Theme.of(tester.element(find.text('Temp'))).colorScheme.tertiary,
      );
    });

    testWidgets('never lists depth', (tester) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );

      // Depth is the chart itself, not an option, so it gets no legend entry.
      expect(find.text('Depth'), findsNothing);
    });

    testWidgets('uses a smaller font than the dialog rows', (tester) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );

      final inline = tester.widget<Text>(find.text('Temp'));
      final labelSmall = Theme.of(
        tester.element(find.text('Temp')),
      ).textTheme.labelSmall!;
      expect(inline.style!.fontSize, lessThan(labelSmall.fontSize!));
    });

    testWidgets('is not clickable: tapping an entry changes nothing', (
      tester,
    ) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );

      await tester.tap(find.text('Temp'));
      await tester.pumpAndSettle();

      expect(find.text('Temp'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
    });

    testWidgets('follows toggles made in the dialog', (tester) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );
      expect(find.text('Temp'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(_inDialog(find.text('Temp')));
      await tester.pumpAndSettle();

      // Only the dialog row remains once the metric is switched off.
      expect(find.text('Temp'), findsOneWidget);
      expect(_inDialog(find.text('Temp')), findsOneWidget);
      expect(find.byType(LegendDash), findsNothing);
    });
  });

  group('multi-tank pressure toggles', () {
    testWidgets(
      'live in the dialog while the visible tanks are listed inline',
      (tester) async {
        await _pumpLegend(
          tester,
          config: const ProfileLegendConfig(
            hasMultiTankPressure: true,
            tanks: _testTanks,
            tankPressures: {
              'tank-1': [
                TankPressurePoint(
                  tankId: 'tank-1',
                  timestamp: 0,
                  pressure: 200,
                ),
              ],
              'tank-2': [
                TankPressurePoint(
                  tankId: 'tank-2',
                  timestamp: 0,
                  pressure: 200,
                ),
              ],
            },
          ),
        );

        expect(find.text('D80 (Air)'), findsOneWidget);
        expect(find.text('AL80 (EAN50)'), findsOneWidget);
        expect(find.byIcon(Icons.check_box), findsNothing);

        await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(_inDialog(find.text('D80 (Air)')), findsOneWidget);
        expect(_inDialog(find.text('AL80 (EAN50)')), findsOneWidget);

        await tester.tap(_inDialog(find.text('AL80 (EAN50)')));
        await tester.pumpAndSettle();

        expect(find.byType(LegendDash), findsOneWidget);
      },
    );
  });
}
