import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_owner_chip.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_passport_header.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Which diver the active profile is; changing it reloads the provider.
final _activeDiver = StateProvider<String>((ref) => 'd1');

void main() {
  const shared = EquipmentItem(
    id: 'reg',
    name: 'Primary',
    type: EquipmentType.regulator,
    diverId: 'd2',
  );

  testWidgets('the owner chip waits while the active diver reloads', (
    tester,
  ) async {
    final reload = Completer<String?>();
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          hasMultipleDiversProvider.overrideWithValue(true),
          validatedCurrentDiverIdProvider.overrideWith((ref) async {
            final id = ref.watch(_activeDiver);
            // The first load is immediate; a switch waits on [reload].
            return id == 'd1' ? id : reload.future;
          }),
        ],
        child: const GearPassportHeader(equipment: shared),
      ),
    );
    await tester.pumpAndSettle();
    // Shared from d2 into d1's library: the owner is named.
    expect(find.byType(EquipmentOwnerChip), findsOneWidget);

    // Switching to the owner reloads the provider, which keeps d1 as its
    // stale value while loading; the chip must not be judged against it.
    ProviderScope.containerOf(
      tester.element(find.byType(GearPassportHeader)),
    ).read(_activeDiver.notifier).state = 'd2';
    await tester.pump();
    expect(find.byType(EquipmentOwnerChip), findsNothing);

    reload.complete('d2');
    await tester.pumpAndSettle();
    // Now the active diver owns it: no chip.
    expect(find.byType(EquipmentOwnerChip), findsNothing);
  });
}
