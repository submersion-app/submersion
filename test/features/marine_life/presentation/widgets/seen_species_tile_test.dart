import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/widgets/seen_species_tile.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

SeenSpecies _whaleShark() => SeenSpecies(
  species: const Species(
    id: 'sp_whale_shark',
    commonName: 'Whale Shark',
    scientificName: 'Rhincodon typus',
    category: SpeciesCategory.shark,
    isBuiltIn: true,
  ),
  totalSightings: 5,
  diveCount: 3,
  siteCount: 2,
  firstSeen: DateTime(2023, 5, 1),
  lastSeen: DateTime(2024, 1, 15),
);

void main() {
  // The tile dates itself through UnitFormatter.formatDate, which resolves
  // against Intl.defaultLocale, a process global that app.dart sets from the
  // app locale, NOT the MaterialApp.locale pinned below. Pin it so the
  // "Jan 15, 2024" assertion states its real dependency instead of riding on
  // intl's implicit en_US fallback, and restore it so the global stays
  // contained.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('shows name, scientific name, counts and last seen', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides,
        child: SeenSpeciesTile(entry: _whaleShark()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Whale Shark'), findsOneWidget);
    expect(find.text('Rhincodon typus'), findsOneWidget);
    // Default date format in AppSettings is "MMM d, yyyy".
    expect(
      find.text('5 sightings · 3 dives · Last seen Jan 15, 2024'),
      findsOneWidget,
    );
  });

  testWidgets('renders the localized name for a built-in species', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('de'),
        overrides: overrides,
        child: SeenSpeciesTile(entry: _whaleShark()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Walhai'), findsOneWidget);
    expect(find.text('Whale Shark'), findsNothing);
  });

  testWidgets('keeps the typed name for a custom species', (tester) async {
    final overrides = await getBaseOverrides();
    final custom = _whaleShark().copyWith(
      species: const Species(
        id: '2b1d8c9e-0000-4000-8000-000000000001',
        commonName: 'Pygmy Seahorse',
        category: SpeciesCategory.fish,
      ),
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('de'),
        overrides: overrides,
        child: SeenSpeciesTile(entry: custom),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pygmy Seahorse'), findsOneWidget);
    expect(find.text('Rhincodon typus'), findsNothing);
  });

  testWidgets('reports taps', (tester) async {
    final overrides = await getBaseOverrides();
    var tapped = false;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides,
        child: SeenSpeciesTile(
          entry: _whaleShark(),
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    expect(tapped, isTrue);
  });
}
