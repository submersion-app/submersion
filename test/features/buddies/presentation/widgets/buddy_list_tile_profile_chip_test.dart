import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_tile.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

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

final _profilePhoto = Uint8List.fromList([1, 2, 3]);

Future<List<dynamic>> _overrides() async => [
  ...await getBaseOverrides(),
  buddyDetailedCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<BuddyField>(
      defaultConfig: _config,
      fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
    ),
  ),
  diverByIdProvider('chris').overrideWith(
    (ref) async => Diver(
      id: 'chris',
      name: 'Chris',
      photo: _profilePhoto,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ),
];

BuddyWithDiveCount _entry({String? linkedDiverId}) => BuddyWithDiveCount(
  buddy: Buddy(
    id: 'b1',
    name: 'Chris',
    linkedDiverId: linkedDiverId,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  diveCount: 3,
  lastDiveAt: DateTime(2026, 3, 5),
);

void main() {
  testWidgets('a linked buddy shows the Profile chip and borrows the photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: BuddyListTile(entry: _entry(linkedDiverId: 'chris')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.photo, _profilePhoto);
  });

  testWidgets('an unlinked buddy shows no Profile chip', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: BuddyListTile(entry: _entry()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsNothing);
    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.photo, isNull);
  });
}
