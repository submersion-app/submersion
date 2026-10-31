import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

/// One item left at a dive center, and the place that says so.
typedef GearAtCenter = ({EquipmentItem item, EquipmentLocation place});

/// The [items] whose current place in [currentPlaces] links to [centerId],
/// by item name. An archived place counts: the gear is still there.
List<GearAtCenter> gearAtDiveCenter(
  String centerId,
  List<EquipmentItem> items,
  Map<String, EquipmentLocation> currentPlaces,
) {
  final rows = <GearAtCenter>[
    for (final item in items)
      if (currentPlaces[item.id] case final place?
          when place.diveCenterId == centerId)
        (item: item, place: place),
  ];
  return sortedByText(rows, (row) => row.item.name);
}
