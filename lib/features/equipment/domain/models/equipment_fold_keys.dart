import 'dart:convert';

import 'package:submersion/core/constants/enums.dart';

// Keys naming the Equipment page's foldable groups (issue #4184).
//
// The page stores the keys of the groups the diver folded, never the open
// ones, so every group starts open and a new place or type appears open.
//
// - a place: `loc:<locationId>`, or `loc:none` for gear with no location;
// - a type inside a place: `loc:<locationId>/type:<typeName>`;
// - a type when the page does not group by location: `type:<typeName>`.
//
// Gear listed with no type heading (type grouping off) has no fold of its
// own, so it has no key.
//
// A place's fold and the folds of the types inside it are independent:
// unfolding a place brings its type groups back exactly as they were.
//
// An assembly (issue #5071) folds under `asm:<equipmentId>`, one key per
// item wherever it appears. Assemblies start folded, so the opposite rule
// holds for them: a stored `asm:` key means the diver OPENED it. While a
// filter is on every assembly starts open instead, and a key in the
// session's list means folded. [resolveCollapsedKeys] turns either into the
// keys folded now.

/// How many folded keys are kept. A key for a deleted place matches nothing
/// and is never pruned (the group may only be filtered out right now), so
/// the list is capped instead, the oldest fold dropped first.
const int kMaxStoredFoldKeys = 300;

/// The key of a place's group; null is "No location".
String locationFoldKey(String? locationId) => 'loc:${locationId ?? 'none'}';

/// The key of a type's group, nested under [parentKey] when the type sits
/// inside another group (a place on the Equipment list, an owner's shared
/// gear in a picker).
String typeFoldKey(EquipmentType type, {String? parentKey}) {
  final own = 'type:${type.name}';
  return parentKey == null ? own : '$parentKey/$own';
}

/// The key of an assembly's fold (issue #5071).
String assemblyFoldKey(String equipmentId) => 'asm:$equipmentId';

/// Whether [key] is an assembly's fold key.
bool isAssemblyFoldKey(String key) => key.startsWith('asm:');

/// The keys folded now: the stored place and type keys, plus the key of each
/// assembly in [assemblyIds] that is folded. Outside a filter an assembly is
/// folded unless its key is stored; with [assembliesStartOpen] (a filter on)
/// it is folded only when its key is stored. A stored assembly key for an
/// id not in [assemblyIds] folds nothing.
Set<String> resolveCollapsedKeys(
  Iterable<String> stored,
  Iterable<String> assemblyIds, {
  required bool assembliesStartOpen,
}) {
  final keys = stored.toSet();
  return {
    for (final key in keys)
      if (!isAssemblyFoldKey(key)) key,
    for (final id in assemblyIds)
      if (keys.contains(assemblyFoldKey(id)) == assembliesStartOpen)
        assemblyFoldKey(id),
  };
}

/// The folded keys stored in [raw], a JSON list. Anything else (null, blank,
/// malformed JSON, another shape) reads as nothing folded, and entries that
/// are not strings are skipped. Unknown keys are kept, so a key a newer
/// build wrote survives a round trip through this one.
List<String> decodeFoldKeys(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return List.unmodifiable(decoded.whereType<String>());
  } on FormatException {
    return const [];
  }
}

/// [keys] as the stored JSON list.
String encodeFoldKeys(List<String> keys) => jsonEncode(keys);

/// [keys] with [key] folded (appended) or unfolded (removed), keeping at
/// most [cap] keys by dropping the oldest. Never mutates [keys].
List<String> toggleFoldKey(
  List<String> keys,
  String key, {
  int cap = kMaxStoredFoldKeys,
}) {
  if (keys.contains(key)) {
    return List.unmodifiable(keys.where((k) => k != key));
  }
  final next = [...keys, key];
  final overflow = next.length - cap;
  return List.unmodifiable(overflow > 0 ? next.skip(overflow) : next);
}
