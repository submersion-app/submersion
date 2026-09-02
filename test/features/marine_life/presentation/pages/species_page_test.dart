import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../media/presentation/support/media_widget_harness.dart';

final _whaleShark = SeenSpecies(
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

final _turtle = SeenSpecies(
  species: const Species(
    id: 'sp_green_sea_turtle',
    commonName: 'Green Sea Turtle',
    scientificName: 'Chelonia mydas',
    category: SpeciesCategory.turtle,
    isBuiltIn: true,
  ),
  totalSightings: 3,
  diveCount: 3,
  siteCount: 1,
  firstSeen: DateTime(2023, 8, 1),
  lastSeen: DateTime(2024, 6, 1),
);

GoRouter _router() => GoRouter(
  initialLocation: '/species',
  routes: [
    GoRoute(
      path: '/species',
      builder: (context, state) => const SpeciesPage(),
      routes: [
        GoRoute(
          path: 'manage',
          builder: (context, state) =>
              const Scaffold(body: Text('MANAGE PAGE')),
        ),
        GoRoute(
          path: ':speciesId',
          builder: (context, state) => Scaffold(
            body: Text('DETAIL ${state.pathParameters['speciesId']}'),
          ),
        ),
      ],
    ),
  ],
);

Future<void> _pumpPage(
  WidgetTester tester,
  List<SeenSpecies> entries, {
  Locale locale = const Locale('en'),
  Map<String, MediaItem> covers = const {},
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testAppRouter(
      router: _router(),
      locale: locale,
      overrides: [
        ...overrides,
        mediaResolverOverride(),
        seenSpeciesProvider.overrideWith((ref) async => entries),
        speciesCoverMediaProvider.overrideWith((ref) async => covers),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('lists seen species with a summary line', (tester) async {
    await _pumpPage(tester, [_whaleShark, _turtle]);

    expect(find.text('Whale Shark'), findsOneWidget);
    expect(find.text('Green Sea Turtle'), findsOneWidget);
    expect(find.text('2 species · 8 sightings'), findsOneWidget);
  });

  testWidgets('sorts by most sightings by default', (tester) async {
    await _pumpPage(tester, [_turtle, _whaleShark]);

    expect(
      _top(tester, 'Whale Shark'),
      lessThan(_top(tester, 'Green Sea Turtle')),
    );
  });

  testWidgets('typing narrows the list and clearing restores it', (
    tester,
  ) async {
    await _pumpPage(tester, [_whaleShark, _turtle]);

    await tester.enterText(find.byType(TextField), 'turtle');
    await tester.pump();
    expect(find.text('Whale Shark'), findsNothing);
    expect(find.text('Green Sea Turtle'), findsOneWidget);
    expect(find.text('1 species · 3 sightings'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(find.text('Whale Shark'), findsOneWidget);
    expect(find.text('Green Sea Turtle'), findsOneWidget);
  });

  testWidgets('a category chip narrows the list', (tester) async {
    await _pumpPage(tester, [_whaleShark, _turtle]);

    await tester.tap(find.text('Shark'));
    await tester.pump();
    expect(find.text('Whale Shark'), findsOneWidget);
    expect(find.text('Green Sea Turtle'), findsNothing);
  });

  testWidgets('the sort menu reorders the list', (tester) async {
    await _pumpPage(tester, [_whaleShark, _turtle]);
    expect(
      _top(tester, 'Whale Shark'),
      lessThan(_top(tester, 'Green Sea Turtle')),
    );

    await tester.tap(find.byKey(const ValueKey('species_sort_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();

    expect(
      _top(tester, 'Green Sea Turtle'),
      lessThan(_top(tester, 'Whale Shark')),
    );
  });

  testWidgets('shows the empty state when nothing has been logged', (
    tester,
  ) async {
    await _pumpPage(tester, const []);

    expect(find.text('No species yet'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows the no-match state for a query nothing matches', (
    tester,
  ) async {
    await _pumpPage(tester, [_whaleShark]);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No species match your search'), findsOneWidget);
  });

  testWidgets('tapping a species opens its detail page', (tester) async {
    await _pumpPage(tester, [_whaleShark]);

    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL sp_whale_shark'), findsOneWidget);
  });

  testWidgets('the manage action opens the catalog manager', (tester) async {
    await _pumpPage(tester, [_whaleShark]);

    await tester.tap(find.byKey(const ValueKey('manage_catalog')));
    await tester.pumpAndSettle();
    expect(find.text('MANAGE PAGE'), findsOneWidget);
  });

  testWidgets('search matches the localized name', (tester) async {
    await _pumpPage(tester, [_whaleShark, _turtle], locale: const Locale('de'));
    expect(find.text('Walhai'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'walh');
    await tester.pump();
    expect(find.text('Walhai'), findsOneWidget);
    expect(find.text('Green Sea Turtle'), findsNothing);
  });

  testWidgets('tiles show the cover photo only for species that have one', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      [_whaleShark, _turtle],
      covers: {'sp_whale_shark': testMediaItem(id: 'p1', diveId: 'd1')},
    );

    expect(find.byType(MediaItemView), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });
}
