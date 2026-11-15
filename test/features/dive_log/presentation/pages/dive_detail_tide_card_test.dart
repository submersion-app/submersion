import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/domain/services/dive_tide_window.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/dive_tide_chart.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_cycle_graph.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_extremes_list.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_stat_tiles.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/mock_providers.dart';

// The dive's stored tide record carries wall-clock-as-UTC instants: the digits
// the diver saw, flagged UTC. The tide card must print them verbatim -- a
// `.toLocal()` shifts them by the MACHINE's UTC offset, so on any non-UTC host
// the pre-fix code renders shifted digits and these tests fail. (#222)
TideRecord _tideRecord({
  required DateTime highTideTime,
  required DateTime lowTideTime,
}) {
  return TideRecord(
    id: 'tide-1',
    diveId: 'test-dive-1',
    heightMeters: 1.6,
    tideState: TideState.rising,
    rateOfChange: 0.4,
    highTideHeight: 2.4,
    highTideTime: highTideTime,
    lowTideHeight: 0.4,
    lowTideTime: lowTideTime,
    createdAt: DateTime.utc(2026, 3, 28, 12),
  );
}

/// The day of tide around an entry at [entry] (a real instant): a flat
/// curve, which is all the card's layout needs, and the four extremes a
/// 12.4 hour tide puts in 24 hours.
DiveTideWindow _tideWindow(DateTime entry) {
  final start = entry.subtract(diveTideWindowHalfSpan);
  final end = entry.add(diveTideWindowHalfSpan);
  TideExtreme extreme(TideExtremeType type, Duration fromEntry, double m) =>
      TideExtreme(type: type, time: entry.add(fromEntry), heightMeters: m);
  return DiveTideWindow(
    entry: entry,
    start: start,
    end: end,
    predictions: [
      for (
        var time = start;
        !time.isAfter(end);
        time = time.add(const Duration(hours: 1))
      )
        TidePrediction(time: time, heightMeters: 1.4),
    ],
    extremes: [
      extreme(TideExtremeType.high, const Duration(hours: -11), 2.3),
      extreme(TideExtremeType.low, const Duration(hours: -5), 0.5),
      extreme(TideExtremeType.high, const Duration(hours: 1), 2.4),
      extreme(TideExtremeType.low, const Duration(hours: 7), 0.4),
    ],
  );
}

/// A dive at a Reykjavik site. Iceland keeps UTC all year with no daylight
/// saving, so the site's wall clock equals UTC and stored instants print
/// verbatim.
Dive _utcSiteDive() => createTestDiveWithBottomTime().copyWith(
  site: const DiveSite(
    id: 'site-reykjavik',
    name: 'Reykjavik',
    location: GeoPoint(64.15, -21.95),
  ),
);

