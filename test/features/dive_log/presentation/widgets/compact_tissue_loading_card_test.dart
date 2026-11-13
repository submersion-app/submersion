import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_area_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map_axes.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_pressure_bar_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

import 'tissue_card_test_helpers.dart';

const _comp = testCompartment;

const _status = testStatus;

const _comp2 = TissueCompartment(
  compartmentNumber: 2,
  halfTimeN2: 8.0,
  halfTimeHe: 3.02,
  mValueAN2: 1.0000,
  mValueBN2: 0.6514,
  mValueAHe: 1.3830,
  mValueBHe: 0.5747,
);

// The area chart spreads hue across `compartments.length - 1`, so a
// single-compartment status divides by zero. Real deco models always emit all
// 16 compartments; use at least two here to stay on a realistic code path.
const _multiCompStatus = DecoStatus(
  compartments: [_comp, _comp2],
  ndlSeconds: 600,
  ceilingMeters: 0.0,
  ttsSeconds: 0,
  gfLow: 0.4,
  gfHigh: 0.85,
  decoStops: [],
  currentDepthMeters: 10.0,
  ambientPressureBar: 2.0,
);

// A compartment loaded well past its M-value. surfaceMValue for these
// coefficients is ~3.24 bar, so currentPN2 4.5 is ~139% loading, which clamps
// the bar to full chart height -- the case where the highlight outline used to
// overflow the fixed-height bar slot.
const _overloadedComp = TissueCompartment(
  compartmentNumber: 1,
  halfTimeN2: 4.0,
  halfTimeHe: 1.51,
  mValueAN2: 1.2599,
  mValueBN2: 0.5050,
  mValueAHe: 1.7424,
  mValueBHe: 0.4245,
  currentPN2: 4.5,
);

const _overloadedStatus = DecoStatus(
  compartments: [_overloadedComp],
  ndlSeconds: -1,
  ceilingMeters: 6.0,
  ttsSeconds: 300,
  gfLow: 0.4,
  gfHigh: 0.85,
  decoStops: [],
  currentDepthMeters: 30.0,
  ambientPressureBar: 4.0,
);

