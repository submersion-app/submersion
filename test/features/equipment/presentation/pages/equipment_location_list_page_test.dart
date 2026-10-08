import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/test_app.dart';

void main() {
  EquipmentLocation place(
    String id,
    String name,
    EquipmentLocationKind kind, {
    bool archived = false,
  }) => EquipmentLocation(
    id: id,
    name: name,
    kind: kind,
    isArchived: archived,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final garage = place('g', 'Garage', EquipmentLocationKind.storage);
  final shop = place('s', 'Shop', EquipmentLocationKind.serviceShop);
  final attic = place(
    'a',
    'Attic',
    EquipmentLocationKind.storage,
    archived: true,
  );

  Future<void> pump(
    WidgetTester tester,
    List<EquipmentLocation> places, {
    Map<String, EquipmentLocation> current = const {},
    List<EquipmentItem> items = const [],
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          equipmentLocationsProvider.overrideWith((ref) async => places),
          currentEquipmentLocationsProvider.overrideWith(
            (ref) async => current,
          ),
          allEquipmentProvider.overrideWith((ref) async => items),
        ],
        child: const EquipmentLocationListPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no places shows the empty state', (tester) async {
    await pump(tester, const []);
    expect(
      find.text('No places yet. Add one to start tracking where your gear is.'),
      findsOneWidget,
    );
  });

  testWidgets('groups by kind with counts; retired gear not counted; '
      'archived collapsed', (tester) async {
    await pump(
      tester,
      [attic, garage, shop],
      current: {
        'reg': garage,
        'bcd': garage,
        'fins': shop,
        'old': shop,
        'wish': shop,
      },
      items: [
        for (final id in ['reg', 'bcd', 'fins'])
          EquipmentItem(id: id, name: id, type: EquipmentType.regulator),
        const EquipmentItem(
          id: 'old',
          name: 'old',
          type: EquipmentType.regulator,
          status: EquipmentStatus.retired,
        ),
        // On the wishlist: not owned, so not at the shop either.
        const EquipmentItem(
          id: 'wish',
          name: 'wish',
          type: EquipmentType.regulator,
          status: EquipmentStatus.wanted,
        ),
      ],
    );
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Service shop'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('Attic'), findsNothing);
    await tester.tap(find.text('Archived (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Attic'), findsOneWidget);
  });

  testWidgets('Add place opens the editor', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byKey(const ValueKey('equipment_locations_add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('equipment_location_name')),
      findsOneWidget,
    );
  });
}