Future<void> _pumpDetailPage(
  WidgetTester tester,
  TideRecord record, {
  Dive? dive,
  DateFormatPreference dateFormat = DateFormatPreference.mmmDYYYY,
  DiveTideWindow? window,
  Object? windowError,
}) async {
  final shownDive = dive ?? _utcSiteDive();
  final settings = MockSettingsNotifier();
  await settings.setTimeFormat(TimeFormat.twentyFourHour);
  await settings.setDateFormat(dateFormat);
  final overrides = await getBaseOverrides(settingsNotifier: settings);

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveProvider(shownDive.id).overrideWith((ref) async => shownDive),
        diveDataSourcesProvider(
          shownDive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
        healedTideRecordProvider((
          diveId: shownDive.id,
          location: shownDive.site?.location,
          entryTime: shownDive.effectiveEntryTime,
        )).overrideWith((ref) async => record),
        if (shownDive.site?.location != null)
          diveTideWindowProvider((
            diveId: shownDive.id,
            location: shownDive.site!.location!,
            entryTime: shownDive.effectiveEntryTime,
          )).overrideWith((ref) async {
            if (windowError != null) throw windowError;
            return window;
          }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: shownDive.id, embedded: true),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  // The day of predictions is watched once the record has resolved, so it
  // lands a frame later.
  await tester.pump();
  await tester.pump();

  FlutterError.onError = originalOnError;
}

void main() {
  // The card formats via DateFormat(pattern) with no explicit locale, so it
  // resolves against intl's process-global default. Pin it so the expected
  // digits do not depend on the locale the test host happens to run under.
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  // The test dive enters the water at 10:05 on Saturday 28 March 2026.
  final entryInstant = DateTime.utc(2026, 3, 28, 10, 5);
  TideRecord record() => _tideRecord(
    highTideTime: DateTime.utc(2026, 3, 28, 14, 20),
    lowTideTime: DateTime.utc(2026, 3, 28, 8, 20),
  );

  group('DiveDetailPage tide card wall-clock formatting (#222)', () {
    testWidgets('header names the dive date verbatim', (tester) async {
      await _pumpDetailPage(tester, record());

      expect(find.text('Sat, Mar 28'), findsOneWidget);
    });

    testWidgets('the record high and low print unshifted times', (
      tester,
    ) async {
      // With no day of predictions, the list falls back to the one high and
      // one low the stored record names, in time order.
      await _pumpDetailPage(tester, record());

      expect(find.text('08:20 · 0.40m'), findsOneWidget);
      expect(find.text('14:20 · 2.40m'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('08:20 · 0.40m')).dy,
        lessThan(tester.getTopLeft(find.text('14:20 · 2.40m')).dy),
      );
    });
  });

  group('DiveDetailPage tide card date order (#964)', () {
    testWidgets('header follows a day-first preference', (tester) async {
      await _pumpDetailPage(
        tester,
        record(),
        dateFormat: DateFormatPreference.ddmmyyyy,
      );

      expect(find.text('Sat, 28 Mar'), findsOneWidget);
    });
  });

  group('DiveDetailPage tide card shows the day around the dive (#4567)', () {
    testWidgets('charts the 24 hours around the entry', (tester) async {
      await _pumpDetailPage(
        tester,
        record(),
        window: _tideWindow(entryInstant),
      );

      expect(find.byType(DiveTideChart), findsOneWidget);
      expect(find.byType(TideCycleGraph), findsNothing);
      // The dive marker carries the entry time.
      expect(
        find.descendant(
          of: find.byType(DiveTideChart),
          matching: find.text('10:05'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lists every high and low in the day, not just one of each', (
      tester,
    ) async {
      await _pumpDetailPage(
        tester,
        record(),
        window: _tideWindow(entryInstant),
      );

      final list = find.byType(TideExtremesList);
      Finder row(String text) =>
          find.descendant(of: list, matching: find.text(text));
      // 23:05 the evening before is named by its weekday; the rest fall on
      // the dive's own date.
      expect(row('Fri 23:05 · 2.30m'), findsOneWidget);
      expect(row('05:05 · 0.50m'), findsOneWidget);
      expect(row('11:05 · 2.40m'), findsOneWidget);
      expect(row('17:05 · 0.40m'), findsOneWidget);
      expect(
        find.descendant(of: list, matching: find.text('High')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: list, matching: find.text('Low')),
        findsNWidgets(2),
      );
      // The record's own high (14:20) gives way to the predicted ones.
      expect(row('14:20 · 2.40m'), findsNothing);
    });

    testWidgets('falls back to the cycle graph when no day resolves', (
      tester,
    ) async {
      await _pumpDetailPage(tester, record());

      expect(find.byType(DiveTideChart), findsNothing);
      expect(find.byType(TideCycleGraph), findsOneWidget);
    });

    testWidgets('falls back to the cycle graph when the day fails to load', (
      tester,
    ) async {
      await _pumpDetailPage(
        tester,
        record(),
        windowError: StateError('no tide engine'),
      );

      expect(find.byType(DiveTideChart), findsNothing);
      expect(find.byType(TideCycleGraph), findsOneWidget);
      expect(find.text('14:20 · 2.40m'), findsOneWidget);
    });

    testWidgets('gives the tide at entry as three readings', (tester) async {
      await _pumpDetailPage(
        tester,
        record(),
        window: _tideWindow(entryInstant),
      );

      final tiles = find.byType(TideStatTiles);
      Finder inTiles(String text) =>
          find.descendant(of: tiles, matching: find.text(text));
      expect(inTiles('State'), findsOneWidget);
      expect(inTiles('Rising'), findsOneWidget);
      expect(inTiles('Height'), findsOneWidget);
      expect(inTiles('1.60m'), findsOneWidget);
      expect(inTiles('Rate of Change'), findsOneWidget);
      // The state keeps its icon beside its value.
      expect(
        find.descendant(of: tiles, matching: find.byIcon(Icons.trending_up)),
        findsOneWidget,
      );
    });
  });

  group('DiveDetailPage tide card site-local times', () {
    // Bonaire resolves to America/Caracas: UTC-4 with no DST.
    const bonaire = GeoPoint(12.15, -68.27);
    Dive bonaireDive() => createTestDiveWithBottomTime().copyWith(
      site: const DiveSite(id: 'site-1', name: 'Salt Pier', location: bonaire),
    );

    testWidgets('stored instants are shown in the site wall clock', (
      tester,
    ) async {
      await _pumpDetailPage(
        tester,
        _tideRecord(
          highTideTime: DateTime.utc(2026, 3, 28, 18, 20),
          lowTideTime: DateTime.utc(2026, 3, 28, 12, 20),
        ),
        dive: bonaireDive(),
      );

      expect(find.text('Sat, Mar 28'), findsOneWidget);
      expect(find.text('14:20 · 2.40m'), findsOneWidget);
      expect(find.text('08:20 · 0.40m'), findsOneWidget);
    });

    testWidgets('the day of predictions is shown in the site wall clock', (
      tester,
    ) async {
      // 10:05 on Bonaire's clock is 14:05 UTC, and the window is built in
      // real instants around that.
      await _pumpDetailPage(
        tester,
        record(),
        dive: bonaireDive(),
        window: _tideWindow(DateTime.utc(2026, 3, 28, 14, 5)),
      );

      expect(
        find.descendant(
          of: find.byType(DiveTideChart),
          matching: find.text('10:05'),
        ),
        findsOneWidget,
      );
      expect(find.text('Fri 23:05 · 2.30m'), findsOneWidget);
      expect(find.text('11:05 · 2.40m'), findsOneWidget);
    });
  });

  testWidgets('a site without coordinates shows no tide card', (tester) async {
    // With no site clock, stored instants cannot be shown as local times.
    final dive = createTestDiveWithBottomTime().copyWith(
      site: const DiveSite(id: 'site-nowhere', name: 'Unmapped'),
    );
    await _pumpDetailPage(tester, record(), dive: dive);

    expect(find.byType(TideStatTiles), findsNothing);
    expect(find.text('Sat, Mar 28'), findsNothing);
  });

  testWidgets('a dive marked freshwater shows no tide card', (tester) async {
    // The diver's own water type wins over the site's (Dive.effectiveWaterType).
    final dive = _utcSiteDive().copyWith(waterType: WaterType.fresh);
    await _pumpDetailPage(tester, record(), dive: dive);

    expect(find.byType(TideStatTiles), findsNothing);
  });

  testWidgets('rate of change uses the shared tide-rate format (#3028)', (
    tester,
  ) async {
    await _pumpDetailPage(tester, record());

    expect(find.text('+0.40m/hr'), findsOneWidget);
  });
}
