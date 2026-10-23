/// A site's entry or exit methods as stored in one `dive_sites` text column
/// (issue #2054): enum names in declaration order, joined by ',' with no
/// spaces. A single method is stored exactly as it was before sites could
/// hold several, so existing rows need no migration, and an empty list is
/// stored as null.
library;

import 'package:submersion/core/constants/enums.dart';

/// [methods] without duplicates, in enum declaration order, so a list has one
/// canonical form whatever order the diver ticked it in.
List<EntryMethod> canonicalEntryMethods(Iterable<EntryMethod> methods) =>
    methods.toSet().toList()..sort((a, b) => a.index.compareTo(b.index));

/// The column value for [methods]; null when there are none.
String? encodeEntryMethods(Iterable<EntryMethod> methods) {
  final canonical = canonicalEntryMethods(methods);
  return canonical.isEmpty ? null : canonical.map((m) => m.name).join(',');
}

/// The methods a stored column value names. Names this build does not know
/// (written by a newer peer) are dropped rather than failing the read.
List<EntryMethod> decodeEntryMethods(String? stored) {
  if (stored == null || stored.isEmpty) return const [];
  final byName = EntryMethod.values.asNameMap();
  return canonicalEntryMethods([
    for (final name in stored.split(',')) ?byName[name.trim()],
  ]);
}
