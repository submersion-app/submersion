import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/panels/key_numbers_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _full = HomeKeyNumbers(
  careerDives: 412,
  careerTimeSeconds: 386 * 3600,
  divesThisYear: 47,
  timeThisYearSeconds: 41 * 3600,
  monthlySeries: const [2, 0, 4, 9, 3, 0, 5, 2, 7, 1, 3, 11],
  daysSinceLastDive: 12,
  lastDiveId: 'd412',
  lastDiveSite: 'Salt Pier',
  avgSac: 14.2,
  avgSacChange: -0.6,
  sacSeries: const [15, 14.8, 14.5, 14.2],
  deepestThisYear: 42.1,
  deepestLastYear: 38,
  nextTrip: Trip(
    id: 't1',
    name: 'Bonaire',
    startDate: DateTime.now().add(const Duration(days: 23)),
    endDate: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  tripChecklistDone: 6,
  tripChecklistTotal: 14,
  avgDepthThisYear: 21,
  avgDepthLastYear: 19.6,
  species: 143,
  newSpeciesThisYear: 12,
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  HomeKeyNumbers? numbers,
  AppSettings settings = const AppSettings(),
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(settings),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        homeKeyNumbersProvider.overrideWith((ref) async => numbers ?? _full),
      ].cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) {
                final tier = homeWidthTierOf(context);
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: KeyNumbersPanel.heightFor(
                      context,
                      tier,
                      KeyNumbersPanel.visibleTileCount(
                        numbers ?? _full,
                        settings.hiddenHomeKeyNumbers,
                      ),
                    ),
                    child: const KeyNumbersPanel(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  test('tiles per row follow the tier', () {
    expect(KeyNumbersPanel.tilesPerRow(HomeWidthTier.desktop, 6), 6);
    expect(KeyNumbersPanel.tilesPerRow(HomeWidthTier.tablet, 6), 3);
    expect(KeyNumbersPanel.tilesPerRow(HomeWidthTier.tablet, 4), 4);
    expect(KeyNumbersPanel.tilesPerRow(HomeWidthTier.phone, 6), 2);
  });

  testWidgets('desktop shows the six default tiles', (tester) async {
    await _pump(tester, width: 1280);
    for (final title in [
      'DIVES',
      'TIME UNDER',
      'LAST DIVE',
      'AVG RMV',
      'DEEPEST THIS YEAR',
      'NEXT TRIP',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text('SPECIES'), findsNothing);
    expect(find.text('412'), findsOneWidget);
    expect(find.text('+47 this year'), findsOneWidget);
  });

  testWidgets('a tile with nothing to say is left out', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(careerDives: 0, careerTimeSeconds: 0),
    );
    expect(find.text('DIVES'), findsOneWidget);
    expect(find.text('TIME UNDER'), findsOneWidget);
    expect(find.text('LAST DIVE'), findsNothing);
    expect(find.text('AVG RMV'), findsNothing);
    expect(find.text('NEXT TRIP'), findsNothing);
  });

  testWidgets('switching tiles on shows them', (tester) async {
    await _pump(
      tester,
      width: 1280,
      settings: const AppSettings(hiddenHomeKeyNumbers: {}),
    );
    expect(find.text('SPECIES'), findsOneWidget);
    expect(find.text('AVG DEPTH'), findsOneWidget);
  });

  testWidgets('imperial units show feet', (tester) async {
    await _pump(
      tester,
      width: 1280,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
    expect(find.textContaining('ft'), findsWidgets);
  });

  testWidgets('a SAC-only diver sees bar a minute', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(
        careerDives: 1,
        careerTimeSeconds: 1,
        avgSac: 1.2,
        sacLane: GasConsumptionLane.sac,
      ),
    );
    expect(find.text('AVG SAC'), findsOneWidget);
    expect(find.textContaining('bar/min'), findsOneWidget);
  });

  testWidgets('no overflow at text scale 2 on a phone', (tester) async {
    await _pump(
      tester,
      width: 390,
      textScale: 2,
      settings: const AppSettings(hiddenHomeKeyNumbers: {}),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a SAC that went up is not drawn as a gain', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(
        careerDives: 30,
        careerTimeSeconds: 100000,
        avgSac: 15,
        avgSacChange: 0.4,
      ),
    );
    final text = tester.widget<Text>(find.textContaining('+0.4'));
    final context = tester.element(find.textContaining('+0.4'));
    expect(text.style?.color, isNot(Theme.of(context).colorScheme.primary));
  });

  testWidgets('under ten hours shows a decimal', (tester) async {
    await _pump(
      tester,
      width: 1280,
      numbers: const HomeKeyNumbers(careerDives: 1, careerTimeSeconds: 2700),
    );
    expect(find.textContaining('0.8 h'), findsOneWidget);
  });

  testWidgets('the trip checklist count comes before the trip name', (
    tester,
  ) async {
    await _pump(tester, width: 1280);
    expect(find.text('checklist 6/14 · Bonaire'), findsOneWidget);
  });
}
