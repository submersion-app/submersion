import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_content.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _config = EntityCardViewConfig<BuddyField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
    EntityCardSlotConfig(slotId: 'subtitle', field: BuddyField.email),
    EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
    EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
  ],
);

final _buddy = Buddy(
  id: 'b1',
  name: 'PELIZZARI Umberto',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<List<dynamic>> _overrides({required int diveCount}) async => [
  ...await getBaseOverrides(),
  buddyDetailedCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<BuddyField>(
      defaultConfig: _config,
      fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
    ),
  ),
  diveRoleMapProvider.overrideWith((ref) async => {}),
  // Both search providers answer, so the test pins which one the delegate is
  // actually reading rather than merely whether it renders a tile.
  buddySearchProvider.overrideWith((ref, query) async => [_buddy]),
  buddySearchWithDiveCountProvider.overrideWith(
    (ref, query) async => [
      BuddyWithDiveCount(
        buddy: _buddy,
        diveCount: diveCount,
        lastDiveAt: DateTime(2016, 11, 20),
      ),
    ],
  ),
];

/// Opens the buddy list's search page the way the list app bar does.
Future<void> _openSearch(WidgetTester tester, {required int diveCount}) async {
  await tester.pumpWidget(
    testApp(
      // Pinned: the assertions below read English labels, and the count is the
      // whole point of the test, so it must not depend on the runner's locale.
      locale: const Locale('en'),
      overrides: await _overrides(diveCount: diveCount),
      child: Consumer(
        builder: (context, ref, _) => ElevatedButton(
          onPressed: () =>
              showSearch(context: context, delegate: BuddySearchDelegate(ref)),
          child: const Text('open search'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open search'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'umb');
  // Clear the DebouncedSearchResults debounce before settling.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  // Issue #2084: the search results fabricated `BuddyWithDiveCount(diveCount:
  // 0)` because `buddySearchProvider` carries no counts, so every hit claimed
  // the buddy had no dives. French renders that zero as "1 plongée", because
  // zero falls in the CLDR `one` plural category there.
  testWidgets('search results show the buddy real dive count', (tester) async {
    await _openSearch(tester, diveCount: 2);

    expect(find.text('PELIZZARI Umberto'), findsOneWidget);
    expect(find.text('2 dives'), findsOneWidget);
    expect(find.text('0 dives'), findsNothing);
  });

  testWidgets('a buddy with no shared dives still reads as none', (
    tester,
  ) async {
    await _openSearch(tester, diveCount: 0);

    expect(find.text('0 dives'), findsOneWidget);
  });
}