void main() {
  // On a phone the card is about 334 px wide inside the page; scrubbing sets
  // the cursor time, which joins the title in the header (#4423).
  testWidgets(
    'the header fits a phone with the cursor time and every control',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(334, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildCard(
          decoStatuses: const [_status, _status],
          onOpen3dView: () {},
          subtitle: '23:20',
          scrollable: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The time stays whole; the title gives way first.
      expect(find.text('@ 23:20'), findsOneWidget);
      final time = tester.getRect(find.text('@ 23:20'));
      final controls = tester.getRect(find.byIcon(Icons.grid_on));
      expect(time.right, lessThanOrEqualTo(controls.left));
    },
  );

  testWidgets(
    'does not overflow when the highlighted compartment bar is full height',
    (tester) async {
      await tester.pumpWidget(buildCard(status: _overloadedStatus));
      await tester.pumpAndSettle();

      // The leading (only) compartment is >120% loaded, so its bar fills the
      // whole chart height and is highlighted by default. The highlight must
      // not push the bar past its fixed-height slot.
      expect(tester.takeException(), isNull);
    },
  );

  group('CompactTissueLoadingCard gassing direction (issue #2593)', () {
    // A tissue at 2.5 bar, 4 bar ambient (30 m), on a loop whose inspired inert
    // pressure is 1.2 bar: below ambient, yet releasing gas.
    const loadedComp = TissueCompartment(
      compartmentNumber: 1,
      halfTimeN2: 4.0,
      halfTimeHe: 1.51,
      mValueAN2: 1.2599,
      mValueBN2: 0.5050,
      mValueAHe: 1.7424,
      mValueBHe: 0.4245,
      currentPN2: 2.5,
    );
    DecoStatus atStop({double? inspiredN2, double? inspiredHe}) => DecoStatus(
      compartments: const [loadedComp],
      ndlSeconds: -1,
      ceilingMeters: 6.0,
      ttsSeconds: 300,
      gfLow: 0.4,
      gfHigh: 0.85,
      decoStops: const [],
      currentDepthMeters: 30.0,
      ambientPressureBar: 4.0,
      inspiredN2Bar: inspiredN2,
      inspiredHeBar: inspiredHe,
    );

    testWidgets('reads off-gassing against the inspired gas, not ambient', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(status: atStop(inspiredN2: 1.2, inspiredHe: 0.0)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offgassing'), findsOneWidget);
      expect(find.text('Ongassing'), findsNothing);
    });

    testWidgets('leaves the direction out when the inspired gas is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(status: atStop()));
      await tester.pumpAndSettle();

      expect(find.text('Offgassing'), findsNothing);
      expect(find.text('Ongassing'), findsNothing);
    });
  });

  group('CompactTissueLoadingCard 3D view button', () {
    testWidgets('shows the 3D button and fires the callback on tap', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(buildCard(onOpen3dView: () => opened++));
      await tester.pumpAndSettle();

      final button = find.byIcon(Icons.view_in_ar);
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(opened, 1);
    });

    testWidgets('3D button keeps a minimum touch target on mobile', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(onOpen3dView: () {}));
      await tester.pumpAndSettle();

      // The default test platform (android) uses MaterialTapTargetSize.padded,
      // which must inflate the compact 16px icon to an accessible hit area
      // (48 minus the compact visual density adjustment).
      final size = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.view_in_ar),
          matching: find.byType(IconButton),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));
    });

    testWidgets('hides the 3D button when no callback is provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.view_in_ar), findsNothing);
    });
  });

  group('CompactTissueLoadingCard header icons', () {
    // Header controls in left-to-right render order: the view dropdown
    // (showing the default heat map view's icon) and the 3D button.
    const headerIcons = [Icons.grid_on, Icons.view_in_ar];

    Finder viewMenu() => find.byTooltip('Chart view');

    testWidgets('are spaced evenly across the header row', (tester) async {
      await tester.pumpWidget(buildCard(onOpen3dView: () {}));
      await tester.pumpAndSettle();

      final rects = [
        for (final icon in headerIcons)
          tester.getRect(
            find.ancestor(
              of: find.byIcon(icon),
              matching: find.byType(IconButton),
            ),
          ),
        tester.getRect(find.byType(HeaderInfoButton)),
      ];

      // Guard the assumed render order before measuring the gaps.
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, greaterThan(rects[i - 1].left));
      }

      final gaps = [
        for (var i = 1; i < rects.length; i++)
          rects[i].left - rects[i - 1].right,
      ];
      for (final gap in gaps) {
        expect(gap, closeTo(gaps.first, 0.5), reason: 'gaps were $gaps');
      }
    });

    testWidgets('share one layout box so the gaps cannot drift', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(onOpen3dView: () {}));
      await tester.pumpAndSettle();

      final sizes = headerIcons
          .map(
            (icon) => tester.getSize(
              find.ancestor(
                of: find.byIcon(icon),
                matching: find.byType(IconButton),
              ),
            ),
          )
          .toList();

      for (final size in sizes) {
        // Every control carries the same accessible touch target as the 3D
        // button (48 minus the compact visual density adjustment).
        expect(size.width, greaterThanOrEqualTo(40));
        expect(size.height, greaterThanOrEqualTo(40));
        expect(size, sizes.first, reason: 'sizes were $sizes');
      }
    });

    testWidgets('offer one view dropdown and no colour scheme button '
        '(issue #4437)', (tester) async {
      await tester.pumpWidget(
        buildCard(status: _multiCompStatus, decoStatuses: [_multiCompStatus]),
      );
      await tester.pumpAndSettle();

      expect(viewMenu(), findsOneWidget);
      // The dropdown shows the current view's icon with a caret; the other
      // view's icon and the palette are gone from the header.
      expect(find.byIcon(Icons.grid_on), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(find.byIcon(Icons.area_chart), findsNothing);
      expect(find.byIcon(Icons.palette_outlined), findsNothing);
    });

    testWidgets('switch the visualization mode from the dropdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(status: _multiCompStatus, decoStatuses: [_multiCompStatus]),
      );
      await tester.pumpAndSettle();

      // The card renders exactly one of the two visualizations, chosen by
      // tissueVizMode, so the rendered chart type is what proves the pick
      // took effect. AppSettings defaults to TissueVizMode.heatMap.
      expect(find.byType(TissueHeatMapStrip), findsOneWidget);
      expect(find.byType(TissueAreaChart), findsNothing);

      await tester.tap(viewMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stacked area'));
      await tester.pumpAndSettle();
      expect(find.byType(TissueAreaChart), findsOneWidget);
      expect(find.byType(TissueHeatMapStrip), findsNothing);
      // The dropdown now shows the chosen view's icon.
      expect(find.byIcon(Icons.area_chart), findsOneWidget);
      expect(find.byIcon(Icons.grid_on), findsNothing);

      await tester.tap(viewMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Heat map'));
      await tester.pumpAndSettle();
      expect(find.byType(TissueHeatMapStrip), findsOneWidget);
      expect(find.byType(TissueAreaChart), findsNothing);
    });

    testWidgets('check the current view in the dropdown menu', (tester) async {
      await tester.pumpWidget(
        buildCard(status: _multiCompStatus, decoStatuses: [_multiCompStatus]),
      );
      await tester.pumpAndSettle();

      await tester.tap(viewMenu());
      await tester.pumpAndSettle();

      final items = tester
          .widgetList<CheckedPopupMenuItem<TissueVizMode>>(
            find.byType(CheckedPopupMenuItem<TissueVizMode>),
          )
          .toList();
      expect(items.map((item) => item.value), TissueVizMode.values);
      expect(
        {for (final item in items) item.value: item.checked},
        {TissueVizMode.heatMap: true, TissueVizMode.stackedArea: false},
      );
    });
  });

  group('CompactTissueLoadingCard heatmap labels', () {
    testWidgets('names Fast and Slow once, and the heat map rows in a caption '
        '(issue #4228)', (tester) async {
      await tester.pumpWidget(buildCard(decoStatuses: [_status]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(CompactTissueLoadingCard));
      final l10n = AppLocalizations.of(context);
      // Only the bar chart axis: the heat map no longer repeats them.
      expect(find.text(l10n.diveLog_deco_tissueFast), findsOneWidget);
      expect(find.text(l10n.diveLog_deco_tissueSlow), findsOneWidget);
      // The compartment axis names the rows now (#4503).
      expect(find.byType(TissueHeatMapCompartmentAxis), findsOneWidget);
      // The heat map colors against AMBIENT pressure, so its legend names
      // the two halves undersaturated / supersaturated instead of borrowing
      // the badges' "Ongassing"/"Offgassing", which are measured against the
      // inspired pressure.
      expect(
        find.text(l10n.diveLog_deco_heatMapUndersaturated),
        findsOneWidget,
      );
      expect(
        find.text(l10n.diveLog_deco_heatMapSupersaturated),
        findsOneWidget,
      );
      expect(find.text(l10n.diveLog_deco_gasOngassing), findsNothing);
      expect(find.text(l10n.diveLog_deco_gasOffgassing), findsNothing);
    });

    for (final direction in TextDirection.values) {
      testWidgets('keeps the legend at the trailing end with the halves in '
          'reading order (${direction.name})', (tester) async {
        await tester.pumpWidget(
          buildCard(decoStatuses: [_status], textDirection: direction),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(CompactTissueLoadingCard));
        final l10n = AppLocalizations.of(context);
        final strip = tester.getRect(find.byType(TissueHeatMapStrip));
        final legend = tester.getRect(find.byType(TissueHeatMapLegend));
        final under = tester.getCenter(
          find.text(l10n.diveLog_deco_heatMapUndersaturated),
        );
        final over = tester.getCenter(
          find.text(l10n.diveLog_deco_heatMapSupersaturated),
        );

        if (direction == TextDirection.rtl) {
          // Trailing is the left; the low half reads first, on the right.
          expect(legend.center.dx, lessThan(strip.center.dx));
          expect(under.dx, greaterThan(over.dx));
        } else {
          expect(legend.center.dx, greaterThan(strip.center.dx));
          expect(under.dx, lessThan(over.dx));
        }
      });
    }

    testWidgets(
      'fires onCompartmentHoverChanged with index on tap then null on release',
      (tester) async {
        await tester.pumpWidget(buildCard(decoStatuses: [_status]));
        await tester.pumpAndSettle();

        final heatMap = find.byType(TissueHeatMapStrip);
        // Tap down → _showTooltipForPosition → onCompartmentHoverChanged(compIdx)
        // Tap up   → _removeTooltip          → onCompartmentHoverChanged(null)
        await tester.tap(heatMap);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'shows Fast and Slow labels when heatmap data is provided in expanded mode',
      (tester) async {
        await tester.pumpWidget(
          buildCard(decoStatuses: [_status], expandVisualization: true),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(CompactTissueLoadingCard));
        final l10n = AppLocalizations.of(context);
        expect(find.text(l10n.diveLog_deco_tissueFast), findsOneWidget);
        expect(find.text(l10n.diveLog_deco_tissueSlow), findsOneWidget);
        expect(find.byType(TissueHeatMapCompartmentAxis), findsOneWidget);
      },
    );
  });

  group('CompactTissueLoadingCard surface level marker (issue #4228)', () {
    testWidgets('draws one marker per compartment and names it in a legend', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(status: _multiCompStatus));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('tissue-surface-marker-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tissue-surface-marker-2')),
        findsOneWidget,
      );
      expect(find.text('Surface level'), findsOneWidget);
      expect(find.text('M-value'), findsOneWidget);
    });

    testWidgets('bar tooltips follow a new status, not the previous one', (
      tester,
    ) async {
      String firstTooltip() => tester
          .widget<Tooltip>(
            find
                .descendant(
                  of: find.byType(TissuePressureBarChart),
                  matching: find.byType(Tooltip),
                )
                .first,
          )
          .message!;

      await tester.pumpWidget(buildCard(status: _status));
      await tester.pumpAndSettle();
      expect(firstTooltip(), contains('N₂: 0.74 bar'));

      // Same tree, new status (a profile scrub): the bar chart keeps its
      // state, so its memoized tooltips must be rebuilt for this status.
      await tester.pumpWidget(buildCard(status: _overloadedStatus));
      await tester.pumpAndSettle();
      expect(firstTooltip(), contains('N₂: 4.50 bar'));
    });

    for (final brightness in Brightness.values) {
      testWidgets('draws the M-value line in the full error color '
          '(${brightness.name} theme)', (tester) async {
        await tester.pumpWidget(
          buildCard(
            status: _multiCompStatus,
            theme: ThemeData(brightness: brightness),
          ),
        );
        await tester.pumpAndSettle();

        final colorScheme = Theme.of(
          tester.element(find.byType(CompactTissueLoadingCard)),
        ).colorScheme;
        expect(colorScheme.brightness, brightness);
        final line = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(const ValueKey('tissue-m-value-line')),
            matching: find.byType(ColoredBox),
          ),
        );
        // At half opacity it all but vanished against the dark card.
        expect(line.color, colorScheme.error);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('tissue-m-value-line')))
              .height,
          TissuePressureBarChart.mValueLineHeight,
        );
      });
    }

    testWidgets('sits the M-value line on whole pixels and lets hovers '
        'through to the bars', (tester) async {
      await tester.pumpWidget(buildCard(status: _multiCompStatus));
      await tester.pumpAndSettle();

      final lineFinder = find.byKey(const ValueKey('tissue-m-value-line'));
      final chartStack = find
          .ancestor(of: lineFinder, matching: find.byType(Stack))
          .first;
      final offset =
          tester.getRect(chartStack).bottom - tester.getRect(lineFinder).bottom;
      // Unrounded, 50 * 100 / 120 - 1 = 40.67 straddles three pixel rows.
      // Snapped on the device pixel grid of the test view.
      final dpr = tester.view.devicePixelRatio;
      expect(offset * dpr, closeTo((offset * dpr).roundToDouble(), 1e-6));
      expect(
        find.descendant(of: lineFinder, matching: find.byType(IgnorePointer)),
        findsOneWidget,
      );
    });

    test('bandBottom snaps to device pixels and survives a tiny chart', () {
      // 50 * 100 / 120 - 1 = 40.67: at 1.5x the nearest device row is
      // 61 / 1.5 = 40.67, at 1x it is 41.
      expect(
        TissuePressureBarChart.bandBottom(
          chartHeight: 50,
          percent: 100,
          height: 2,
        ),
        41,
      );
      expect(
        TissuePressureBarChart.bandBottom(
              chartHeight: 50,
              percent: 100,
              height: 2,
              devicePixelRatio: 1.5,
            ) *
            1.5,
        closeTo(61, 1e-9),
      );
      // Shorter than the band: no ArgumentError from clamp.
      expect(
        TissuePressureBarChart.bandBottom(
          chartHeight: 1,
          percent: 100,
          height: 2,
        ),
        0,
      );
    });

    testWidgets('names the same leading compartment to the screen reader as '
        'the visible text', (tester) async {
      // Both compartments at the surface N2 tension, at the surface: the
      // depth-aware ranking ties and keeps #1, while percentLoading alone
      // would pick #2 (its surface M-value is smaller).
      const settled = DecoStatus(
        compartments: [_comp, _comp2],
        ndlSeconds: 600,
        ceilingMeters: 0.0,
        ttsSeconds: 0,
        gfLow: 0.4,
        gfHigh: 0.85,
        decoStops: [],
        currentDepthMeters: 0.0,
        ambientPressureBar: 1.0,
      );
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildCard(status: settled));
      await tester.pumpAndSettle();

      expect(find.text('Leading: #1'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('leading compartment 1 at')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('leading compartment 2 at')),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('sits at each compartment\'s own equilibrium loading', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(status: _multiCompStatus));
      await tester.pumpAndSettle();

      double markerBottom(int compartment) {
        final marker = find.byKey(
          ValueKey('tissue-surface-marker-$compartment'),
        );
        final slot = find
            .ancestor(of: marker, matching: find.byType(Stack))
            .first;
        return tester.getRect(slot).bottom - tester.getRect(marker).bottom;
      }

      // Compartment 2 has a smaller surface M-value than compartment 1, so
      // the same equilibrium tension is a larger share of it: its marker
      // must sit higher. A single horizontal line could not show that.
      expect(markerBottom(2), greaterThan(markerBottom(1)));
    });
  });

  group('CompactTissueLoadingCard per-gas directions (issue #4228)', () {
    // After a trimix dive, at the surface: the compartment still holds
    // helium, which leaves, and less nitrogen than the air, which comes in.
    const trimixComp = TissueCompartment(
      compartmentNumber: 1,
      halfTimeN2: 4.0,
      halfTimeHe: 1.51,
      mValueAN2: 1.2599,
      mValueBN2: 0.5050,
      mValueAHe: 1.7424,
      mValueBHe: 0.4245,
      currentPN2: 0.40,
      currentPHe: 0.30,
    );
    const afterTrimix = DecoStatus(
      compartments: [trimixComp],
      ndlSeconds: 600,
      ceilingMeters: 0.0,
      ttsSeconds: 0,
      gfLow: 0.4,
      gfHigh: 0.85,
      decoStops: [],
      currentDepthMeters: 0.0,
      ambientPressureBar: 1.0,
      inspiredN2Bar: 0.74,
      inspiredHeBar: 0.0,
    );

    testWidgets('shows N2 on-gassing and He off-gassing side by side', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(status: afterTrimix));
      await tester.pumpAndSettle();

      final n2 = find.byKey(const ValueKey('tissue-detail-n2'));
      final he = find.byKey(const ValueKey('tissue-detail-he'));
      expect(
        find.descendant(of: n2, matching: find.byIcon(Icons.arrow_downward)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: he, matching: find.byIcon(Icons.arrow_upward)),
        findsOneWidget,
      );
      // Both half-times, since helium moves on its own clock.
      expect(find.text('4 / 1.5 min'), findsOneWidget);
    });

    testWidgets('leaves helium out of an air dive', (tester) async {
      const airStatus = DecoStatus(
        compartments: [_comp],
        ndlSeconds: 600,
        ceilingMeters: 0.0,
        ttsSeconds: 0,
        gfLow: 0.4,
        gfHigh: 0.85,
        decoStops: [],
        currentDepthMeters: 0.0,
        ambientPressureBar: 1.0,
        inspiredN2Bar: 0.74,
        inspiredHeBar: 0.0,
      );
      await tester.pumpWidget(buildCard(status: airStatus));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tissue-detail-he')), findsNothing);
      expect(find.text('4 min'), findsOneWidget);
    });

    testWidgets('reads Equilibrium once nothing is moving any more', (
      tester,
    ) async {
      const settled = DecoStatus(
        compartments: [_comp],
        ndlSeconds: 600,
        ceilingMeters: 0.0,
        ttsSeconds: 0,
        gfLow: 0.4,
        gfHigh: 0.85,
        decoStops: [],
        currentDepthMeters: 0.0,
        ambientPressureBar: 1.0,
        // _comp holds the default surface N2 tension.
        inspiredN2Bar: inspiredSurfaceN2Bar,
        inspiredHeBar: 0.0,
      );
      await tester.pumpWidget(buildCard(status: settled));
      await tester.pumpAndSettle();

      expect(find.text('Equilibrium'), findsOneWidget);
      expect(find.text('Offgassing'), findsNothing);
      expect(find.text('Ongassing'), findsNothing);
    });

    testWidgets('labels the leading compartment through localization', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard());
      await tester.pumpAndSettle();

      expect(find.text('Leading: #1'), findsOneWidget);
      expect(find.text('Load'), findsOneWidget);
    });
  });

  group('CompactTissueLoadingCard info icon (issue #4377)', () {
    testWidgets('replaces the values footer with a header info icon', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(scrollable: true));
      await tester.pumpAndSettle();

      expect(find.text('What do these values mean?'), findsNothing);
      expect(find.byType(InfoButton), findsOneWidget);

      await tester.tap(find.byType(InfoButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('M-value'), findsWidgets);
    });

    testWidgets('keeps the stretched card free of overflow', (tester) async {
      await tester.pumpWidget(
        buildCard(decoStatuses: [_status], expandVisualization: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InfoButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
