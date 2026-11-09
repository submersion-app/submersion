import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/util/site_time_zone.dart';
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
  // UnitFormatter.formatTime formats with DateFormat, which resolves against
  // the process-global Intl.defaultLocale, not MaterialApp.locale. Pin it so
  // the AM/PM and digit assertions do not ride on whatever another test left
  // behind, and restore it so the global stays contained.
  setUp(() {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previousLocale);
  });

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

  testWidgets('outlines night blocks darker than day blocks in light mode', (
    tester,
  ) async {
    // A night dive's light fill needs a dark edge to show on the pale day
    // band, where a day dive's dark fill needs a light one on the night band.
    await tester.pumpWidget(_host([_placed(DateTime.utc(2025, 3, 1, 9))]));
    final painter = _painter(tester);
    final day = painter.dayOutlineColor as Color;
    final night = painter.nightOutlineColor as Color;
    expect(night.computeLuminance(), lessThan(day.computeLuminance()));
  });

  testWidgets(
    'speaks only the sunrise when only the sunrise lands on the day',
    (tester) async {
      // Tromso, 26 July 2026: the sun rises at about 01:18 after the midnight
      // sun, and that day's sunset falls after midnight on the 27th.
      const tromso = DiveSite(
        id: 'tromso',
        name: 'Tromso',
        location: GeoPoint(69.65, 18.96),
      );
      final entry = DateTime.utc(2026, 7, 26, 10);
      await tester.pumpWidget(
        _host([Dive(id: 't', dateTime: entry, entryTime: entry, site: tromso)]),
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Dive times during this day\. Sunrise 01:\d\d\.$'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('chooses the semantics label by which sun times are real', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      dayRhythmSemanticsLabel(l10n, sunrise: '06:12', sunset: '18:47'),
      'Dive times during this day. Sunrise 06:12, sunset 18:47.',
    );
    expect(
      dayRhythmSemanticsLabel(l10n, sunrise: '06:12'),
      'Dive times during this day. Sunrise 06:12.',
    );
    expect(
      dayRhythmSemanticsLabel(l10n, sunset: '18:47'),
      'Dive times during this day. Sunset 18:47.',
    );
    expect(dayRhythmSemanticsLabel(l10n), 'Dive times during this day');
  });

  testWidgets('uses the dark sky and outlines in dark mode', (tester) async {
    final dives = [_placed(DateTime.utc(2025, 3, 1, 9))];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: DayRhythmBar(dives: dives, units: _units24),
          ),
        ),
      ),
    );
    final painter = _painter(tester);
    final colorScheme = ThemeData(brightness: Brightness.dark).colorScheme;
    expect(painter.nightColor, colorScheme.tertiary);
    expect(painter.dayOutlineColor, Colors.black.withValues(alpha: 0.6));
    expect(painter.nightOutlineColor, painter.dayOutlineColor);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolves a site time zone once for the blocks and the sky', (
    tester,
  ) async {
    // Resolving a coordinate to its zone is the expensive step; the night
    // tint and the sky share one lookup per site.
    var lookups = 0;
    final previousOverride = SiteTimeZone.debugZoneIdOverride;
    SiteTimeZone.debugZoneIdOverride = (latitude, longitude) {
      lookups++;
      return 'America/Kralendijk';
    };
    addTearDown(() => SiteTimeZone.debugZoneIdOverride = previousOverride);

    await tester.pumpWidget(
      _host([
        _placed(DateTime.utc(2025, 3, 1, 9)),
        _placed(DateTime.utc(2025, 3, 1, 14)),
      ]),
    );
    expect(lookups, 1);
  });

  testWidgets('formats fallback hour ticks in the 12-hour setting', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        Dive(id: 'd1', dateTime: DateTime.utc(2025, 3, 1, 9)),
      ], units: _units12),
    );
    expect(find.text('6:00 AM'), findsOneWidget);
    expect(find.text('12:00 PM'), findsOneWidget);
    expect(find.text('6:00 PM'), findsOneWidget);
  });
}
