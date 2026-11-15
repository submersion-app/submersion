import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_picker_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_picker.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_page.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_trip_page.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The master-detail pane reuses the tabs for the next trip (#2845).
void main() {
  Trip trip(String id, {DateTime? start}) {
    final from = start ?? DateTime(2024, 1, 15);
    return Trip(
      id: id,
      name: 'Trip $id',
      startDate: from,
      // A calendar week, not 7 x 24 hours: across a daylight-saving change
      // the hours land off midnight, on the wrong day.
      endDate: DateTime(from.year, from.month, from.day + 7),
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }

  testWidgets('selecting another trip starts it on Overview', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shown = ValueNotifier(TripWithStats(trip: trip('a'), diveCount: 0));
    addTearDown(shown.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          for (final id in ['a', 'b'])
            divesForTripProvider(id).overrideWith((ref) async => <Dive>[]),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<TripWithStats>(
              valueListenable: shown,
              builder: (_, value, _) => TripDetailTabs(tripWithStats: value),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(Tab, 'Dives'));
    await tester.pumpAndSettle();
    TabController controller() =>
        DefaultTabController.of(tester.element(find.byType(TabBar)));
    expect(controller().index, TripDetailTab.dives.index);

    shown.value = TripWithStats(trip: trip('b'), diveCount: 0);
    await tester.pumpAndSettle();
    expect(controller().index, TripDetailTab.overview.index);
  });

  group('the story page chosen on the Overview', () {
    Future<ValueNotifier<TripWithStats>> pumpTabs(
      WidgetTester tester, {
      List<String>? undivedReads,
      Future<Set<String>> Function()? undivedAnswer,
      Trip? first,
    }) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final shownTrip = first ?? trip('a');
      final shown = ValueNotifier(TripWithStats(trip: shownTrip, diveCount: 0));
      addTearDown(shown.dispose);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            for (final id in {shownTrip.id, 'a', 'b'}) ...[
              tripUndivedPlanIdsProvider(id).overrideWith((ref) {
                undivedReads?.add(id);
                return undivedAnswer?.call() ?? Future.value(const <String>{});
              }),
              divesForTripProvider(id).overrideWith((ref) async => <Dive>[]),
              tripStoryProvider(id).overrideWith(
                (ref) async => buildTripStory(
                  trip: id == shownTrip.id ? shownTrip : trip(id),
                  dives: [
                    Dive(
                      id: '$id-1',
                      dateTime: DateTime(2024, 1, 17, 9),
                      maxDepth: 20,
                    ),
                  ],
                  itineraryDays: [],
                  mediaByDiveId: {},
                  sightingsByDiveId: {},
                  checklistItems: [],
                  today: DateTime(2024, 6, 1),
                ),
              ),
            ],
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<TripWithStats>(
                valueListenable: shown,
                builder: (_, value, _) => TripDetailTabs(tripWithStats: value),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return shown;
    }

    testWidgets('the chosen day survives a visit to another tab', (
      tester,
    ) async {
      await pumpTabs(tester);
      expect(find.byType(TripStoryTripPage), findsOneWidget);

      await tester.tap(find.byKey(TripDayPicker.dayTileKey(3)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Dives'));
      await tester.pumpAndSettle();
      expect(find.byType(TripStoryDayPage), findsNothing);
      await tester.tap(find.widgetWithText(Tab, 'Overview'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TripStoryDayPage>(find.byType(TripStoryDayPage))
            .day
            .dayNumber,
        3,
      );
    });

    testWidgets('which plans were dived is read once, not again on each '
        'return to the Overview', (tester) async {
      final reads = <String>[];
      await pumpTabs(tester, undivedReads: reads);
      expect(reads, ['a']);

      await tester.tap(find.widgetWithText(Tab, 'Dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Overview'));
      await tester.pumpAndSettle();

      // Read again, the picker would draw a plan late on every return.
      expect(reads, ['a']);
    });

    testWidgets('the plans read answering does not rebuild the tabs', (
      tester,
    ) async {
      final answer = Completer<Set<String>>();
      await pumpTabs(tester, undivedAnswer: () => answer.future);
      final before = tester.widget<TabBar>(find.byType(TabBar));

      answer.complete(const {'a-1'});
      await tester.pumpAndSettle();

      // Only the picker needs the answer, and it reads it itself.
      expect(tester.widget<TabBar>(find.byType(TabBar)), same(before));
    });

    testWidgets('a trip that has not started does not read its plans', (
      tester,
    ) async {
      final reads = <String>[];
      final now = DateTime.now();
      await pumpTabs(
        tester,
        undivedReads: reads,
        first: trip('c', start: DateTime(now.year, now.month, now.day + 30)),
      );

      // Its Overview is the Prepare page, which draws no day picker.
      expect(reads, isEmpty);
    });

    testWidgets('a different trip starts from its own opening page', (
      tester,
    ) async {
      final shown = await pumpTabs(tester);
      await tester.tap(find.byKey(TripDayPicker.dayTileKey(3)));
      await tester.pumpAndSettle();
      expect(find.byType(TripStoryDayPage), findsOneWidget);

      shown.value = TripWithStats(trip: trip('b'), diveCount: 0);
      await tester.pumpAndSettle();

      expect(find.byType(TripStoryTripPage), findsOneWidget);
      expect(find.byType(TripStoryDayPage), findsNothing);
    });
  });
}
