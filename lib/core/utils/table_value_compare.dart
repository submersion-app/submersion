/// Sort order for table columns whose cells hold values of any kind.
///
/// No Flutter imports; unit-testable in isolation.
library;

import 'package:submersion/core/text/text_sort.dart';

/// Compares two non-null cell values for a table column sort.
///
/// A column's values need not share a type: Visibility extracts a measured
/// distance for newer dives and the legacy bucket label for older ones. Both
/// are `Comparable`, yet `double.compareTo(String)` throws, and a throw inside
/// a table's build greys out the whole table (issue #2444). So values are
/// compared natively only when they are of the same kind:
///
/// - text alphabetically, through [collator];
/// - numbers numerically, int and double alike;
/// - other `Comparable`s of one runtime type by their own `compareTo`.
///
/// Values of different kinds order numbers first, then other values, then
/// text, so measured readings stay together ahead of labels. Anything else
/// (lists, booleans, `Comparable`s of different types) compares by its
/// [formatted] display text.
int compareTableValues(
  Object a,
  Object b, {
  required TextCollator collator,
  required String Function(Object value) formatted,
}) {
  if (a is String && b is String) return collator.compare(a, b);
  if (a is num && b is num) return a.compareTo(b);
  if (a is Comparable && a.runtimeType == b.runtimeType) {
    return a.compareTo(b);
  }
  final byKind = _kindRank(a).compareTo(_kindRank(b));
  if (byKind != 0) return byKind;
  return collator.compare(formatted(a), formatted(b));
}

/// Numbers first, then anything else, then text.
int _kindRank(Object value) => switch (value) {
  num() => 0,
  String() => 2,
  _ => 1,
};
