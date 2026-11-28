import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_bought_from_section.dart';

import 'buddy_detail_page_unlock_harness.dart';

/// A buddy's page lists the gear the diver bought from them (issue #5140).
void main() {
  testWidgets('gear bought from the buddy is listed under their name', (
    tester,
  ) async {
    await pumpBuddyPage(
      tester,
      equipment: [
        EquipmentItem(
          id: 'reg',
          name: 'Apeks XTX50',
          type: EquipmentType.regulator,
          purchaseDate: DateTime(2025, 3, 12),
          sellerBuddyId: alex.id,
        ),
      ],
    );

    expect(find.text('Bought from Alex'), findsOneWidget);
    expect(find.text('Apeks XTX50'), findsOneWidget);
  });

  testWidgets('a buddy who sold nothing shows no trace of it', (tester) async {
    await pumpBuddyPage(tester);

    expect(find.text('Bought from Alex'), findsNothing);
    expect(find.byType(GearBoughtFromSection).hitTestable(), findsNothing);
  });
}
