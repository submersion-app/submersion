import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/compact_buddy_list_tile.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _config = EntityCardViewConfig<BuddyField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
    EntityCardSlotConfig(
      slotId: 'subtitle',
      field: BuddyField.certificationLevel,
    ),
    EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
    EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
  ],
);

Future<List<dynamic>> _overrides() async => [
  ...await getBaseOverrides(),
  buddyCompactCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<BuddyField>(
      defaultConfig: _config,
      fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
    ),
  ),
];

final _entry = BuddyWithDiveCount(
  buddy: Buddy(
    id: 'b1',
    name: 'Ken Sato',
    certificationLevel: CertificationLevel.advancedOpenWater,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  diveCount: 7,
  lastDiveAt: DateTime(2024, 3, 5),
);

void main() {
  testWidgets('renders two lines from the compact config', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: CompactBuddyListTile(entry: _entry, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Ken Sato'), findsOneWidget);
    expect(find.text('Advanced Open Water'), findsOneWidget);
    expect(find.text('7 dives'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('shows a checkbox in selection mode', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: CompactBuddyListTile(
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
}
