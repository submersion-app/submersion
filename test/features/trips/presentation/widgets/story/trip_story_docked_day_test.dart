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

  testWidgets('a screen reader can activate the panel', (tester) async {
    // A label alone is not enough: the node must carry the tap action, or a
    // screen reader announces a button it cannot press. Excluding the child's
    // semantics (to keep the label clean) also drops the InkWell's action,
    // so the Semantics wrapper has to supply it.
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpPanel(tester, futureDayFixture(), onTap: () => taps++);

    final finder = find.byType(TripStoryDockedDay);
    expect(
      tester.getSemantics(finder),
      matchesSemantics(
        label: 'Go to day 3',
        isButton: true,
        hasTapAction: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('Go to day 3'));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });
}
