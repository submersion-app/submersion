import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';
import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_cycle_graph.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'tide_record_fixture.dart';

// The high and low tide dots wore a fixed white ring to punch them out of
// the curve. On a dark chart that ring glared as a bright halo; it should
// be the colour behind the chart instead: the page, or the card it sits on.
// Presets give cards their own colour (Console dark's #1A2230 card on a
// #141A22 page), and these charts usually sit on a card.
const _cardColour = Color(0xFF1A2230);
final _theme = submersionDark.copyWith(
  cardTheme: const CardThemeData(color: _cardColour),
);

Widget _host(bool onCard, Widget child) => MaterialApp(
  theme: _theme,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 400, child: onCard ? Card(child: child) : child),
    ),
  ),
);

void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() => Intl.defaultLocale = previousDefaultLocale);

  for (final onCard in [false, true]) {
    final backdrop = onCard ? _cardColour : _theme.colorScheme.surface;
    final where = onCard ? 'on a card' : 'on the page';

    testWidgets('the tide chart extremes ring in the backdrop colour $where', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          onCard,
          SizedBox(
            height: 300,
            child: TideChart(
              predictions: [
                for (var minutes = 0; minutes <= 240; minutes += 10)
                  TidePrediction(
                    time: DateTime.utc(
                      2026,
                      3,
                      28,
                      7,
                    ).add(Duration(minutes: minutes)),
                    heightMeters: minutes / 100,
                  ),
              ],
              extremes: [
                TideExtreme(
                  type: TideExtremeType.high,
                  time: DateTime.utc(2026, 3, 28, 9, 30),
                  heightMeters: 1.5,
                ),
              ],
              now: DateTime.utc(2026, 3, 28, 9),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rings = [
        for (final bar
            in tester
                .widget<LineChart>(find.byType(LineChart).first)
                .data
                .lineBarsData)
          if (bar.dotData.show)
            for (var i = 0; i < bar.spots.length; i++)
              if (bar.dotData.getDotPainter(bar.spots[i], 0, bar, i)
                  case FlDotCirclePainter(strokeWidth: 2, :final strokeColor))
                strokeColor,
      ];
      expect(rings, isNotEmpty);
      expect(rings, everyElement(backdrop));
    });

    testWidgets('the tide cycle marker rings in the backdrop colour $where', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          onCard,
          TideCycleGraph(
            record: risingTideRecord,
            referenceTime: DateTime.utc(2026, 3, 28, 10),
            height: 80,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final graph = find.descendant(
        of: find.byType(TideCycleGraph),
        matching: find.byType(CustomPaint),
      );
      expect(
        tester.renderObject(graph.first),
        // The marker's fill, then its ring.
        paints
          ..circle(style: PaintingStyle.fill)
          ..circle(style: PaintingStyle.stroke, color: backdrop),
      );
    });
  }
}
