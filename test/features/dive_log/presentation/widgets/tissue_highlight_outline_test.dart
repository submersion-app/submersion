import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/presentation/widgets/highlight_outline.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_pressure_bar_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4431: the highlighted compartment's outline on the tissue charts
/// was one theme colour, which vanished on the heat map's black and white
/// cells. It is now a dark core inside a light halo, the same in both themes.
void main() {
  DecoStatus statusAt30m() {
    final algorithm = BuhlmannAlgorithm();
    algorithm.calculateSegment(
      depthMeters: 30,
      durationSeconds: 20 * 60,
      fN2: airN2Fraction,
      fHe: 0.0,
    );
    return algorithm.getDecoStatus(currentDepth: 30);
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  bool isStroke(List<dynamic> arguments, Color color, double width) {
    final paint = arguments.last;
    return paint is Paint &&
        paint.style == PaintingStyle.stroke &&
        paint.color.toARGB32() == color.toARGB32() &&
        paint.strokeWidth == width;
  }

  bool isHalo(Symbol method, List<dynamic> arguments, Symbol expected) =>
      method == expected &&
      isStroke(
        arguments,
        HighlightOutline.haloColor,
        HighlightOutline.haloWidth,
      );

  bool isCore(Symbol method, List<dynamic> arguments, Symbol expected) =>
      method == expected &&
      isStroke(
        arguments,
        HighlightOutline.coreColor,
        HighlightOutline.coreWidth,
      );

  group('HighlightOutline', () {
    test('pairs a light halo with a dark core, the halo the wider', () {
      expect(HighlightOutline.haloColor.computeLuminance(), greaterThan(0.9));
      expect(HighlightOutline.coreColor.computeLuminance(), lessThan(0.05));
      expect(
        HighlightOutline.haloWidth,
        greaterThan(HighlightOutline.coreWidth),
      );
    });

    testWidgets('the painter keeps the whole band inside its box', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(
          child: CustomPaint(
            size: Size(20, 40),
            painter: HighlightOutlinePainter(),
          ),
        ),
      );

      const inset = HighlightOutline.haloWidth / 2;
      final band = RRect.fromRectAndRadius(
        const Rect.fromLTRB(inset, inset, 20 - inset, 40 - inset),
        HighlightOutline.barRadius,
      );
      expect(
        find.byType(CustomPaint),
        paints
          ..rrect(
            rrect: band,
            color: HighlightOutline.haloColor,
            strokeWidth: HighlightOutline.haloWidth,
            style: PaintingStyle.stroke,
          )
          ..rrect(
            rrect: band,
            color: HighlightOutline.coreColor,
            strokeWidth: HighlightOutline.coreWidth,
            style: PaintingStyle.stroke,
          ),
      );
    });

    testWidgets('the painter does not paint past a box thinner than the band', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(
          child: CustomPaint(
            size: Size(20, 2),
            painter: HighlightOutlinePainter(),
          ),
        ),
      );

      // Centring the band on a box thinner than the band still lets half the
      // stroke width spill over its top and bottom, into the chart around a
      // nearly empty bar, so the painter clips to its own box first.
      expect(
        find.byType(CustomPaint),
        paints
          ..clipRect(rect: const Rect.fromLTWH(0, 0, 20, 2))
          ..something((method, arguments) {
            if (method != #drawRRect) return false;
            final rrect = arguments.first as RRect;
            return rrect.top >= 0 && rrect.bottom <= 2 && rrect.top <= 1;
          }),
      );
    });
  });

  group('TissuePressureBarChart highlight', () {
    for (final brightness in Brightness.values) {
      testWidgets('outlines only the highlighted bar with the two-tone band '
          'in ${brightness.name} mode', (tester) async {
        await pump(
          tester,
          TissuePressureBarChart(status: statusAt30m(), highlightedIndex: 3),
          brightness: brightness,
        );

        final outlined = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.foregroundPainter is HighlightOutlinePainter,
        );
        expect(outlined, findsOneWidget);
        expect(
          outlined,
          paints
            ..something((m, a) => isHalo(m, a, #drawRRect))
            ..something((m, a) => isCore(m, a, #drawRRect)),
        );
      });
    }

    testWidgets('draws no outline when nothing is highlighted', (tester) async {
      await pump(tester, TissuePressureBarChart(status: statusAt30m()));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.foregroundPainter is HighlightOutlinePainter,
        ),
        findsNothing,
      );
    });
  });

  group('TissueHeatMapStrip highlight', () {
    const stripHeight = 72.0;

    Widget strip({int? hovered, int? selected}) {
      final status = statusAt30m();
      return TissueHeatMapStrip(
        decoStatuses: List.filled(20, status),
        height: stripHeight,
        colorFn: subsurfaceHeatColor,
        hoveredCompartmentIndex: hovered,
        selectedIndex: selected,
      );
    }

    for (final brightness in Brightness.values) {
      testWidgets('rings the hovered row with the two-tone band in '
          '${brightness.name} mode', (tester) async {
        await pump(tester, strip(hovered: 3), brightness: brightness);

        expect(
          find.byType(TissueHeatMapStrip),
          paints
            ..something((m, a) => isHalo(m, a, #drawRRect))
            ..something((m, a) => isCore(m, a, #drawRRect)),
        );
      });
    }

    testWidgets('puts the band outside the row so the row stays visible, '
        'and inside the strip at its ends', (tester) async {
      await pump(tester, strip(hovered: 3));

      final width = tester.getSize(find.byType(TissueHeatMapStrip)).width;
      const rowHeight = stripHeight / 16;
      const half = HighlightOutline.haloWidth / 2;
      final expected = RRect.fromLTRBR(
        half,
        3 * rowHeight - half,
        width - half,
        4 * rowHeight + half,
        Radius.zero,
      );

      expect(
        find.byType(TissueHeatMapStrip),
        paints..something((method, arguments) {
          if (!isHalo(method, arguments, #drawRRect)) return false;
          final rrect = arguments.first as RRect;
          return (rrect.left - expected.left).abs() < 0.01 &&
              (rrect.top - expected.top).abs() < 0.01 &&
              (rrect.right - expected.right).abs() < 0.01 &&
              (rrect.bottom - expected.bottom).abs() < 0.01;
        }),
      );
    });

    testWidgets('draws the time cursor with the two-tone band too', (
      tester,
    ) async {
      await pump(tester, strip(selected: 5));

      expect(
        find.byType(TissueHeatMapStrip),
        paints
          ..something((m, a) => isHalo(m, a, #drawLine))
          ..something((m, a) => isCore(m, a, #drawLine)),
      );
    });
  });
}
