import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';

/// The statuses the Equipment list's default view shows until the diver
/// picks others (issue #2628): everything but retired and sold gear (#636)
/// and wishlist gear (#2025).
const Set<EquipmentStatus> factoryDefaultEquipmentStatuses = {
  EquipmentStatus.active,
  EquipmentStatus.spare,
  EquipmentStatus.needsService,
  EquipmentStatus.inService,
  EquipmentStatus.loaned,
  EquipmentStatus.lost,
};

bool isFactoryDefaultEquipmentStatuses(Set<EquipmentStatus> statuses) =>
    setEquals(statuses, factoryDefaultEquipmentStatuses);

/// The stored form of [statuses]: null for the factory set (so an untouched
/// setting stores nothing and a later factory change reaches it) and for an
/// empty set, which the default view never uses; otherwise a JSON array of
/// names in enum order, so equal sets store equal text.
String? encodeEquipmentDefaultStatuses(Set<EquipmentStatus> statuses) {
  if (statuses.isEmpty || isFactoryDefaultEquipmentStatuses(statuses)) {
    return null;
  }
  return jsonEncode([
    for (final s in EquipmentStatus.values)
      if (statuses.contains(s)) s.name,
  ]);
}

/// The known statuses [raw] names, or null when it names none: null,
/// unreadable, not a list, or only names from a newer build.
Set<EquipmentStatus>? tryDecodeEquipmentDefaultStatuses(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! List) return null;
  final names = decoded.whereType<String>().toSet();
  final statuses = {
    for (final s in EquipmentStatus.values)
      if (names.contains(s.name)) s,
  };
  return statuses.isEmpty ? null : Set.unmodifiable(statuses);
}

/// [tryDecodeEquipmentDefaultStatuses], falling back to the factory set so
/// a bad value can never leave the default view empty.
Set<EquipmentStatus> decodeEquipmentDefaultStatuses(String? raw) =>
    tryDecodeEquipmentDefaultStatuses(raw) ?? factoryDefaultEquipmentStatuses;
