import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/services/day_daylight.dart';
import 'package:submersion/features/trips/domain/services/day_rhythm_layout.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _units24 = UnitFormatter(
  AppSettings(timeFormat: TimeFormat.twentyFourHour),
);
const _units12 = UnitFormatter(AppSettings(timeFormat: TimeFormat.twelveHour));

// Bonaire on 1 March 2025: sunrise near 06:49, sunset near 18:42.
const _bonaire = DiveSite(
  id: 'bonaire',
  name: 'Bonaire',
  location: GeoPoint(12.15, -68.27),
);

Dive _placed(DateTime entry) =>
    Dive(id: 'placed', dateTime: entry, entryTime: entry, site: _bonaire);

Widget _host(
  List<Dive> dives, {
  UnitFormatter units = _units24,
  double trackHeight = 16,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(textScaler: textScaler),
    child: Scaffold(
      body: SizedBox(
        width: 600,
        child: DayRhythmBar(
          dives: dives,
          units: units,
          trackHeight: trackHeight,
        ),
      ),
    ),
  ),
);

dynamic _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(DayRhythmBar),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter;

void main() {
  testWidgets('renders with a semantics label', (tester) async {
    await tester.pumpWidget(
      _host([Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))]),
    );
    expect(find.bySemanticsLabel('Dive times during this day'), findsOneWidget);
  });

  testWidgets('paints without error at a large text scale and small height', (
    tester,
  ) async {
    // A huge text scale would make the labels far wider than the bar; they
    // must be placed or dropped rather than overflowing.
    await tester.pumpWidget(
      _host(
        [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        trackHeight: 4,
        textScaler: const TextScaler.linear(6),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays the blocks out again when the dives change', (
    tester,
  ) async {
    double startFraction() =>
        (_painter(tester).blocks as List<RhythmBlock>).single.startFraction;

    await tester.pumpWidget(
      _host([Dive(id: 'd1', dateTime: DateTime.utc(2026, 3, 8, 6))]),
    );
    expect(startFraction(), closeTo(0.25, 0.001));

    // An edited dive time arrives as a new list for the same bar.
    await tester.pumpWidget(
      _host([Dive(id: 'd1', dateTime: DateTime.utc(2026, 3, 8, 18))]),
    );
    expect(startFraction(), closeTo(0.75, 0.001));
  });

  testWidgets('speaks the sun times at a placed site', (tester) async {
    await tester.pumpWidget(_host([_placed(DateTime.utc(2025, 3, 1, 9))]));
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Dive times during this day\. Sunrise 06:4\d, sunset 18:4\d\.$',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining(RegExp(r'^06:4\d$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^18:4\d$')), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
  });

  testWidgets('keeps the plain label and hour ticks for a fallback day', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([Dive(id: 'd1', dateTime: DateTime.utc(2025, 3, 1, 9))]),
    );
    expect(find.bySemanticsLabel('Dive times during this day'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('labels follow the 12-hour setting', (tester) async {
    await tester.pumpWidget(
      _host([_placed(DateTime.utc(2025, 3, 1, 9))], units: _units12),
    );
    expect(find.textContaining(RegExp(r'^6:4\d AM$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^6:4\d PM$')), findsOneWidget);
  });

  testWidgets('relabels when the time format changes', (tester) async {
    final dives = [_placed(DateTime.utc(2025, 3, 1, 9))];
    await tester.pumpWidget(_host(dives));
    expect(find.textContaining(RegExp(r'^18:4\d$')), findsOneWidget);

    await tester.pumpWidget(_host(dives, units: _units12));
    expect(find.textContaining(RegExp(r'^6:4\d PM$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^18:4\d$')), findsNothing);
  });

  testWidgets('paints a sky gradient behind the blocks', (tester) async {
    final dives = [_placed(DateTime.utc(2025, 3, 1, 9))];
    await tester.pumpWidget(_host(dives));
    expect(
      _painter(tester).stops as List<SkyStop>,
      skyStops(computeDayDaylight(dives)),
    );
  });
}
