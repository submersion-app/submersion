import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _sighting = Sighting(
  id: 's1',
  diveId: 'dive-1',
  speciesId: 'sp1',
  speciesName: 'Eagle Ray',
  speciesCategory: SpeciesCategory.ray,
  count: 2,
  notes: 'pair near the wall',
);

Future<void> _pump(
  WidgetTester tester, {
  required void Function(Sighting) onSave,
  required VoidCallback onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: EditSightingSheet(
            sighting: _sighting,
            onSave: onSave,
            onDelete: onDelete,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders species name, count and notes', (tester) async {
    await _pump(tester, onSave: (_) {}, onDelete: () {});
    expect(find.text('Eagle Ray'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('pair near the wall'), findsOneWidget);
  });

  testWidgets('count buttons adjust and save returns updated sighting', (
    tester,
  ) async {
    Sighting? saved;
    await _pump(tester, onSave: (s) => saved = s, onDelete: () {});

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'single ray');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(saved?.count, 1);
    expect(saved?.notes, 'single ray');
  });

  testWidgets('delete asks for confirmation before firing onDelete', (
    tester,
  ) async {
    var deleted = 0;
    await _pump(tester, onSave: (_) {}, onDelete: () => deleted++);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('Eagle Ray'), findsWidgets);

    // Cancel keeps the sighting.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    // Confirm removes it.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });
}
