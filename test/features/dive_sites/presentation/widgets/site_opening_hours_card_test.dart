import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_opening_hours_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The Opening hours card and its open-now line (issue #5073).
void main() {
  final satHours = OpeningHours(
    schedules: [
      OpeningSchedule(
        days: {
          DateTime.saturday: DayHours.ranges(const [TimeRange(600, 840)]),
        },
      ),
    ],
  );

  Future<void> pumpCard(
    WidgetTester tester,
    DiveSite site, {
    required DateTime now,
    Size size = const Size(800, 1200),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await getBaseOverrides(
          settingsNotifier: MockSettingsNotifier(
            const AppSettings(timeFormat: TimeFormat.twentyFourHour),
          ),
        ),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SiteOpeningHoursCard(site: site, now: () => now),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('open now is read in the site time zone', (tester) async {
    // Saturday 28 Nov 2026 15:00 UTC is 10:00 in Florida (UTC-5): open,
    // though the same instant in London is 15:00, after closing.
    await pumpCard(
      tester,
      DiveSite(
        id: 's',
        name: 'Ginnie Springs',
        location: const GeoPoint(29.836, -82.700),
        openingHours: satHours,
      ),
      now: DateTime.utc(2026, 11, 28, 15),
    );

    expect(find.text('Open now, closes 14:00'), findsOneWidget);
  });

  testWidgets('closed shows when it next opens', (tester) async {
    await pumpCard(
      tester,
      DiveSite(
        id: 's',
        name: 'Ginnie Springs',
        location: const GeoPoint(29.836, -82.700),
        openingHours: satHours,
      ),
      // Tuesday 24 Nov 2026, 14:00 in Florida.
      now: DateTime.utc(2026, 11, 24, 19),
    );

    expect(find.text('Closed, opens Sat 10:00'), findsOneWidget);
  });

  testWidgets('the open line uses the primary colour', (tester) async {
    await pumpCard(
      tester,
      DiveSite(
        id: 's',
        name: 'X',
        location: const GeoPoint(29.836, -82.700),
        openingHours: satHours,
      ),
      now: DateTime.utc(2026, 11, 28, 15),
    );

    final text = tester.widget<Text>(find.text('Open now, closes 14:00'));
    final context = tester.element(find.text('Open now, closes 14:00'));
    expect(text.style?.color, Theme.of(context).colorScheme.primary);
  });

  testWidgets('a lone all-year schedule has no heading; seasons do', (
    tester,
  ) async {
    await pumpCard(
      tester,
      DiveSite(id: 's', name: 'X', openingHours: satHours),
      now: DateTime(2026, 11, 28, 9),
    );
    expect(find.byKey(const ValueKey('site_hours_heading')), findsNothing);

    await pumpCard(
      tester,
      const DiveSite(
        id: 's',
        name: 'X',
        openingHours: OpeningHours(
          schedules: [
            OpeningSchedule(
              name: 'Summer',
              season: YearlyDateRange(
                start: MonthDay(4, 1),
                end: MonthDay(10, 31),
              ),
            ),
          ],
        ),
      ),
      now: DateTime(2026, 11, 28, 9),
    );
    expect(find.text('Summer, Apr 1 to Oct 31'), findsOneWidget);
    expect(
      find.text('Closed for the season, opens Apr 1'),
      findsNothing,
      reason: 'a season closed every day never opens',
    );
  });

  testWidgets("today's row is bold", (tester) async {
    await pumpCard(
      tester,
      DiveSite(id: 's', name: 'X', openingHours: satHours),
      now: DateTime(2026, 11, 28, 9),
    );

    final sat = tester.widget<Text>(find.text('Sat'));
    expect(sat.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('always open shows only 24/7 and the note', (tester) async {
    await pumpCard(
      tester,
      const DiveSite(
        id: 's',
        name: 'Pier',
        openingHours: OpeningHours(alwaysOpen: true, note: 'Lights at night'),
      ),
      now: DateTime(2026, 11, 28, 9),
    );

    expect(find.text('Open 24/7'), findsOneWidget);
    expect(find.text('Lights at night'), findsOneWidget);
    expect(find.text('Sat'), findsNothing);
  });

  testWidgets('a midnight close prints as midnight', (tester) async {
    await pumpCard(
      tester,
      DiveSite(
        id: 's',
        name: 'X',
        openingHours: OpeningHours(
          schedules: [
            OpeningSchedule(
              days: {
                DateTime.saturday: DayHours.ranges(const [
                  TimeRange(1080, 1440),
                ]),
              },
            ),
          ],
        ),
      ),
      now: DateTime(2026, 11, 28, 9),
    );

    expect(find.text('18:00–00:00'), findsOneWidget);
  });

  testWidgets('ten busy schedules fit a phone without overflow', (
    tester,
  ) async {
    final busy = DayHours.ranges(const [
      TimeRange(360, 600),
      TimeRange(660, 900),
      TimeRange(960, 1320),
    ]);
    await pumpCard(
      tester,
      DiveSite(
        id: 's',
        name: 'X',
        openingHours: OpeningHours(
          note: 'Long note ' * 30,
          schedules: [
            for (var i = 0; i < 10; i++)
              OpeningSchedule(
                name: 'Schedule with a long name number $i',
                season: YearlyDateRange(
                  start: MonthDay(i + 1, 1),
                  end: MonthDay(i + 1, 28),
                ),
                days: {for (var d = 1; d <= 7; d += 2) d: busy},
              ),
          ],
        ),
      ),
      now: DateTime(2026, 11, 28, 9),
      size: const Size(375, 800),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('an opening a week away names its date, not the weekday', (
    tester,
  ) async {
    // Saturday 28 Nov 2026, after closing: next opening is Saturday 5 Dec.
    await pumpCard(
      tester,
      DiveSite(id: 's', name: 'X', openingHours: satHours),
      now: DateTime(2026, 11, 28, 15),
    );

    expect(find.text('Closed, opens Dec 5 10:00'), findsOneWidget);
  });
}
