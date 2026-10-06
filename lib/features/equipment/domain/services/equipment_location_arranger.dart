import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';

/// One place's run of gear when the Equipment page groups by location.
/// [location] is null for the gear with no location. [groups] are the
/// shared arrangement's type groups inside this place.
@immutable
class EquipmentLocationSection {
  final EquipmentLocation? location;
  final List<EquipmentGroup> groups;

  const EquipmentLocationSection({
    required this.location,
    required this.groups,
  });

  int get itemCount => groups.fold(0, (sum, g) => sum + g.items.length);
}

/// Splits [items] by current place ([locationOf], item id to place; absent
/// means no location), then arranges each place's gear with
/// [arrangeEquipment] unchanged, so type headings and item order inside a
/// place are exactly what the shared arrangement draws everywhere else.
/// Places come by kind (storage, service shop, person, other), then by
/// name, then id; "No location" last. The input list is never mutated.
List<EquipmentLocationSection> arrangeEquipmentByLocation(
  List<EquipmentItem> items,
  EquipmentArrangement arrangement, {
  required Map<String, EquipmentLocation> locationOf,
  required String Function(EquipmentType) typeLabel,
  Comparator<EquipmentItem>? compareItems,
}) {
  if (items.isEmpty) return const [];
  final buckets = <String?, List<EquipmentItem>>{};
  final places = <String, EquipmentLocation>{};
  for (final item in items) {
    final place = locationOf[item.id];
    if (place != null) places[place.id] = place;
    buckets.putIfAbsent(place?.id, () => []).add(item);
  }
  final ordered = places.values.toList()
    ..sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      final byName = compareTextForSort(a.name, b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
  EquipmentLocationSection section(EquipmentLocation? place) =>
      EquipmentLocationSection(
        location: place,
        groups: arrangeEquipment(
          buckets[place?.id]!,
          arrangement,
          typeLabel: typeLabel,
          compareItems: compareItems,
        ),
      );
  return [
    for (final place in ordered) section(place),
    if (buckets.containsKey(null)) section(null),
  ];
}
