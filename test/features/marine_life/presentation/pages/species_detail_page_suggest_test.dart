import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/helpers/species_suggestion_launcher.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_detail_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/domain/entities/species_insights.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _custom = Species(
  id: 'c1',
  commonName: 'Stove-pipe Sponge',
  scientificName: 'Aplysina archeri',
  category: SpeciesCategory.invertebrate,
);

const _builtIn = Species(
  id: 'sp_whale_shark',
  commonName: 'Whale Shark',
  category: SpeciesCategory.shark,
  isBuiltIn: true,
);

Future<List<dynamic>> _overrides(Species species, List<Uri> launched) async {
  final overrides = await getBaseOverrides();
  return [
    ...overrides,
    speciesProvider(species.id).overrideWith((ref) async => species),
    speciesInsightsProvider(
      species.id,
    ).overrideWith((ref) async => SpeciesInsights.empty),
    speciesSightingsProvider(species.id).overrideWith((ref) async => const []),
    packageInfoProvider.overrideWith(
      (ref) async => PackageInfo(
        appName: 'Submersion',
        packageName: 'app.submersion',
        version: '1.7.6',
        buildNumber: '7001',
      ),
    ),
    localeProvider.overrideWithValue('en'),
    speciesSuggestionLaunchProvider.overrideWithValue((uri) async {
      launched.add(uri);
      return true;
    }),
  ];
}

Future<List<Uri>> _pump(WidgetTester tester, Species species) async {
  final launched = <Uri>[];
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: await _overrides(species, launched),
      child: SpeciesDetailPage(speciesId: species.id),
    ),
  );
  await tester.pumpAndSettle();
  return launched;
}

void main() {
  testWidgets('a custom species offers Suggest for the catalog', (
    tester,
  ) async {
    final launched = await _pump(tester, _custom);

    await tester.tap(find.byKey(const ValueKey('species_detail_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggest for the catalog'));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.host, 'github.com');
    expect(
      launched.single.queryParameters['title'],
      'Species suggestion: Stove-pipe Sponge',
    );
  });

  testWidgets('a built-in species cannot be suggested', (tester) async {
    await _pump(tester, _builtIn);

    await tester.tap(find.byKey(const ValueKey('species_detail_menu')));
    await tester.pumpAndSettle();
    expect(find.text('Suggest for the catalog'), findsNothing);
    expect(find.text('Open in Connections'), findsOneWidget);
  });

  testWidgets('Open in Connections centres the map on the species', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/species/${_builtIn.id}',
      routes: [
        GoRoute(
          path: '/species/:id',
          builder: (_, s) =>
              SpeciesDetailPage(speciesId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/insights/connections',
          builder: (context, state) =>
              Scaffold(body: Text('CONNECTIONS ${state.uri.query}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: await _overrides(_builtIn, <Uri>[]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('species_detail_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open in Connections'));
    await tester.pumpAndSettle();
    expect(
      find.text('CONNECTIONS mode=around&focus=species:sp_whale_shark'),
      findsOneWidget,
    );
  });
}
