import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_table.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_time_columns.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'sac_segments_test_harness.dart';

void main() {
  group('colors', () {
    final hues = {
      for (final phase in DivePhase.values) ...{
        '${phase.name} light': (
          SacSegmentColors.forPhase(phase, Brightness.light),
          Brightness.light,
        ),
        '${phase.name} dark': (
          SacSegmentColors.forPhase(phase, Brightness.dark),
          Brightness.dark,
        ),
      },
      for (final brightness in Brightness.values)
        for (final gas in [
          GasColors.air,
          GasColors.nitrox,
          GasColors.oxygen,
          GasColors.trimix,
        ])
          'gas ${gas.toARGB32()} ${brightness.name}': (gas, brightness),
    };

    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        final theme = AppThemeRegistry.resolveTheme(preset, brightness);
        final scheme = theme.colorScheme;
        final card = Color.alphaBlend(
          theme.cardTheme.color ?? scheme.surfaceContainerLow,
          scheme.surface,
        );

        test('stand out with no hue on ${preset.id} ${brightness.name}', () {
          final idle = SacSegmentColors.idle(scheme.primary, theme);

          expect(contrastRatio(idle, card), greaterThan(1.4));
          expect(contrastRatio(scheme.primary, idle), greaterThan(1.2));
        });

        for (final MapEntry(key: name, value: (hue, mode)) in hues.entries) {
          if (mode != brightness) continue;

          test('$name stands out on ${preset.id} ${brightness.name}', () {
            final idle = SacSegmentColors.idle(hue, theme);

            expect(contrastRatio(idle, card), greaterThan(1.4));
            expect(contrastRatio(hue, idle), greaterThan(1.2));
          });

          test('$name keeps a row label readable on ${preset.id} '
              '${brightness.name}', () {
            final bar = SacSegmentColors.barFill(hue, theme);

            expect(contrastRatio(scheme.onSurface, bar), greaterThan(4.5));
            expect(contrastRatio(bar, card), greaterThan(1.1));
          });
        }
      }
    }

    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        test('resolve to opaque on ${preset.id} ${brightness.name}', () {
          final theme = AppThemeRegistry.resolveTheme(preset, brightness);

          expect(SacSegmentColors.idle(Colors.blue, theme).a, 1.0);
          expect(SacSegmentColors.barFill(Colors.blue, theme).a, 1.0);
        });
      }
    }

    test('give every phase its own hue', () {
      for (final brightness in Brightness.values) {
        final colors = {
          for (final phase in DivePhase.values)
            SacSegmentColors.forPhase(phase, brightness),
        };
        expect(colors, hasLength(DivePhase.values.length));
      }
    });

    Color columnColor(WidgetTester tester, int index) {
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(SacTimeColumns.plotKey),
          matching: find.byType(DecoratedBox),
        ),
      );
      return (boxes.elementAt(index).decoration as BoxDecoration).color!;
    }

    testWidgets('a column takes the color of the phase it mostly falls in', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester);
      final theme = Theme.of(tester.element(find.byType(SacTimeColumns)));
      Color idle(DivePhase phase) => SacSegmentColors.idle(
        SacSegmentColors.forPhase(phase, theme.brightness),
        theme,
      );

      expect(columnColor(tester, 0), idle(DivePhase.bottom));
      expect(columnColor(tester, 1), idle(DivePhase.bottom));
      expect(columnColor(tester, 3), idle(DivePhase.safetyStop));
    });

    testWidgets('the selected column draws at full strength', (tester) async {
      await pumpSacSegmentsView(tester, selectedTimestamp: 7 * 60);
      final scheme = Theme.of(
        tester.element(find.byType(SacTimeColumns)),
      ).colorScheme;

      expect(
        columnColor(tester, 1),
        SacSegmentColors.forPhase(DivePhase.bottom, scheme.brightness),
      );
    });

    testWidgets('columns stay on the primary color with no phase data', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester, phases: const []);
      final theme = Theme.of(tester.element(find.byType(SacTimeColumns)));

      expect(
        columnColor(tester, 0),
        SacSegmentColors.idle(theme.colorScheme.primary, theme),
      );
    });

    testWidgets('a phase row uses the color of its columns', (tester) async {
      await pumpSacSegmentsView(tester, gases: const []);
      final scheme = Theme.of(
        tester.element(find.byType(SacTimeColumns)),
      ).colorScheme;

      final rows = tester
          .widget<SacSegmentTable>(find.byType(SacSegmentTable))
          .sections
          .single
          .rows;
      expect(rows.map((r) => r.color), [
        for (final phase in [
          DivePhase.descent,
          DivePhase.bottom,
          DivePhase.ascent,
          DivePhase.safetyStop,
        ])
          SacSegmentColors.forPhase(phase, scheme.brightness),
      ]);
    });

    testWidgets('a gas row uses the color of its gas everywhere else', (
      tester,
    ) async {
      await pumpSacSegmentsView(
        tester,
        phases: const [],
        gases: [
          sacSegment(
            0,
            15,
            tankId: 'back',
            gasMix: const GasMix(o2: 18, he: 45),
          ),
          sacSegment(15, 20, tankId: 'deco', gasMix: const GasMix(o2: 50)),
        ],
      );

      final rows = tester
          .widget<SacSegmentTable>(find.byType(SacSegmentTable))
          .sections
          .single
          .rows;
      expect(rows.map((r) => r.color), [GasColors.trimix, GasColors.nitrox]);
    });

    testWidgets('a gas row with no known mix has no color of its own', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester, phases: const []);

      final rows = tester
          .widget<SacSegmentTable>(find.byType(SacSegmentTable))
          .sections
          .single
          .rows;
      expect(rows.map((r) => r.color), everyElement(isNull));
    });
  });

  group('rate axis', () {
    double columnFactor(WidgetTester tester, int index) => tester
        .widgetList<FractionallySizedBox>(
          find.descendant(
            of: find.byKey(SacTimeColumns.plotKey),
            matching: find.byType(FractionallySizedBox),
          ),
        )
        .elementAt(index)
        .heightFactor!;

    testWidgets('labels the scale, with the unit on the top line', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester);

      expect(find.text('20 L/min'), findsOneWidget);
      expect(find.text('10'), findsAtLeastNWidgets(1));
      // Zero is also the first mark on the time axis.
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('follows the lane in view', (tester) async {
      await pumpSacSegmentsView(
        tester,
        rates: sacRates(lane: GasConsumptionLane.sac),
      );

      expect(find.text('2 bar/min'), findsOneWidget);
    });

    testWidgets('follows the diver\'s units', (tester) async {
      await pumpSacSegmentsView(
        tester,
        rates: SacRateDisplay(
          units: const UnitFormatter(
            AppSettings(pressureUnit: PressureUnit.psi),
          ),
          lane: GasConsumptionLane.sac,
          normalizationFactor: 1.0,
          volumeFor: (_) => null,
        ),
      );

      expect(find.text('30 psi/min'), findsOneWidget);
    });

    testWidgets('falls back to pressure when a column cannot convert', (
      tester,
    ) async {
      await pumpSacSegmentsView(
        tester,
        time: [
          sacSegment(0, 5, tankId: 'back', sacRate: 2.0),
          sacSegment(5, 10, tankId: 'stage'),
        ],
        rates: sacRates(volumeFor: (id) => id == 'back' ? 10.0 : null),
      );

      expect(find.text('2 bar/min'), findsOneWidget);
    });

    testWidgets('a column reaches the value it reads on the axis', (
      tester,
    ) async {
      await pumpSacSegmentsView(
        tester,
        time: [sacSegment(0, 5, sacRate: 2.2), sacSegment(5, 10, sacRate: 1.1)],
      );

      // 22 L/min on an axis that tops out at 30.
      expect(find.text('30 L/min'), findsOneWidget);
      expect(columnFactor(tester, 0), closeTo(22 / 30, 1e-9));
      expect(columnFactor(tester, 1), closeTo(11 / 30, 1e-9));
    });

    testWidgets('the average line uses the same scale', (tester) async {
      await pumpSacSegmentsView(
        tester,
        time: [sacSegment(0, 5, sacRate: 2.2), sacSegment(5, 10, sacRate: 1.1)],
      );

      final chart = tester.widget<SacTimeColumns>(find.byType(SacTimeColumns));
      expect(chart.averageFactor, closeTo(16.5 / 30, 1e-9));
    });

    testWidgets('leaves the axis off a dive with no consumption', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester, time: [sacSegment(0, 5, sacRate: 0)]);

      expect(
        tester.widget<SacTimeColumns>(find.byType(SacTimeColumns)).rateTicks,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sits left of the plot in a right-to-left locale', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester, locale: const Locale('ar'));
      final plot = tester.getRect(find.byKey(SacTimeColumns.plotKey));
      final chart = tester.getRect(find.byType(SacTimeColumns));

      expect(plot.right, chart.right);
      expect(plot.left, greaterThan(chart.left));
    });

    testWidgets('leaves the screen reader on the columns', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSacSegmentsView(tester);

      expect(find.bySemanticsLabel('20 L/min'), findsNothing);
      handle.dispose();
    });

    testWidgets('picks the right column across the plot, not the card', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester);
      final plot = tester.getRect(find.byKey(SacTimeColumns.plotKey));

      Future<void> tapAcross(double share) async {
        await tester.tapAt(
          Offset(plot.left + plot.width * share, plot.top + 30),
        );
        await tester.pump();
      }

      await tapAcross(0.55);
      expect(find.textContaining('10-15 min ·'), findsOneWidget);

      await tapAcross(0.8);
      expect(find.textContaining('15-20 min ·'), findsOneWidget);
    });
  });

  group('rate axis at large text', () {
    // The page scrolls; these check the chart, not the 600 point test window.
    void tallWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(2400, 4800);
      addTearDown(tester.view.resetPhysicalSize);
    }

    List<Rect> rateLabels(WidgetTester tester) {
      final plot = tester.getRect(find.byKey(SacTimeColumns.plotKey));
      return [
          for (final element
              in find
                  .descendant(
                    of: find.byType(SacTimeColumns),
                    matching: find.byType(Text),
                  )
                  .evaluate())
            tester.getRect(find.byWidget(element.widget)),
        ].where((rect) => rect.right < plot.left).toList()
        ..sort((a, b) => a.top.compareTo(b.top));
    }

    for (final scale in [1.0, 1.5, 2.0, 3.0, 4.0]) {
      testWidgets('labels stay apart at text x$scale', (tester) async {
        tallWindow(tester);
        await pumpSacSegmentsView(
          tester,
          // 15 L/min, the peak that draws the most lines.
          time: [sacSegment(0, 5, sacRate: 1.5)],
          textScaler: TextScaler.linear(scale),
        );

        final rects = rateLabels(tester);
        expect(rects, isNotEmpty);
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i].top, greaterThanOrEqualTo(rects[i - 1].bottom));
        }
      });
    }

    testWidgets('keeps the top line, with its unit, as labels thin out', (
      tester,
    ) async {
      tallWindow(tester);
      await pumpSacSegmentsView(
        tester,
        time: [sacSegment(0, 5, sacRate: 1.5)],
        textScaler: const TextScaler.linear(3),
      );

      expect(find.text('15 L/min'), findsOneWidget);
    });
  });

  group('time axis', () {
    List<Text> axisLabels(WidgetTester tester) {
      final columns = find.byType(SacTimeColumns);
      final plot = tester.getRect(find.byKey(SacTimeColumns.plotKey));
      return tester
          .widgetList<Text>(
            find.descendant(of: columns, matching: find.byType(Text)),
          )
          .where((t) => t.data != null && t.data!.isNotEmpty)
          .where((t) {
            final rect = tester.getRect(find.byWidget(t));
            return rect.top >= plot.bottom;
          })
          .toList();
    }

    final fiftyMinutes = [
      for (var i = 0; i < 10; i++) sacSegment(i * 5, (i + 1) * 5),
    ];

    testWidgets('measures once while only the selection changes', (
      tester,
    ) async {
      var endLabels = 0;
      Widget chart(int? active) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 342,
            child: SacTimeColumns(
              columns: const [
                SacTimeColumn(
                  startSeconds: 0,
                  durationSeconds: 3000,
                  heightFactor: 1,
                  semanticLabel: 'all',
                ),
              ],
              averageFactor: 0.5,
              activeIndex: active,
              endLabel: (minutes) {
                if (minutes > 0) endLabels++;
                return '$minutes min';
              },
              onTap: (_) {},
              onScrub: (_) {},
              onHover: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(chart(null));
      final measured = endLabels;
      await tester.pumpWidget(chart(0));

      // Only the one label drawn, none measured.
      expect(endLabels, measured + 1);
    });

    testWidgets('measures again when a font arrives', (tester) async {
      var endLabels = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 342,
              child: SacTimeColumns(
                columns: const [
                  SacTimeColumn(
                    startSeconds: 0,
                    durationSeconds: 3000,
                    heightFactor: 1,
                    semanticLabel: 'all',
                  ),
                ],
                averageFactor: 0.5,
                activeIndex: null,
                endLabel: (minutes) {
                  if (minutes > 0) endLabels++;
                  return '$minutes min';
                },
                onTap: (_) {},
                onScrub: (_) {},
                onHover: (_) {},
              ),
            ),
          ),
        ),
      );
      final measured = endLabels;

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.system.name,
        SystemChannels.system.codec.encodeMessage(<String, Object?>{
          'type': 'fontsChange',
        }),
        (_) {},
      );
      await tester.pump();

      // More than the one label a rebuild draws: the marks were measured.
      expect(endLabels, greaterThan(measured + 1));
    });

    void widenWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(4800, 1800);
      addTearDown(tester.view.resetPhysicalSize);
    }

    testWidgets('adds marks as the card widens', (tester) async {
      widenWindow(tester);
      await pumpSacSegmentsView(tester, time: fiftyMinutes, width: 342);
      final narrow = axisLabels(tester).length;

      await pumpSacSegmentsView(tester, time: fiftyMinutes, width: 1200);

      expect(axisLabels(tester).length, greaterThan(narrow));
    });

    testWidgets('marks every column once there is room', (tester) async {
      widenWindow(tester);
      await pumpSacSegmentsView(tester, time: fiftyMinutes, width: 1200);

      expect(axisLabels(tester).map((t) => t.data), [
        for (var minutes = 0; minutes < 50; minutes += 5) '$minutes',
        '50 min',
      ]);
    });

    for (final (width, scale) in [
      (300.0, 1.0),
      (342.0, 1.0),
      (760.0, 1.0),
      (342.0, 1.5),
      (760.0, 2.0),
    ]) {
      testWidgets('no labels touch at $width wide, text x$scale', (
        tester,
      ) async {
        await pumpSacSegmentsView(
          tester,
          time: [for (var i = 0; i < 24; i++) sacSegment(i * 5, (i + 1) * 5)],
          width: width,
          textScaler: TextScaler.linear(scale),
        );

        final rects = [
          for (final label in axisLabels(tester))
            tester.getRect(find.byWidget(label)),
        ];
        expect(rects.length, greaterThan(1));
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i].left, greaterThan(rects[i - 1].right));
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('sacTimeAxisMarks', () {
    // Close to the card's real label font, at 6 points a character.
    double measured(int tick, {required bool isLast}) =>
        ('$tick'.length + (isLast ? 4 : 0)) * 6.0;

    List<int> marks(int minutes, double width) => sacTimeAxisMarks(
      totalSeconds: minutes * 60,
      width: width,
      labelWidth: measured,
    );

    test('labels every ten minutes on a phone', () {
      expect(marks(52, 280), [0, 10, 20, 30, 40, 50]);
    });

    test('labels every column on a wide card', () {
      expect(marks(52, 700), [for (var m = 0; m <= 50; m += 5) m]);
    });

    test('backs off as labels widen', () {
      double wide(int tick, {required bool isLast}) => 60;

      expect(
        sacTimeAxisMarks(totalSeconds: 3120, width: 280, labelWidth: wide),
        [0, 20, 40],
      );
    });

    test('holds a short dive to its only mark', () {
      expect(marks(0, 280), [0]);
      expect(marks(3, 280), [0]);
    });

    test('stops at the last whole step inside the dive', () {
      expect(marks(47, 280), [0, 10, 20, 30, 40]);
    });

    test('thins out a very long dive', () {
      expect(marks(1000, 280), [0, 240, 480, 720, 960]);
    });

    test('settles on the widest step when even that one collides', () {
      double huge(int tick, {required bool isLast}) => 500;

      expect(
        sacTimeAxisMarks(totalSeconds: 60000, width: 100, labelWidth: huge),
        [0, 240, 480, 720, 960],
      );
    });

    test('still returns marks when nothing fits', () {
      double huge(int tick, {required bool isLast}) => 500;

      expect(
        sacTimeAxisMarks(totalSeconds: 3000, width: 100, labelWidth: huge),
        isNotEmpty,
      );
    });
  });
}
