import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_extremes_list.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_stat_tiles.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'tide_record_fixture.dart';

const _units = UnitFormatter(
  AppSettings(timeFormat: TimeFormat.twentyFourHour),
);

Future<void> _pump(WidgetTester tester, double width, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _extremes = [
  TideExtreme(
    type: TideExtremeType.high,
    time: DateTime.utc(2026, 3, 27, 23, 5),
    heightMeters: 2.3,
  ),
  TideExtreme(
    type: TideExtremeType.low,
    time: DateTime.utc(2026, 3, 28, 5, 5),
    heightMeters: 0.5,
  ),
  TideExtreme(
    type: TideExtremeType.high,
    time: DateTime.utc(2026, 3, 28, 11, 5),
    heightMeters: 2.4,
  ),
  TideExtreme(
    type: TideExtremeType.low,
    time: DateTime.utc(2026, 3, 28, 17, 5),
    heightMeters: 0.4,
  ),
];

/// The box of the tile showing [value]. Compared by box rather than by text,
/// because the test font (every glyph a square) wraps some labels to a
/// second line, which moves a tile's centred text but not the tile.
Rect _tile(WidgetTester tester, String value) => tester.getRect(
  find
      .ancestor(of: find.text(value), matching: find.byType(DecoratedBox))
      .first,
);

void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  group('TideStatTiles', () {
    Widget tiles() => TideStatTiles(record: risingTideRecord, units: _units);

    testWidgets('sit side by side in a wide card', (tester) async {
      await _pump(tester, 600, tiles());

      final state = _tile(tester, 'Rising');
      final height = _tile(tester, '1.60m');
      final rate = _tile(tester, '+0.40m/hr');
      expect(state.top, height.top);
      expect(height.top, rate.top);
      // Equal heights, whatever each one holds.
      expect(state.height, height.height);
      expect(height.height, rate.height);
      expect(state.right, lessThan(height.left));
      expect(height.right, lessThan(rate.left));
    });

    testWidgets('give the state its own row in a narrow card', (tester) async {
      await _pump(tester, 320, tiles());

      final state = _tile(tester, 'Rising');
      final height = _tile(tester, '1.60m');
      final rate = _tile(tester, '+0.40m/hr');
      expect(state.bottom, lessThan(height.top));
      expect(state.width, 320);
      expect(height.top, rate.top);
      expect(height.right, lessThan(rate.left));
      expect(tester.takeException(), isNull);
    });
  });

  group('TideExtremesList', () {
    Widget list() => TideExtremesList(
      extremes: _extremes,
      units: _units,
      day: DateTime.utc(2026, 3, 28, 10, 5),
    );

    testWidgets('reads down one column in a narrow card', (tester) async {
      await _pump(tester, 320, list());

      final rows = [
        'Fri 23:05 · 2.30m',
        '05:05 · 0.50m',
        '11:05 · 2.40m',
        '17:05 · 0.40m',
      ].map((text) => tester.getTopLeft(find.text(text))).toList();
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].dy, greaterThan(rows[i - 1].dy));
      }
    });

    testWidgets('splits into two columns, read down then across', (
      tester,
    ) async {
      // Wide enough that no row wraps in the square test font.
      await _pump(tester, 1000, list());

      final first = tester.getCenter(find.text('Fri 23:05 · 2.30m'));
      final second = tester.getCenter(find.text('05:05 · 0.50m'));
      final third = tester.getCenter(find.text('11:05 · 2.40m'));
      final fourth = tester.getCenter(find.text('17:05 · 0.40m'));
      // The first two fill the left column, the last two the right.
      expect(second.dy, greaterThan(first.dy));
      expect(third.dx, greaterThan(first.dx));
      expect((third.dy - first.dy).abs(), lessThan(1));
      expect((fourth.dy - second.dy).abs(), lessThan(1));
    });
  });
}
