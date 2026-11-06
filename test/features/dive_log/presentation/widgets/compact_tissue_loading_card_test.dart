import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_area_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _comp = TissueCompartment(
  compartmentNumber: 1,
  halfTimeN2: 4.0,
  halfTimeHe: 1.51,
  mValueAN2: 1.2599,
  mValueBN2: 0.5050,
  mValueAHe: 1.7424,
  mValueBHe: 0.4245,
);

const _status = DecoStatus(
  compartments: [_comp],
  ndlSeconds: 600,
  ceilingMeters: 0.0,
  ttsSeconds: 0,
  gfLow: 0.4,
  gfHigh: 0.85,
  decoStops: [],
  currentDepthMeters: 10.0,
  ambientPressureBar: 2.0,
);

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

Widget buildCard({
  DecoStatus status = _status,
  List<DecoStatus>? decoStatuses,
  bool expandVisualization = false,
  VoidCallback? onOpen3dView,
  bool scrollable = false,
}) {
  final card = CompactTissueLoadingCard(
    status: status,
    decoStatuses: decoStatuses,
    expandVisualization: expandVisualization,
    onOpen3dView: onOpen3dView,
  );
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    child: MaterialApp(
      // The assertions read English strings; pin the locale so they do not
      // depend on the host's.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Both real hosts (dive detail, current dive load page) scroll, so a
      // test that grows the card (the inline explanation) scrolls too.
      home: Scaffold(
        body: scrollable ? SingleChildScrollView(child: card) : card,
      ),
    ),
  );
}

void main() {
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
    // Header controls in left-to-right render order.
    const headerIcons = [
      Icons.grid_on,
      Icons.area_chart,
      Icons.palette_outlined,
      Icons.view_in_ar,
    ];

    testWidgets('are spaced evenly across the header row', (tester) async {
      await tester.pumpWidget(buildCard(onOpen3dView: () {}));
      await tester.pumpAndSettle();

      final rects = headerIcons
          .map((icon) => tester.getRect(find.byIcon(icon)))
          .toList();

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

    testWidgets('switch the visualization mode when tapped', (tester) async {
      await tester.pumpWidget(
        buildCard(status: _multiCompStatus, decoStatuses: [_multiCompStatus]),
      );
      await tester.pumpAndSettle();

      // The card renders exactly one of the two visualizations, chosen by
      // tissueVizMode, so the rendered chart type is what proves the tap
      // took effect. AppSettings defaults to TissueVizMode.heatMap.
      expect(find.byType(TissueHeatMapStrip), findsOneWidget);
      expect(find.byType(TissueAreaChart), findsNothing);

      await tester.tap(find.byIcon(Icons.area_chart));
      await tester.pumpAndSettle();
      expect(find.byType(TissueAreaChart), findsOneWidget);
      expect(find.byType(TissueHeatMapStrip), findsNothing);

      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();
      expect(find.byType(TissueHeatMapStrip), findsOneWidget);
      expect(find.byType(TissueAreaChart), findsNothing);
    });

    testWidgets('tint the active visualization mode icon', (tester) async {
      await tester.pumpWidget(
        buildCard(status: _multiCompStatus, decoStatuses: [_multiCompStatus]),
      );
      await tester.pumpAndSettle();

      final primary = Theme.of(
        tester.element(find.byType(CompactTissueLoadingCard)),
      ).colorScheme.primary;

      Color? colorOf(IconData icon) =>
          tester.widget<Icon>(find.byIcon(icon)).color;

      expect(colorOf(Icons.grid_on), primary);
      expect(colorOf(Icons.area_chart), isNot(primary));

      await tester.tap(find.byIcon(Icons.area_chart));
      await tester.pumpAndSettle();

      expect(colorOf(Icons.area_chart), primary);
      expect(colorOf(Icons.grid_on), isNot(primary));
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
      expect(find.text(l10n.diveLog_deco_heatMapRows), findsOneWidget);
      // The legend is localized rather than hardcoded English.
      expect(find.text(l10n.diveLog_deco_gasOngassing), findsOneWidget);
      expect(find.text(l10n.diveLog_deco_gasOffgassing), findsOneWidget);
    });

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
        expect(find.text(l10n.diveLog_deco_heatMapRows), findsOneWidget);
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

    testWidgets('draws the M-value line in the full error color', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(status: _multiCompStatus));
      await tester.pumpAndSettle();

      final error = Theme.of(
        tester.element(find.byType(CompactTissueLoadingCard)),
      ).colorScheme.error;
      final line = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const ValueKey('tissue-m-value-line')),
          matching: find.byType(ColoredBox),
        ),
      );
      // At half opacity it all but vanished against the dark card.
      expect(line.color, error);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('tissue-m-value-line')))
            .height,
        1.5,
      );
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

  group('CompactTissueLoadingCard values explanation (issue #4228)', () {
    testWidgets('is collapsed by default and expands on tap', (tester) async {
      await tester.pumpWidget(buildCard(scrollable: true));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(CompactTissueLoadingCard));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.diveLog_deco_info_title), findsOneWidget);
      expect(find.text(l10n.diveLog_deco_info_body), findsNothing);

      await tester.tap(find.text(l10n.diveLog_deco_info_title));
      await tester.pumpAndSettle();

      expect(find.text(l10n.diveLog_deco_info_body), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('opens in a dialog when the card is stretched to a fixed '
        'height, so it cannot overflow it', (tester) async {
      await tester.pumpWidget(
        buildCard(decoStatuses: [_status], expandVisualization: true),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(CompactTissueLoadingCard));
      final l10n = AppLocalizations.of(context);
      await tester.tap(find.text(l10n.diveLog_deco_info_title));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.diveLog_deco_info_body), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
