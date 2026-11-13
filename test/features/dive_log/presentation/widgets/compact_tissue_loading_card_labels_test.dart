import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_compartment_detail.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map_axes.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_pressure_bar_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import 'tissue_card_test_helpers.dart';

/// Issue #4503: the Tissue Loading card names what a compartment number
/// stands for, numbers its bars and labels the heat map's axes.
void main() {
  group('CompactTissueLoadingCard compartment group (issue #4503)', () {
    // Loaded above air's inspired nitrogen, so the compartment off-gasses and
    // the direction badge shows beside the number.
    final withBadge = DecoStatus(
      compartments: [testCompartment.copyWith(currentPN2: 1.5)],
      ndlSeconds: 600,
      ceilingMeters: 0.0,
      ttsSeconds: 0,
      gfLow: 0.4,
      gfHigh: 0.85,
      decoStops: const [],
      currentDepthMeters: 0.0,
      ambientPressureBar: 1.0,
      inspiredN2Bar: 0.74,
      inspiredHeBar: 0.0,
    );

    testWidgets('names the group on its own line under the number', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard(status: withBadge));
      await tester.pumpAndSettle();

      final number = tester.getRect(find.text('Leading: #1'));
      final group = tester.getRect(find.text('Fast, blood-rich tissue'));
      final badge = tester.getRect(find.text('Offgassing'));
      expect(group.top, greaterThanOrEqualTo(number.bottom));
      // The badge keeps its place beside the number.
      expect(badge.center.dy, closeTo(number.center.dy, 1));
    });

    testWidgets('keeps one height from bar to bar at large text', (
      tester,
    ) async {
      final sixteen = sixteenCompartmentStatus();
      Future<double> heightFor(int index) async {
        await tester.pumpWidget(
          MaterialApp(
            // German at twice the text size on a phone: the fast group's
            // label is the longest and wrapped where the medium one did not.
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 334,
                    child: TissueCompartmentDetail(
                      status: sixteen,
                      displayIndex: index,
                      isLeading: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        return tester.getSize(find.byType(TissueCompartmentDetail)).height;
      }

      // Compartments 5 and 6 sit either side of the fast / medium split,
      // so their group lines differ in length.
      final fast = await heightFor(4);
      final medium = await heightFor(5);
      expect(fast, medium);
      // Shrunk to one line, never cut short.
      expect(find.text('Mittel, Muskeln und Haut'), findsOneWidget);
    });

    testWidgets('fits a phone with the badge and the group line', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(334, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildCard(status: withBadge, scrollable: true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fast, blood-rich tissue'), findsOneWidget);
    });
  });

  group('TissuePressureBarChart bar numbers (issue #4503)', () {
    final sixteen = sixteenCompartmentStatus();
    Finder inChart(Finder f) =>
        find.descendant(of: find.byType(TissuePressureBarChart), matching: f);

    for (final direction in TextDirection.values) {
      testWidgets('numbers every bar under its own bar (${direction.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildCard(status: sixteen, textDirection: direction),
        );
        await tester.pumpAndSettle();

        // Each bar sits in its own tooltip, in compartment order.
        final bars = tester.widgetList<Tooltip>(inChart(find.byType(Tooltip)));
        expect(bars, hasLength(16));
        final cells = [
          for (final bar in bars) tester.getRect(find.byWidget(bar)),
        ];
        for (var n = 1; n <= 16; n++) {
          final number = inChart(find.text('$n'));
          expect(number, findsOneWidget, reason: 'bar $n');
          expect(
            tester.getCenter(number).dx,
            closeTo(cells[n - 1].center.dx, 1),
            reason: 'bar $n',
          );
        }
      });
    }

    testWidgets('keeps the numbers inside their cells at 2x text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(334, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: buildCard(status: sixteen, scrollable: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(inChart(find.text('16')), findsOneWidget);
    });

    testWidgets('leaves the numbers to the chart\'s own spoken label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildCard(status: sixteen));
      await tester.pumpAndSettle();

      // Drawn, so the check below is not passing on an empty row.
      expect(inChart(find.text('16')), findsOneWidget);
      // The card reads as one merged node; a spoken number would be a line
      // of its own in that label ("...|15|16|Fast...").
      final spoken = tester
          .getSemantics(inChart(find.text('16')))
          .label
          .split('\n');
      expect(spoken, isNot(contains('16')));
      semantics.dispose();
    });
  });

  group('CompactTissueLoadingCard heat map axes (issue #4503)', () {
    final sixteen = sixteenCompartmentStatus();
    final timeline = List.filled(33, sixteen);
    final timestamps = [for (var t = 0; t <= 1920; t += 60) t];
    Finder inAxis<T>(String text) =>
        find.descendant(of: find.byType(T), matching: find.text(text));

    testWidgets('labels the heat map with compartments and dive time', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(
          status: sixteen,
          decoStatuses: timeline,
          profileTimestamps: timestamps,
        ),
      );
      await tester.pumpAndSettle();

      final strip = tester.getRect(find.byType(TissueHeatMapStrip));
      final time = tester.getRect(find.byType(TissueHeatMapTimeAxis));
      final rows = tester.getRect(find.byType(TissueHeatMapCompartmentAxis));
      expect(time.left, closeTo(strip.left, 0.5));
      expect(time.right, closeTo(strip.right, 0.5));
      expect(time.top, greaterThanOrEqualTo(strip.bottom));
      expect(rows.right, lessThanOrEqualTo(strip.left));
      expect(rows.top, closeTo(strip.top, 0.5));
      expect(rows.bottom, closeTo(strip.bottom, 0.5));
      expect(inAxis<TissueHeatMapCompartmentAxis>('16'), findsOneWidget);
      expect(inAxis<TissueHeatMapTimeAxis>('32 min'), findsOneWidget);
    });

    for (final (name, stamps) in [
      ('no timestamps', null),
      ('a mismatched timeline', [0, 60]),
    ]) {
      testWidgets('leaves the time axis out with $name', (tester) async {
        await tester.pumpWidget(
          buildCard(
            status: sixteen,
            decoStatuses: timeline,
            profileTimestamps: stamps,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TissueHeatMapCompartmentAxis), findsOneWidget);
        expect(find.byType(TissueHeatMapTimeAxis), findsNothing);
      });
    }

    testWidgets('keeps both axes left to right in a right-to-left locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(
          status: sixteen,
          decoStatuses: timeline,
          profileTimestamps: timestamps,
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();

      // The painter always runs time left to right, so the labels must too.
      final strip = tester.getRect(find.byType(TissueHeatMapStrip));
      final rows = tester.getRect(find.byType(TissueHeatMapCompartmentAxis));
      expect(rows.right, lessThanOrEqualTo(strip.left));
      expect(
        tester.getCenter(inAxis<TissueHeatMapTimeAxis>('0 min')).dx,
        lessThan(tester.getCenter(inAxis<TissueHeatMapTimeAxis>('32 min')).dx),
      );
    });

    testWidgets('stretches the compartment axis with an expanded card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderScope(
            overrides: [
              settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            ],
            child: Scaffold(
              body: SizedBox(
                height: 900,
                child: CompactTissueLoadingCard(
                  status: sixteen,
                  decoStatuses: timeline,
                  profileTimestamps: timestamps,
                  expandVisualization: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final strip = tester.getRect(find.byType(TissueHeatMapStrip));
      final last = tester.getCenter(inAxis<TissueHeatMapCompartmentAxis>('16'));
      // The last row's centre: half a row above the strip's bottom.
      expect(last.dy, closeTo(strip.bottom - strip.height / 32, 1));
    });
  });
}
