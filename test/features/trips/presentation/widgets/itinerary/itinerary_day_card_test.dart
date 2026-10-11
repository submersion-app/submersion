import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/itinerary_day_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

final _day = ItineraryDay(
  id: 'r',
  tripId: 'trip-1',
  dayNumber: 10,
  date: DateTime(2026, 9, 30),
  dayType: DayType.diveDay,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  for (final scale in [1.0, 1.3, 1.5]) {
    testWidgets('today on a 360px phone fits at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ItineraryDayCard(
                    day: _day,
                    dives: [
                      Dive(
                        id: 'd',
                        dateTime: DateTime(2026, 9, 30, 9),
                        airTemp: 31.5,
                        cloudCover: CloudCover.partlyCloudy,
                      ),
                    ],
                    tripId: 'trip-1',
                    isLiveaboard: false,
                    kind: TripStoryDayKind.today,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('today-chip')), findsOneWidget);
    });
  }

  testWidgets('the photo count counts photos, not videos or documents', (
    tester,
  ) async {
    MediaItem item(String id, MediaType type) => MediaItem(
      id: id,
      mediaType: type,
      takenAt: DateTime(2026, 9, 30, 10),
      createdAt: DateTime(2026, 9, 30, 10),
      updatedAt: DateTime(2026, 9, 30, 10),
    );
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ItineraryDayCard(
              day: _day,
              dives: const [],
              tripId: 'trip-1',
              isLiveaboard: false,
              kind: TripStoryDayKind.past,
              media: [
                item('p', MediaType.photo),
                item('v', MediaType.video),
                item('d', MediaType.document),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1 photo'), findsOneWidget);
  });

  testWidgets('every day type renders its own badge', (tester) async {
    final overrides = await getBaseOverrides();
    for (final type in DayType.values) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ItineraryDayCard(
                day: _day.copyWith(dayType: type, portName: 'Kralendijk'),
                dives: const [],
                tripId: 'trip-1',
                isLiveaboard: true,
                kind: TripStoryDayKind.future,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: type.name);
      expect(find.byType(Icon), findsWidgets, reason: type.name);
      expect(find.text('Kralendijk'), findsOneWidget, reason: type.name);
    }
  });
}
