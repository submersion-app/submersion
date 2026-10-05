import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';

import '../../../../helpers/test_app.dart';

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

void main() {
  Future<void> pumpOpener(
    WidgetTester tester,
    List<EquipmentLocation> places,
    void Function(LocationPick?) onPicked,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          equipmentLocationsProvider.overrideWith((ref) async => places),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async =>
                onPicked(await showEquipmentLocationPickerSheet(context, ref)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists active places under their kind, hides archived ones, '
      'and filters by search', (tester) async {
    LocationPick? picked;
    await pumpOpener(tester, [
      place('g', 'Garage bin 2', EquipmentLocationKind.storage),
      place('j', "Joe's Scuba", EquipmentLocationKind.serviceShop),
      place('x', 'Old locker', EquipmentLocationKind.storage, archived: true),
    ], (p) => picked = p);

    expect(find.text('Garage bin 2'), findsOneWidget);
    expect(find.text("Joe's Scuba"), findsOneWidget);
    expect(find.text('Old locker'), findsNothing);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Service shop'), findsOneWidget);
    expect(find.text('No location'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'joe');
    await tester.pumpAndSettle();
    expect(find.text('Garage bin 2'), findsNothing);

    await tester.tap(find.text("Joe's Scuba"));
    await tester.pumpAndSettle();
    expect((picked! as PlacePick).location.id, 'j');
  });

  testWidgets('No location returns NoLocationPick', (tester) async {
    LocationPick? picked;
    await pumpOpener(tester, const [], (p) => picked = p);
    await tester.tap(find.text('No location'));
    await tester.pumpAndSettle();
    expect(picked, isA<NoLocationPick>());
  });

  testWidgets('dismissing returns null', (tester) async {
    LocationPick? picked = const NoLocationPick();
    await pumpOpener(tester, const [], (p) => picked = p);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });

  testWidgets('New place opens the editor prefilled from the search', (
    tester,
  ) async {
    await pumpOpener(tester, const [], (_) {});
    await tester.enterText(find.byType(TextField), 'Boat locker');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('equipment_location_picker_new')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New place'), findsWidgets);
    final name = tester.widget<TextFormField>(
      find.byKey(const ValueKey('equipment_location_name')),
    );
    expect(name.controller?.text, 'Boat locker');
  });
}
