import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

typedef TripPackedItem = ({EquipmentItem item, String? bagId});

/// One packed bag and the gear it contains on this trip.
class TripBagContents {
  const TripBagContents({required this.bag, required this.items});

  final EquipmentItem bag;
  final List<EquipmentItem> items;

  Iterable<EquipmentItem> get _weighed => [bag, ...items];

  static double? _weight(EquipmentItem item) {
    final kg = item.weightKg;
    return kg != null && kg.isFinite && kg >= 0 ? kg : null;
  }

  double get knownWeightKg =>
      _weighed.fold(0.0, (sum, item) => sum + (_weight(item) ?? 0));

  List<String> get missingWeights => [
    for (final item in _weighed)
      if (_weight(item) == null) item.name,
  ];
}

List<EquipmentItem> tripPackingBags(Iterable<EquipmentItem> gear) => [
  for (final item in gear)
    if (item.type == EquipmentType.bag) item,
];
