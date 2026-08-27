import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _defaultConfig = EntityCardViewConfig<SiteField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
    EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.location),
    EntityCardSlotConfig(slotId: 'stat1', field: SiteField.depthRange),
    EntityCardSlotConfig(slotId: 'stat2', field: SiteField.diveCount),
  ],
  extraFields: [SiteField.lastDived, SiteField.maxDepthReached],
);

Future<List<dynamic>> _overrides({
  EntityCardViewConfig<SiteField> config = _defaultConfig,
  bool mapBackground = false,
}) async => [
  ...await getBaseOverrides(),
  siteDetailedCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<SiteField>(
      defaultConfig: config,
      fieldFromName: SiteFieldAdapter.instance.fieldFromName,
    ),
  ),
  showMapBackgroundOnSiteCardsProvider.overrideWithValue(mapBackground),
];

final _richEntry = SiteWithDiveCount(
  site: const DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    country: 'Egypt',
    region: 'South Sinai',
    city: 'Dahab',
    minDepth: 5,
    maxDepth: 50,
    difficulty: SiteDifficulty.advanced,
    waterType: WaterType.salt,
    rating: 4.5,
  ),
  diveCount: 14,
  lastDivedAt: DateTime(2024, 3, 5),
  maxDepthReached: 31.5,
  featureTypes: const ['wreck', 'mooring'],
);

const _bareEntry = SiteWithDiveCount(
  site: DiveSite(id: 'site-2', name: 'Unknown Reef'),
  diveCount: 0,
);

void main() {
  testWidgets('renders slots, rating, chips and extra fields', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: SiteListTile(entry: _richEntry, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('Dahab · South Sinai, Egypt'), findsOneWidget);
    expect(find.text('5-50m'), findsOneWidget);
    expect(find.text('14 dives'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Salt Water'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('Mooring'), findsOneWidget);
    expect(find.text('Last dived: '), findsOneWidget);
    expect(find.text('Your max: '), findsOneWidget);
    expect(find.text('32m'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('hides stats, chips and extras that have no value', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: SiteListTile(entry: _bareEntry, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Unknown Reef'), findsOneWidget);
    expect(find.textContaining('dives'), findsNothing);
    expect(find.textContaining('Last dived'), findsNothing);
    expect(find.textContaining('--'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('honours a reconfigured stat slot', (tester) async {
    const config = EntityCardViewConfig<SiteField>(
      slots: [
        EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
        EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.country),
        EntityCardSlotConfig(slotId: 'stat1', field: SiteField.maxDepthReached),
        EntityCardSlotConfig(slotId: 'stat2', field: SiteField.rating),
      ],
    );
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(config: config),
        locale: const Locale('en'),
        child: SiteListTile(entry: _richEntry, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Egypt'), findsOneWidget);
    expect(find.text('32m'), findsOneWidget);
    expect(find.text('5-50m'), findsNothing);
  });

  testWidgets('shows a checkbox in selection mode', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: SiteListTile(
          entry: _richEntry,
          isSelectionMode: true,
          isChecked: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('renders a FlutterMap background for a located site', (
    tester,
  ) async {
    const located = SiteWithDiveCount(
      site: DiveSite(
        id: 'site-3',
        name: 'Located Reef',
        location: GeoPoint(17.3155, -87.5346),
      ),
      diveCount: 0,
    );
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(mapBackground: true),
        child: SiteListTile(entry: located, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsWidgets);
    expect(find.text('Located Reef'), findsOneWidget);
  });
}
