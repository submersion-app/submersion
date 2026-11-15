import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_subtitle.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The words that say what kind of day it was and where: the day type (or
/// "Surface day"), the port, then the sites dived.
void main() {
  final date = DateTime(2026, 3, 8);

  ItineraryDay itinerary({DayType type = DayType.diveDay, String? port}) =>
      ItineraryDay(
        id: 'itin-1',
        tripId: 'trip-1',
        dayNumber: 2,
        date: date,
        dayType: type,
        portName: port,
        notes: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Dive diveAt(String site) => Dive(
    id: 'dive-$site',
    dateTime: date.add(const Duration(hours: 9)),
    site: DiveSite(id: 'site-$site', name: site),
  );

  Future<List<String>> partsFor(WidgetTester tester, TripStoryDay day) async {
    late List<String> parts;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            parts = tripDaySubtitleParts(context, day);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return parts;
  }

  testWidgets('a day type, its port and its sites, in that order', (
    tester,
  ) async {
    final parts = await partsFor(
      tester,
      TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        itineraryDay: itinerary(port: 'Port Ghalib'),
        dives: [diveAt('Reef')],
      ),
    );

    expect(parts, ['Dive Day', 'Port Ghalib', 'Reef']);
  });

  testWidgets('a blank port leaves no doubled separator', (tester) async {
    final parts = await partsFor(
      tester,
      TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        itineraryDay: itinerary(port: '  '),
        dives: [diveAt('Reef')],
      ),
    );

    expect(parts, ['Dive Day', 'Reef']);
  });

  testWidgets('a surface day leads with Surface day', (tester) async {
    final parts = await partsFor(
      tester,
      TripStoryDay(date: date, dayNumber: 2, kind: TripStoryDayKind.past),
    );

    expect(parts, ['Surface day']);
  });

  testWidgets('a rest day with a dive logged reads as a dive day', (
    tester,
  ) async {
    final parts = await partsFor(
      tester,
      TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        itineraryDay: itinerary(type: DayType.rest),
        dives: [diveAt('Reef')],
      ),
    );

    expect(parts.first, 'Dive Day');
  });
}
