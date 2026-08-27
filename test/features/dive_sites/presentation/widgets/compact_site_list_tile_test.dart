import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _config = EntityCardViewConfig<SiteField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
    EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.location),
    EntityCardSlotConfig(slotId: 'stat1', field: SiteField.diveCount),
    EntityCardSlotConfig(slotId: 'stat2', field: SiteField.depthRange),
  ],
);

Future<List<dynamic>> _overrides() async => [
  ...await getBaseOverrides(),
  siteCompactCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<SiteField>(
      defaultConfig: _config,
      fieldFromName: SiteFieldAdapter.instance.fieldFromName,
    ),
  ),
];

const _entry = SiteWithDiveCount(
  site: DiveSite(
    id: 'site-1',
    name: 'Blue Corner Wall',
    country: 'Micronesia',
    region: 'Palau',
    minDepth: 10,
    maxDepth: 30,
    rating: 4.0,
  ),
  diveCount: 12,
);

void main() {
  group('CompactSiteListTile', () {
    testWidgets('renders title, subtitle, both stats and the rating', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: await _overrides(),
          locale: const Locale('en'),
          child: CompactSiteListTile(entry: _entry, onTap: () {}),
        ),
      );
      await tester.pump();

      expect(find.text('Blue Corner Wall'), findsOneWidget);
      expect(find.text('Palau, Micronesia'), findsOneWidget);
      expect(find.text('12 dives'), findsOneWidget);
      expect(find.text('10-30m'), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
    });

    testWidgets('shows checkbox in selection mode', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: await _overrides(),
          child: CompactSiteListTile(
            entry: _entry,
            isSelectionMode: true,
            isSelected: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('handles a bare site gracefully', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: await _overrides(),
          locale: const Locale('en'),
          child: CompactSiteListTile(
            entry: const SiteWithDiveCount(
              site: DiveSite(id: 's', name: 'Unknown Site'),
              diveCount: 0,
            ),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Unknown Site'), findsOneWidget);
      expect(find.textContaining('dives'), findsNothing);
      expect(find.textContaining('--'), findsNothing);
    });
  });
}
