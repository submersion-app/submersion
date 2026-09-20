import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_docked_day.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

TripStoryDay futureDayFixture() => TripStoryDay(
  date: DateTime(2026, 3, 27),
  dayNumber: 3,
  kind: TripStoryDayKind.future,
);

Future<void> pumpPanel(
  WidgetTester tester,
  TripStoryDay day, {
  VoidCallback? onTap,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 195,
            height: 96,
            child: TripStoryDockedDay(day: day, onTap: onTap),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the day inside a half-width panel without overflowing', (
    tester,
  ) async {
    await pumpPanel(tester, futureDayFixture());

    expect(find.byType(TripStoryDayHeader), findsOneWidget);
    expect(
      tester
          .widget<TripStoryDayHeader>(find.byType(TripStoryDayHeader))
          .compact,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a planned day drops the chip in compact form', (tester) async {
    await pumpPanel(tester, futureDayFixture());

    // The chip would consume the subtitle at 195px, and the chapter's own
    // full-width heading still carries it.
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('tapping reports the day', (tester) async {
    var taps = 0;
    await pumpPanel(tester, futureDayFixture(), onTap: () => taps++);

    await tester.tap(find.byType(TripStoryDockedDay));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('the panel is a button for assistive tech', (tester) async {
    await pumpPanel(tester, futureDayFixture(), onTap: () {});

    final semantics = tester.getSemantics(find.byType(TripStoryDockedDay));
    expect(semantics.label, contains('Go to day'));
  });
}
