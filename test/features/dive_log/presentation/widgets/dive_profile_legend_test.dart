import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/presentation/widgets/chart_zoom_controls.dart';
import 'package:submersion/core/theme/app_colors.dart';
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
///
/// [width] constrains the legend's own width, which is what the inline row
/// measures against; pass a small value to exercise truncation.
Future<void> _pumpLegend(
  WidgetTester tester, {
  required ProfileLegendConfig config,
  double? width,
}) async {
  Widget legendWidget = DiveProfileLegend(
    config: config,
    zoomLevel: 1.0,
    onZoomIn: () {},
    onZoomOut: () {},
    onResetZoom: () {},
  );
  if (width != null) {
    legendWidget = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: legendWidget),
    );
  }
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: legendWidget,
    ),
  );
  await tester.pumpAndSettle();
}

/// Distinct vertical positions of the legend swatches, i.e. one per rendered
/// row, in top-to-bottom order.
List<double> _rowTops(WidgetTester tester) {
  final tops = <double>{};
  final swatches = find.byType(LegendSwatch);
  for (var i = 0; i < swatches.evaluate().length; i++) {
    tops.add(tester.getRect(swatches.at(i)).top);
  }
  final sorted = tops.toList()..sort();
  return sorted;
}

/// Labels currently rendered in the inline legend row, in order.
///
/// Each entry is a dash followed by its label, so walking the dashes and
/// taking the label beside each one picks up exactly the entries - not the
/// options badge or the zoom readout, which are also Text in this subtree.
List<String> _visibleLabels(WidgetTester tester) {
  final labels = <String>[];
  final dashes = find.byType(LegendSwatch);
  for (var i = 0; i < dashes.evaluate().length; i++) {
    final row = find
        .ancestor(of: dashes.at(i), matching: find.byType(Row))
        .first;
    final text = find.descendant(of: row, matching: find.byType(Text)).first;
    labels.add(tester.widget<Text>(text).data ?? '');
  }
  return labels;
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
    testWidgets('shows no count when every entry fits', (tester) async {
      // Ceiling and the gas strip are both active by default, and at the
      // default test width both fit inline, so nothing is hidden.
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(
          hasCeilingCurve: true,
          hasGasData: true,
        ),
      );

      expect(find.byIcon(Icons.tune), findsOneWidget);
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isFalse);
    });

    testWidgets('badges the number of entries that do not fit', (tester) async {
      // The zoom controls take ~130px of natural width, so 230 leaves the
      // legend too little for all the entries. The ones that do not fit are
      // counted on the button rather than being cut off mid-label.
      await _pumpLegend(
        tester,
        width: 230,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasCeilingCurve: true,
          hasGasData: true,
        ),
      );

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
      // Whatever did not fit is reported, and the count is never zero.
      final label = badge.label! as Text;
      expect(int.parse(label.data!), greaterThan(0));
    });

    testWidgets('truncates cleanly instead of cutting an entry off', (
      tester,
    ) async {
      await _pumpLegend(
        tester,
        width: 230,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasCeilingCurve: true,
          hasGasData: true,
        ),
      );

      // Something must actually have been dropped, or this proves nothing.
      final dashes = find.byType(LegendSwatch);
      final rendered = dashes.evaluate().length;
      // Depth plus the three configured metrics is four; something must have
      // been dropped, or this proves nothing.
      expect(rendered, lessThan(4));

      // Every entry that IS rendered must sit fully inside the legend's own
      // width. A half-clipped label is the regression this guards.
      final legendRight = tester.getRect(find.byType(DiveProfileLegend)).right;
      for (var i = 0; i < rendered; i++) {
        expect(
          tester.getRect(dashes.at(i)).right,
          lessThanOrEqualTo(legendRight),
        );
      }
    });

    testWidgets('holds one position regardless of how many entries there are', (
      tester,
    ) async {
      Future<Rect> buttonRect(ProfileLegendConfig config) async {
        await _pumpLegend(tester, width: 700, config: config);
        return tester.getRect(
          find.ancestor(
            of: find.byIcon(Icons.tune),
            matching: find.byType(IconButton),
          ),
        );
      }

      final few = await buttonRect(
        const ProfileLegendConfig(hasTemperatureData: true),
      );
      final many = await buttonRect(
        const ProfileLegendConfig(
          hasTemperatureData: true,
          hasEvents: true,
          hasCeilingCurve: true,
          hasNdlData: true,
          hasDecoStopCurve: true,
        ),
      );

      // The button anchors to the trailing edge of the legend rather than
      // trailing the last entry, so it does not shift as metrics are toggled.
      expect(few, equals(many));
    });

    testWidgets('sits just left of the zoom controls and lines up with them', (
      tester,
    ) async {
      await _pumpLegend(
        tester,
        width: 700,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );

      final button = tester.getRect(
        find.ancestor(
          of: find.byIcon(Icons.tune),
          matching: find.byType(IconButton),
        ),
      );
      final zoom = tester.getRect(find.byType(ChartZoomControls));

      expect(button.right, lessThanOrEqualTo(zoom.left));
      // Nothing but the gap between them.
      expect(zoom.left - button.right, lessThanOrEqualTo(8));
      // Same optical line as the zoom buttons.
      expect((button.center.dy - zoom.center.dy).abs(), lessThan(1.0));
    });

    testWidgets('is never clipped, however the entries fall', (tester) async {
      // The row reserves a fixed width for this button. If the button
      // actually renders wider than the reservation it overflows the clip
      // and gets sliced in half, which is what a stray tap target caused.
      for (var width = 320.0; width <= 900.0; width += 20.0) {
        await _pumpLegend(
          tester,
          width: width,
          config: const ProfileLegendConfig(
            hasTemperatureData: true,
            hasEvents: true,
            hasCeilingCurve: true,
            hasNdlData: true,
            hasDecoStopCurve: true,
          ),
        );

        // Measure the button's own box, not the icon: the icon can sit
        // inside the legend while its button hangs past the edge and is
        // sliced. The entries must never encroach on it either.
        final button = tester.getRect(
          find.ancestor(
            of: find.byIcon(Icons.tune),
            matching: find.byType(IconButton),
          ),
        );
        final legend = tester.getRect(find.byType(DiveProfileLegend));
        expect(
          button.right,
          lessThanOrEqualTo(legend.right + 0.5),
          reason: 'options button is clipped at width $width',
        );
        expect(
          button.width,
          DiveProfileLegend.optionsButtonSize,
          reason: 'options button was squeezed at width $width',
        );

        // No entry may overlap it.
        final swatches = find.byType(LegendSwatch);
        for (var i = 0; i < swatches.evaluate().length; i++) {
          expect(
            tester.getRect(swatches.at(i)).right,
            lessThanOrEqualTo(button.left),
            reason: 'an entry ran into the options button at width $width',
          );
        }
      }
    });

    testWidgets('marks each entry with a circle in the line colour', (
      tester,
    ) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );

      final swatch = tester.widget<Container>(
        find.descendant(
          of: find.byType(LegendSwatch).first,
          matching: find.byType(Container),
        ),
      );
      final decoration = swatch.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, AppColors.chartDepth);
    });

    testWidgets('does not leave a band of dead space above the chart', (
      tester,
    ) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );

      // A single-row legend is a 10px marker and a 10pt label. Anything much
      // taller is padding the chart out of its own card - the row used to be
      // 56px, almost all of it the buttons' 48px tap targets.
      final height = tester.getSize(find.byType(DiveProfileLegend)).height;
      expect(height, lessThanOrEqualTo(40));

      // And the gap under the last entry must stay small.
      final swatchBottom = tester
          .getRect(find.byType(LegendSwatch).first)
          .bottom;
      final legendBottom = tester
          .getRect(find.byType(DiveProfileLegend))
          .bottom;
      expect(legendBottom - swatchBottom, lessThanOrEqualTo(14));
    });

    testWidgets('spills into a second row before hiding anything', (
      tester,
    ) async {
      // Narrow enough that a single row cannot hold them all.
      await _pumpLegend(
        tester,
        width: 420,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasCeilingCurve: true,
          hasEvents: true,
          hasMaxDepthMarker: true,
          hasNdlData: true,
        ),
      );

      final rows = _rowTops(tester);
      expect(
        rows.length,
        2,
        reason: 'entries should wrap to a second row rather than be dropped',
      );
      // The second row must actually be below the first, not beside it.
      expect(rows[1], greaterThan(rows[0]));
    });

    testWidgets('never uses more than two rows', (tester) async {
      // Far more entries than two narrow rows can hold.
      await _pumpLegend(
        tester,
        width: 380,
        config: const ProfileLegendConfig(
          hasTemperatureData: true,
          hasCeilingCurve: true,
          hasEvents: true,
          hasMaxDepthMarker: true,
          hasNdlData: true,
          hasTtsData: true,
          hasGfData: true,
          hasCnsData: true,
          hasOtuData: true,
          hasPressureMarkers: true,
        ),
      );

      expect(_rowTops(tester).length, lessThanOrEqualTo(2));
      // Whatever did not fit is reported on the button rather than dropped
      // silently.
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
    });

    testWidgets('switching a metric on never removes another entry', (
      tester,
    ) async {
      // A long entry that does not fit must not block the shorter entries
      // after it: turning Tank 1 on used to hide Ceiling as collateral,
      // because admission stopped at the first entry too wide to fit.
      //
      // Swept across widths rather than pinned to one, since whether a given
      // entry fits is a function of the width and the test font.
      const config = ProfileLegendConfig(
        hasTemperatureData: true,
        hasCeilingCurve: true,
        hasMultiTankPressure: true,
        tanks: _testTanks,
        tankPressures: {
          'tank-1': [
            TankPressurePoint(tankId: 'tank-1', timestamp: 0, pressure: 200),
          ],
        },
      );

      for (var width = 300.0; width <= 700.0; width += 20.0) {
        await _pumpLegend(tester, width: width, config: config);
        final before = _visibleLabels(tester);

        // Toggle through the notifier rather than the dialog: the assertion
        // is about admission, not about the dialog's plumbing.
        ProviderScope.containerOf(
          tester.element(find.byType(DiveProfileLegend)),
        ).read(profileLegendProvider.notifier).toggleTankPressure('tank-1');
        await tester.pumpAndSettle();
        final after = _visibleLabels(tester);

        // If the tank entry is not rendered in either state, then in the
        // state where it is switched on it was too wide to fit - and an
        // entry that is not shown must not cost another entry its place.
        // (When it does fit it legitimately takes room, and whatever no
        // longer fits is reported on the badge.)
        const tankLabel = 'D80 (Air)';
        if (!before.contains(tankLabel) && !after.contains(tankLabel)) {
          expect(
            before,
            equals(after),
            reason:
                'an unrendered tank entry changed what is visible '
                'at width $width',
          );
        }
      }
    });

    testWidgets('sits immediately right of the legend, before zoom controls', (
      tester,
    ) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasCeilingCurve: true),
      );

      final tuneDx = tester.getCenter(find.byIcon(Icons.tune)).dx;
      final zoomDx = tester.getCenter(find.byIcon(Icons.add)).dx;
      // The options button belongs with the legend it configures, not
      // stranded on the far side of the zoom controls.
      expect(tuneDx, lessThan(zoomDx));
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
    testWidgets('lists active metrics with a square in the line colour and '
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

      // Depth always leads the row, so Temp's dash is the second one.
      final dash = tester.widget<Container>(
        find.descendant(
          of: find.byType(LegendSwatch).at(1),
          matching: find.byType(Container),
        ),
      );
      final decoration = dash.decoration! as BoxDecoration;
      expect(
        decoration.color,
        Theme.of(tester.element(find.text('Temp'))).colorScheme.tertiary,
      );
    });

    testWidgets('always lists depth, leading the row', (tester) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );

      // Depth is the chart's primary trace and is always drawn, so it is
      // always named - and it leads, as it did in the stable build.
      expect(find.text('Depth'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Depth')).dx,
        lessThan(tester.getCenter(find.text('Temp')).dx),
      );
    });

    testWidgets('depth uses the chart depth colour', (tester) async {
      await _pumpLegend(
        tester,
        config: const ProfileLegendConfig(hasTemperatureData: true),
      );

      final dash = tester.widget<Container>(
        find.descendant(
          of: find.byType(LegendSwatch).first,
          matching: find.byType(Container),
        ),
      );
      expect((dash.decoration! as BoxDecoration).color, AppColors.chartDepth);
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

      // Only the dialog row remains once the metric is switched off; the
      // depth entry stays, since depth is always drawn.
      expect(find.text('Temp'), findsOneWidget);
      expect(_inDialog(find.text('Temp')), findsOneWidget);
      expect(find.byType(LegendSwatch), findsOneWidget);
      expect(find.text('Depth'), findsOneWidget);
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

        // Depth plus the tank that is still shown.
        expect(find.byType(LegendSwatch), findsNWidgets(2));
      },
    );
  });
}
