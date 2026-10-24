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

final _byName = EntryMethod.values.asNameMap();

/// The methods a stored column value names. Names this build does not know
/// (written by a newer peer) are dropped rather than failing the read.
List<EntryMethod> decodeEntryMethods(String? stored) {
  if (stored == null || stored.isEmpty) return const [];
  return canonicalEntryMethods([
    for (final name in stored.split(',')) ?_byName[name.trim()],
  ]);
}

/// [methods] named by [name] and joined by ", ", in list order.
String joinEntryMethodNames(
  Iterable<EntryMethod> methods,
  String Function(EntryMethod method) name,
) => methods.map(name).join(', ');

/// Whether a site's [exit] methods need a line of their own beside [entry]:
/// empty exits mean "same as entry", and the same methods in another order
/// are the same.
bool exitDiffersFromEntry(List<EntryMethod> entry, List<EntryMethod> exit) {
  if (exit.isEmpty) return false;
  final exits = exit.toSet();
  final entries = entry.toSet();
  return exits.length != entries.length || !exits.containsAll(entries);
}
