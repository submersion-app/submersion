import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('renders with a semantics label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DayRhythmBar(
            dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Dive times during this day'), findsOneWidget);
  });

  testWidgets('paints without error at a large text scale and small height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          // A huge text scale would make the reserved label height exceed the
          // bar height; the painter must clamp instead of drawing invalid rects.
          data: const MediaQueryData(textScaler: TextScaler.linear(6)),
          child: Scaffold(
            body: DayRhythmBar(
              dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
              height: 10,
            ),
          ),
        ),
      ),
    );
    // No exception during layout/paint.
    expect(tester.takeException(), isNull);
  });
}
