import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

Trip _trip() => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: DateTime(2026, 3, 7),
  endDate: DateTime(2026, 3, 10),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<void> pumpStrip(
  WidgetTester tester,
  TripWithStats stats, {
  int siteCount = 0,
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
          body: TripStatStrip(stats: stats, siteCount: siteCount),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('stat strip shows the dive count', (tester) async {
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    await pumpStrip(tester, stats);

    expect(find.text('14'), findsOneWidget);
  });

  testWidgets('stat strip totals runtime, not bottom time (issue #889)', (
    tester,
  ) async {
    final stats = TripWithStats(
      trip: _trip(),
      diveCount: 14,
      totalRuntime: 12 * 3600 + 40 * 60,
    );
    await pumpStrip(tester, stats);

    expect(find.text('Total Runtime'), findsOneWidget);
    expect(find.text('12h 40m'), findsOneWidget);
  });

  testWidgets('stat strip shows sites visited when siteCount > 0', (
    tester,
  ) async {
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    await pumpStrip(tester, stats, siteCount: 5);

    expect(find.text('Sites visited'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('stat strip hides sites visited when siteCount is 0', (
    tester,
  ) async {
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    await pumpStrip(tester, stats);

    expect(find.text('Sites visited'), findsNothing);
  });

  testWidgets('stat strip paints no band of its own', (tester) async {
    // It is the bottom row of the hero card (#4106): the card's backdrop
    // shows through, so a tint here would print a grey bar across the fade.
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    await pumpStrip(tester, stats);

    expect(
      find.descendant(
        of: find.byType(TripStatStrip),
        matching: find.byWidgetPredicate(
          (w) => w is Container && (w.color != null || w.decoration != null),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('a foreground colour reaches values and labels', (tester) async {
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TripStatStrip(stats: stats, color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<Text>(find.text('14')).style?.color, Colors.white);
    expect(
      tester.widget<Text>(find.text('Total Dives')).style?.color,
      Colors.white.withValues(alpha: 0.85),
    );
  });
}
