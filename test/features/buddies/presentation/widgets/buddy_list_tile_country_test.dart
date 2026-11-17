import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_tile.dart';
import 'package:submersion/features/buddies/presentation/widgets/compact_buddy_list_tile.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A buddy row whose subtitle slot shows the country draws its flag, as a
/// site row does (issue #4457).
void main() {
  EntityCardViewConfig<BuddyField> config(
    BuddyField subtitle,
  ) => EntityCardViewConfig<BuddyField>(
    slots: [
      const EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
      EntityCardSlotConfig(slotId: 'subtitle', field: subtitle),
      const EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
      const EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
    ],
  );

  final entry = BuddyWithDiveCount(
    buddy: Buddy(
      id: 'b1',
      name: 'Marco',
      email: 'marco@example.com',
      country: 'Italy',
      countryCode: 'IT',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    diveCount: 3,
  );

  Future<List<dynamic>> overrides(BuddyField subtitle) async => [
    ...await getBaseOverrides(),
    buddyDetailedCardConfigProvider.overrideWith(
      (ref) => EntityCardConfigNotifier<BuddyField>(
        defaultConfig: config(subtitle),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      ),
    ),
    buddyCompactCardConfigProvider.overrideWith(
      (ref) => EntityCardConfigNotifier<BuddyField>(
        defaultConfig: config(subtitle),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      ),
    ),
  ];

  testWidgets('a row showing the country draws its flag', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await overrides(BuddyField.country),
        locale: const Locale('en'),
        child: BuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Italy'), findsOneWidget);
    expect(find.byType(CountryFlag), findsOneWidget);
  });

  testWidgets('a row showing the email draws no flag', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await overrides(BuddyField.email),
        locale: const Locale('en'),
        child: BuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CountryFlag), findsNothing);
  });

  testWidgets('a compact row showing the country draws its flag', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: await overrides(BuddyField.country),
        locale: const Locale('en'),
        child: CompactBuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Italy'), findsOneWidget);
    expect(find.byType(CountryFlag), findsOneWidget);
  });
}
