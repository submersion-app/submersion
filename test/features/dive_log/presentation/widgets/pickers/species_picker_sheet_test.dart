import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _ray = Species(
  id: 'sp-ray',
  commonName: 'Eagle Ray',
  scientificName: 'Aetobatus narinari',
  category: SpeciesCategory.ray,
);
const _turtle = Species(
  id: 'sp-turtle',
  commonName: 'Green Turtle',
  category: SpeciesCategory.turtle,
);

Future<void> _pump(
  WidgetTester tester, {
  List<Species> all = const [_ray, _turtle],
  List<Species> byCategory = const [_turtle],
  List<Species> searchResults = const [],
  void Function(Species, int, String)? onSpeciesSelected,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allSpeciesProvider.overrideWith((ref) async => all),
        speciesByCategoryProvider.overrideWith(
          (ref, category) async => byCategory,
        ),
        speciesSearchProvider.overrideWith((ref, query) async => searchResults),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SpeciesPickerSheet(
            scrollController: ScrollController(),
            onSpeciesSelected: onSpeciesSelected ?? (_, _, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists species with scientific names and categories', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Add Marine Life'), findsOneWidget);
    expect(find.text('Eagle Ray'), findsOneWidget);
    expect(find.text('Aetobatus narinari'), findsOneWidget);
    expect(find.text('Green Turtle'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('category chip filters via the category provider', (
    tester,
  ) async {
    await _pump(tester, byCategory: const [_turtle]);
    await tester.tap(find.widgetWithText(FilterChip, 'Turtle'));
    await tester.pumpAndSettle();
    expect(find.text('Green Turtle'), findsOneWidget);
    expect(find.text('Eagle Ray'), findsNothing);
  });

  testWidgets('search routes through the search provider', (tester) async {
    await _pump(tester, searchResults: const [_ray]);
    await tester.enterText(find.byType(TextField).first, 'eagle');
    await tester.pumpAndSettle();
    expect(find.text('Eagle Ray'), findsOneWidget);
    expect(find.text('Green Turtle'), findsNothing);

    // Clearing the search restores the full list.
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Green Turtle'), findsOneWidget);
  });

  testWidgets('selecting a species collects count and notes via the dialog', (
    tester,
  ) async {
    Species? picked;
    int? count;
    String? notes;
    await _pump(
      tester,
      onSpeciesSelected: (species, c, n) {
        picked = species;
        count = c;
        notes = n;
      },
    );
    await tester.tap(find.text('Eagle Ray'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'cruising the wall');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(picked?.id, 'sp-ray');
    expect(count, 2);
    expect(notes, 'cruising the wall');
  });

  testWidgets('empty search results offer adding a custom species', (
    tester,
  ) async {
    await _pump(tester, searchResults: const []);
    await tester.enterText(find.byType(TextField).first, 'wobbegong');
    await tester.pumpAndSettle();
    expect(find.text('No species found'), findsOneWidget);
    expect(find.textContaining('wobbegong'), findsWidgets);
  });
}
