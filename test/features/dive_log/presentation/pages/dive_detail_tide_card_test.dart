import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
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

/// A dive at a site on the equator and prime meridian. Its zone is Etc/GMT,
/// so the site's wall clock equals UTC and stored instants print verbatim.
Dive _equatorDive() => createTestDiveWithBottomTime().copyWith(
  site: const DiveSite(
    id: 'site-equator',
    name: 'Equator',
    location: GeoPoint(0, 0),
  ),
);

Future<void> _pumpDetailPage(
  WidgetTester tester,
  TideRecord record, {
  Dive? dive,
  DateFormatPreference dateFormat = DateFormatPreference.mmmDYYYY,
}) async {
  final shownDive = dive ?? _equatorDive();
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

  group('DiveDetailPage tide card wall-clock formatting (#222)', () {
    testWidgets('header prints the same-day cycle range verbatim', (
      tester,
    ) async {
      // Low 08:20 precedes high 14:20, so the cycle runs 08:20 -> 20:20 and
      // stays inside Sat Mar 28.
      await _pumpDetailPage(
        tester,
        _tideRecord(
          highTideTime: DateTime.utc(2026, 3, 28, 14, 20),
          lowTideTime: DateTime.utc(2026, 3, 28, 8, 20),
        ),
      );

      expect(find.text('Sat, Mar 28 | 08:20 - 20:20'), findsOneWidget);
    });

    testWidgets('header flags a cycle that crosses midnight', (tester) async {
      // Low 20:00 Mar 28 -> high 02:00 Mar 29 puts the cycle end on the next
      // day, which appends the end date to the range.
      await _pumpDetailPage(
        tester,
        _tideRecord(
          highTideTime: DateTime.utc(2026, 3, 29, 2),
          lowTideTime: DateTime.utc(2026, 3, 28, 20),
        ),
      );

      expect(find.text('Sat, Mar 28 | 20:00 - 08:00 (Mar 29)'), findsOneWidget);
    });

    testWidgets('high and low tide rows print unshifted times', (tester) async {
      await _pumpDetailPage(
        tester,
        _tideRecord(
          highTideTime: DateTime.utc(2026, 3, 28, 14, 20),
          lowTideTime: DateTime.utc(2026, 3, 28, 8, 20),
        ),
      );

      expect(find.textContaining('at 14:20'), findsOneWidget);
      expect(find.textContaining('at 08:20'), findsOneWidget);
    });
  });

  group('DiveDetailPage tide card date order (#964)', () {
    testWidgets('header follows a day-first preference', (tester) async {
      // Both dates in the header flip: the cycle date and the appended
      // next-day end date.
      await _pumpDetailPage(
        tester,
        _tideRecord(
          highTideTime: DateTime.utc(2026, 3, 29, 2),
          lowTideTime: DateTime.utc(2026, 3, 28, 20),
        ),
        dateFormat: DateFormatPreference.ddmmyyyy,
      );

      expect(find.text('Sat, 28 Mar | 20:00 - 08:00 (29 Mar)'), findsOneWidget);
    });
  });

  group('DiveDetailPage tide card site-local times', () {
    // Bonaire resolves to America/Caracas: UTC-4 with no DST.
    const bonaire = GeoPoint(12.15, -68.27);

    testWidgets('stored instants are shown in the site wall clock', (
      tester,
    ) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        site: const DiveSite(
          id: 'site-1',
          name: 'Salt Pier',
          location: bonaire,
        ),
      );
      await _pumpDetailPage(
        tester,
        _tideRecord(
          highTideTime: DateTime.utc(2026, 3, 28, 18, 20),
          lowTideTime: DateTime.utc(2026, 3, 28, 12, 20),
        ),
        dive: dive,
      );

      expect(find.text('Sat, Mar 28 | 08:20 - 20:20'), findsOneWidget);
      expect(find.textContaining('at 14:20'), findsOneWidget);
      expect(find.textContaining('at 08:20'), findsOneWidget);
    });
  });

  testWidgets('a site without coordinates shows no tide card', (tester) async {
    // With no site clock, stored instants cannot be shown as local times.
    final dive = createTestDiveWithBottomTime().copyWith(
      site: const DiveSite(id: 'site-nowhere', name: 'Unmapped'),
    );
    await _pumpDetailPage(
      tester,
      _tideRecord(
        highTideTime: DateTime.utc(2026, 3, 28, 14, 20),
        lowTideTime: DateTime.utc(2026, 3, 28, 8, 20),
      ),
      dive: dive,
    );

    expect(find.textContaining('at 14:20'), findsNothing);
    expect(find.text('Sat, Mar 28 | 08:20 - 20:20'), findsNothing);
  });
}
