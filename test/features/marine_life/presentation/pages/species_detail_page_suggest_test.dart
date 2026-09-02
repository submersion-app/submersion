import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/helpers/species_suggestion_launcher.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_detail_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/domain/entities/species_statistics.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

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

Future<List<Uri>> _pump(WidgetTester tester, Species species) async {
  final launched = <Uri>[];
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...overrides,
        speciesProvider(species.id).overrideWith((ref) async => species),
        speciesStatisticsProvider(
          species.id,
        ).overrideWith((ref) async => SpeciesStatistics.empty),
        speciesSightingsProvider(
          species.id,
        ).overrideWith((ref) async => const []),
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
      ],
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

  testWidgets('a built-in species has no menu', (tester) async {
    await _pump(tester, _builtIn);

    expect(find.byKey(const ValueKey('species_detail_menu')), findsNothing);
  });
}
