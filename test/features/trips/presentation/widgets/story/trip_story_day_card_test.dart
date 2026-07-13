import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

Future<void> pumpCard(WidgetTester tester, TripStoryDay day) async {
  final overrides = await getBaseOverrides();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: TripStoryDayCard(day: day, tripId: 'trip-1'),
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('past day with dives shows rhythm and dive rows', (tester) async {
    final dive = createTestDiveWithBottomTime(
      id: 'd1',
      diveNumber: 42,
      bottomTime: const Duration(minutes: 47),
      maxDepth: 28.0,
    );
    final day = TripStoryDay(
      date: DateTime(2026, 3, 8),
      dayNumber: 2,
      kind: TripStoryDayKind.past,
      dives: [dive],
    );
    await pumpCard(tester, day);

    expect(find.textContaining('Day 2'), findsOneWidget);
    expect(find.byType(DayRhythmBar), findsOneWidget);
    expect(find.byType(DiveListItem), findsOneWidget);
  });

  testWidgets('surface day renders the slim variant', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2026, 3, 9),
      dayNumber: 3,
      kind: TripStoryDayKind.past,
    );
    await pumpCard(tester, day);
    expect(find.textContaining('Surface day'), findsOneWidget);
    expect(find.byType(DayRhythmBar), findsNothing);
  });

  testWidgets('future day shows the planned chip', (tester) async {
    final day = TripStoryDay(
      date: DateTime(2027, 1, 10),
      dayNumber: 1,
      kind: TripStoryDayKind.future,
    );
    await pumpCard(tester, day);
    expect(find.text('Planned'), findsOneWidget);
  });
}
