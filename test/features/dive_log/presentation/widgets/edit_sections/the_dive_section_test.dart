import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/stat_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets(
    'renders metric fields as flat rows (no hero) with Dive #, Entry, Exit on '
    'top and a one-tap avg-depth calculate button',
    (tester) async {
      final maxC = TextEditingController(text: '0.0');
      final avgC = TextEditingController(text: '0.0');
      final botC = TextEditingController(text: '0');
      final runC = TextEditingController(text: '0');
      final numC = TextEditingController(text: '142');
      for (final c in [maxC, avgC, botC, runC, numC]) {
        addTearDown(c.dispose);
      }
      var avgUsed = 0;

      await tester.pumpWidget(
        _wrap(
          TheDiveSection(
            depthSymbol: 'm',
            maxDepthController: maxC,
            avgDepthController: avgC,
            bottomTimeController: botC,
            runtimeController: runC,
            diveNumberController: numC,
            entryText: 'ENTRY_TS',
            onEditEntry: () {},
            exitText: 'EXIT_TS',
            onEditExit: () {},
            siteName: 'Blue Hole',
            onPickSite: () {},
            avgDepthSuggestion: ProfileSuggestion(
              value: '18.5',
              tooltip: 'Calculate from dive profile',
              onUse: () => avgUsed++,
            ),
          ),
        ),
      );

      // Hero strip is gone.
      expect(find.byType(StatStrip), findsNothing);

      // Top three rows in order: Dive #, Entry, Exit.
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(top(find.text('142')), lessThan(top(find.text('ENTRY_TS'))));
      expect(top(find.text('ENTRY_TS')), lessThan(top(find.text('EXIT_TS'))));

      // Avg depth shows the single one-tap calculate button and it fires onUse.
      expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      expect(avgUsed, 1);
    },
  );
}
