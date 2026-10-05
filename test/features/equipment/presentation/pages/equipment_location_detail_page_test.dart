import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  final shop = EquipmentLocation(
    id: 's',
    name: "Joe's Scuba",
    kind: EquipmentLocationKind.serviceShop,
    notes: '12 Harbour Rd',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final garage = EquipmentLocation(
    id: 'g',
    name: 'Garage',
    kind: EquipmentLocationKind.storage,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, {required bool inUse}) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentLocationsProvider.overrideWith(
            (ref) async => [shop, garage],
          ),
          allEquipmentLocationsByIdProvider.overrideWith(
            (ref) async => {'s': shop, 'g': garage},
          ),
          currentEquipmentLocationsProvider.overrideWith(
            (ref) async => {'reg': shop, 'bcd': garage, 'old': shop},
          ),
          allEquipmentProvider.overrideWith(
            (ref) async => const [
              EquipmentItem(
                id: 'reg',
                name: 'Primary reg',
                type: EquipmentType.regulator,
              ),
              EquipmentItem(id: 'bcd', name: 'Wing', type: EquipmentType.bcd),
              EquipmentItem(
                id: 'old',
                name: 'Old reg',
                type: EquipmentType.regulator,
                status: EquipmentStatus.sold,
              ),
            ],
          ),
          equipmentLocationInUseProvider(
            's',
          ).overrideWith((ref) async => inUse),
        ],
        child: const EquipmentLocationDetailPage(locationId: 's'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the gear there now, not sold gear or other places', (
    tester,
  ) async {
    await pump(tester, inUse: true);
    expect(find.text("Joe's Scuba"), findsOneWidget);
    expect(find.text('12 Harbour Rd'), findsOneWidget);
    expect(find.text('Primary reg'), findsOneWidget);
    expect(find.text('Wing'), findsNothing);
    expect(find.text('Old reg'), findsNothing);
  });

  testWidgets('the gear here can be moved from the place page', (tester) async {
    await pump(tester, inUse: true);
    await tester.tap(
      find.byKey(const ValueKey('equipment_location_move_items')),
    );
    await tester.pumpAndSettle();
    // The move sheet opens for the one item here (sold gear left out).
    expect(find.text('Move 1 item'), findsOneWidget);
  });

  testWidgets('a place in use offers Archive but not Delete', (tester) async {
    await pump(tester, inUse: true);
    await tester.tap(find.byKey(const ValueKey('equipment_location_menu')));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('an unused place offers Delete', (tester) async {
    await pump(tester, inUse: false);
    await tester.tap(find.byKey(const ValueKey('equipment_location_menu')));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('deleting a place asks first; Cancel keeps it', (tester) async {
    await pump(tester, inUse: false);
    await tester.tap(find.byKey(const ValueKey('equipment_location_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text("Delete Joe's Scuba?"), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('12 Harbour Rd'), findsOneWidget);
  });
}
