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
/// was the theme's text colour, which vanished on the heat map's black and
/// purple cells in light mode and its white cells in dark mode. It is now a
/// single line drawn so it covers neither the highlighted row nor anything
/// outside the highlighted bar: the theme's accent (primary) colour, except
/// on the heat map in light mode, where it is white.
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

  Color primaryOf(Brightness brightness) =>
      ThemeData(brightness: brightness).colorScheme.primary;

  // The heat map's highlight: white in light mode, where the accent is a
  // dark blue that vanishes on the scale's black and purple cells; the
  // accent (a light blue) in dark mode.
  Color heatMapHighlightOf(Brightness brightness) =>
      brightness == Brightness.light ? Colors.white : primaryOf(brightness);

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

  bool isOutline(
    Symbol method,
    List<dynamic> arguments,
    Symbol expected,
    Color color,
  ) {
    if (method != expected || arguments.isEmpty) return false;
    final paint = arguments.last;
    return paint is Paint &&
        paint.style == PaintingStyle.stroke &&
        paint.color.toARGB32() == color.toARGB32() &&
        paint.strokeWidth == HighlightOutline.width;
  }

  group('HighlightOutline', () {
    test('takes the theme accent colour', () {
      for (final brightness in Brightness.values) {
        final scheme = ThemeData(brightness: brightness).colorScheme;
        expect(HighlightOutline.colorOf(scheme), scheme.primary);
      }
    });

    test('takes white on the heat map in light mode, the accent in dark', () {
      for (final brightness in Brightness.values) {
        final scheme = ThemeData(brightness: brightness).colorScheme;
        expect(
          HighlightOutline.heatMapColorOf(scheme),
          heatMapHighlightOf(brightness),
        );
      }
    });

    testWidgets('the painter keeps the whole line inside its box', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(
          child: CustomPaint(
            size: Size(20, 40),
            painter: HighlightOutlinePainter(color: Colors.teal),
          ),
        ),
      );

      const inset = HighlightOutline.width / 2;
      expect(
        find.byType(CustomPaint),
        paints
          ..clipRect(rect: const Rect.fromLTWH(0, 0, 20, 40))
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              const Rect.fromLTRB(inset, inset, 20 - inset, 40 - inset),
              HighlightOutline.barRadius,
            ),
            color: Colors.teal,
            strokeWidth: HighlightOutline.width,
            style: PaintingStyle.stroke,
          ),
      );
    });

    testWidgets('the painter does not paint past a box thinner than the line', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(
          child: CustomPaint(
            size: Size(20, 1),
            painter: HighlightOutlinePainter(color: Colors.teal),
          ),
        ),
      );

      // Centring the line on a box thinner than the line still lets half the
      // stroke width spill over its top and bottom, into the chart around a
      // nearly empty bar, so the painter clips to its own box first.
      expect(
        find.byType(CustomPaint),
        paints
          ..clipRect(rect: const Rect.fromLTWH(0, 0, 20, 1))
          ..something((method, arguments) {
            if (method != #drawRRect) return false;
            final rrect = arguments.first as RRect;
            return rrect.top >= 0 && rrect.bottom <= 1;
          }),
      );
    });

    test('the painter repaints when its colour changes', () {
      const painter = HighlightOutlinePainter(color: Colors.teal);
      expect(
        painter.shouldRepaint(
          const HighlightOutlinePainter(color: Colors.teal),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          const HighlightOutlinePainter(color: Colors.orange),
        ),
        isTrue,
      );
    });
  });

  group('TissuePressureBarChart highlight', () {
    Finder outlinedBars() => find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.foregroundPainter is HighlightOutlinePainter,
    );

    for (final brightness in Brightness.values) {
      testWidgets('outlines only the highlighted bar in the accent colour '
          'in ${brightness.name} mode', (tester) async {
        await pump(
          tester,
          TissuePressureBarChart(status: statusAt30m(), highlightedIndex: 3),
          brightness: brightness,
        );

        expect(outlinedBars(), findsOneWidget);
        final painter =
            tester.widget<CustomPaint>(outlinedBars()).foregroundPainter!
                as HighlightOutlinePainter;
        expect(painter.color, primaryOf(brightness));
      });
    }

    testWidgets('draws no outline when nothing is highlighted', (tester) async {
      await pump(tester, TissuePressureBarChart(status: statusAt30m()));

      expect(outlinedBars(), findsNothing);
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
      testWidgets('outlines the hovered row in its highlight colour in '
          '${brightness.name} mode', (tester) async {
        await pump(tester, strip(hovered: 3), brightness: brightness);

        expect(
          find.byType(TissueHeatMapStrip),
          paints..something(
            (m, a) =>
                isOutline(m, a, #drawRect, heatMapHighlightOf(brightness)),
          ),
        );
      });
    }

    testWidgets('puts the line outside the row so the row stays visible, '
        'and inside the strip at its ends', (tester) async {
      await pump(tester, strip(hovered: 3));

      final width = tester.getSize(find.byType(TissueHeatMapStrip)).width;
      const rowHeight = stripHeight / 16;
      const half = HighlightOutline.width / 2;
      final expected = Rect.fromLTRB(
        half,
        3 * rowHeight - half,
        width - half,
        4 * rowHeight + half,
      );

      expect(
        find.byType(TissueHeatMapStrip),
        paints..something((method, arguments) {
          if (!isOutline(
            method,
            arguments,
            #drawRect,
            heatMapHighlightOf(Brightness.light),
          )) {
            return false;
          }
          final rect = arguments.first as Rect;
          return (rect.left - expected.left).abs() < 0.01 &&
              (rect.top - expected.top).abs() < 0.01 &&
              (rect.right - expected.right).abs() < 0.01 &&
              (rect.bottom - expected.bottom).abs() < 0.01;
        }),
      );
    });

    // The strip's ClipRRect would clip away a line centred outside the strip,
    // so the first row's top edge and the last row's bottom edge are pulled
    // in by half the line instead. The 2 px line still leaves most of a
    // 4.5 px row in view.
    for (final (row, label) in [(0, 'first'), (15, 'last')]) {
      testWidgets('keeps the $label row\'s outer edge inside the strip', (
        tester,
      ) async {
        await pump(tester, strip(hovered: row));

        const rowHeight = stripHeight / 16;
        const half = HighlightOutline.width / 2;
        final expectedTop = row == 0 ? half : row * rowHeight - half;
        final expectedBottom = row == 15
            ? stripHeight - half
            : (row + 1) * rowHeight + half;

        expect(
          find.byType(TissueHeatMapStrip),
          paints..something((method, arguments) {
            if (!isOutline(
              method,
              arguments,
              #drawRect,
              heatMapHighlightOf(Brightness.light),
            )) {
              return false;
            }
            final rect = arguments.first as Rect;
            return (rect.top - expectedTop).abs() < 0.01 &&
                (rect.bottom - expectedBottom).abs() < 0.01;
          }),
        );
      });
    }

    testWidgets('draws the time cursor in the highlight colour', (
      tester,
    ) async {
      await pump(tester, strip(selected: 5));

      expect(
        find.byType(TissueHeatMapStrip),
        paints..something(
          (m, a) =>
              isOutline(m, a, #drawLine, heatMapHighlightOf(Brightness.light)),
        ),
      );
    });

    testWidgets('follows a theme change', (tester) async {
      await pump(tester, strip(hovered: 3));
      await pump(tester, strip(hovered: 3), brightness: Brightness.dark);
      await tester.pumpAndSettle();

      expect(
        find.byType(TissueHeatMapStrip),
        paints..something(
          (m, a) =>
              isOutline(m, a, #drawRect, heatMapHighlightOf(Brightness.dark)),
        ),
      );
    });
  });
}
