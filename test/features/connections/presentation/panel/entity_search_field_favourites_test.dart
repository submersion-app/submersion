import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/panel/entity_search_field.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Favourite dive types rank first among connections search hits (#4413).
void main() {
  const reef = NodeRef(ConnectionKind.site, 'reef');
  const shore = NodeRef(ConnectionKind.diveType, 'shore');
  const night = NodeRef(ConnectionKind.diveType, 'night');
  // A site that happens to share a starred dive type's id.
  const nightSite = NodeRef(ConnectionKind.site, 'night');

  Future<List<String>> hitOrder(
    WidgetTester tester,
    AppSettings settings,
  ) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          connectionsSearchProvider.overrideWith(
            (ref, text) async => const [
              ConnectionNode(ref: reef, label: 'Reef', diveCount: 40),
              ConnectionNode(ref: nightSite, label: 'Night Bay', diveCount: 5),
              ConnectionNode(ref: shore, label: 'Shore', diveCount: 10),
              ConnectionNode(ref: night, label: 'Night', diveCount: 2),
            ],
          ),
          allSpeciesProvider.overrideWith((ref) async => const []),
          diveTypesProvider.overrideWith((ref) async => const []),
        ].cast(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: EntitySearchField()),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('entity-search')), 'e');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    return [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.key! as ValueKey<String>).value,
    ];
  }

  testWidgets('without favourites, hits stay busiest first', (tester) async {
    expect(await hitOrder(tester, const AppSettings()), [
      'search-hit-${reef.wire}',
      'search-hit-${shore.wire}',
      'search-hit-${nightSite.wire}',
      'search-hit-${night.wire}',
    ]);
  });

  testWidgets('a hidden favourite keeps its busiest-first place', (
    tester,
  ) async {
    expect(
      await hitOrder(
        tester,
        const AppSettings(
          favouriteDiveTypeIds: {'night'},
          hiddenBuiltInIds: {
            'diveTypes': {'night'},
          },
        ),
      ),
      [
        'search-hit-${reef.wire}',
        'search-hit-${shore.wire}',
        'search-hit-${nightSite.wire}',
        'search-hit-${night.wire}',
      ],
    );
  });

  testWidgets('a blank starred id lifts no other kind of hit', (tester) async {
    expect(
      await hitOrder(
        tester,
        const AppSettings(favouriteDiveTypeIds: {'', 'night'}),
      ),
      [
        'search-hit-${night.wire}',
        'search-hit-${reef.wire}',
        'search-hit-${shore.wire}',
        'search-hit-${nightSite.wire}',
      ],
    );
  });

  testWidgets('a starred dive type leads; a site sharing its id does not', (
    tester,
  ) async {
    expect(
      await hitOrder(
        tester,
        const AppSettings(favouriteDiveTypeIds: {'night'}),
      ),
      [
        'search-hit-${night.wire}',
        'search-hit-${reef.wire}',
        'search-hit-${shore.wire}',
        'search-hit-${nightSite.wire}',
      ],
    );
  });
}
