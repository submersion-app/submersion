import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_packed_item.dart';

void main() {
  const duffel = EquipmentItem(
    id: 'duffel',
    name: 'Duffel',
    type: EquipmentType.bag,
  );
  const roller = EquipmentItem(
    id: 'roller',
    name: 'Roller',
    type: EquipmentType.bag,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );

  test('copyWith replaces only what it names', () {
    const contents = TripBagContents(bag: duffel, items: [fins]);
    final moved = contents.copyWith(bag: roller);
    expect(moved.bag, roller);
    expect(moved.items, [fins]);
    final emptied = contents.copyWith(items: const []);
    expect(emptied.bag, duffel);
    expect(emptied.items, isEmpty);
  });

  test('tripPackingBags keeps only the bags', () {
    expect(tripPackingBags(const [duffel, fins, roller]), [duffel, roller]);
  });
}
