import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/trip_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('expanded section shows captions and the suggestion slot', (
    tester,
  ) async {
    var clearedTrip = 0;
    var clearedCenter = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripSection(
              expanded: true,
              onToggle: () {},
              summary: 'Maldives 2026 · Reef Divers',
              isEmpty: false,
              tripName: 'Maldives 2026',
              tripCaption: 'Jun 1 - Jun 14, 2026',
              onPickTrip: () {},
              onClearTrip: () => clearedTrip++,
              tripSuggestion: const Text('SUGGESTION'),
              diveCenterName: 'Reef Divers',
              centerCaption: 'Malé, Maldives',
              onPickDiveCenter: () {},
              onClearDiveCenter: () => clearedCenter++,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Maldives 2026'), findsOneWidget);
    expect(find.text('Jun 1 - Jun 14, 2026'), findsOneWidget);
    expect(find.text('SUGGESTION'), findsOneWidget);
    expect(find.text('Reef Divers'), findsOneWidget);
    expect(find.text('Malé, Maldives'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear).at(0));
    expect(clearedTrip, 1);
    await tester.tap(find.byIcon(Icons.clear).at(1));
    expect(clearedCenter, 1);
  });

  testWidgets('collapsed empty section shows the invitation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TripSection(
            expanded: false,
            onToggle: () {},
            summary: '',
            isEmpty: true,
            tripName: null,
            onPickTrip: () {},
            onClearTrip: () {},
            diveCenterName: null,
            onPickDiveCenter: () {},
            onClearDiveCenter: () {},
          ),
        ),
      ),
    );
    expect(find.text('Add trip or dive center'), findsOneWidget);
  });
}
