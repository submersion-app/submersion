/// Alphabetical ordering for user-visible names.
///
/// `String.compareTo` orders by code unit, which puts every capitalised name
/// ahead of every lowercase one ("Zebra" before "plage") and every accented
/// initial after "z". These helpers compare the case- and accent-folded text
/// instead, then fall back to the raw text so names differing only in case
/// ("Plage" / "plage") still land in a deterministic order (issue #2038).
///
/// No Flutter imports; unit-testable in isolation.
library;

import 'package:collection/collection.dart';
import 'package:submersion/core/text/fuzzy_match.dart' as fuzzy;

/// The folded form [compareTextForSort] orders by.
String textSortKey(String text) => fuzzy.normalize(text);

/// Compares [a] and [b] alphabetically, ignoring case and common accents.
///
/// Folds both strings on every call; when sorting a large list prefer a
/// [TextCollator], which folds each distinct string once.
int compareTextForSort(String a, String b) =>
    _compareFolded(a, textSortKey(a), b, textSortKey(b));

/// Same ordering as [compareTextForSort], memoizing each string's folded key.
///
/// Create one per sort call: the cache grows with the distinct strings it has
/// seen and is meant to be discarded afterwards.
class TextCollator {
  final Map<String, String> _keys = {};

  int compare(String a, String b) => _compareFolded(a, _keyOf(a), b, _keyOf(b));

  String _keyOf(String text) =>
      _keys.putIfAbsent(text, () => textSortKey(text));
}

int _compareFolded(String a, String keyA, String b, String keyB) {
  final byKey = keyA.compareTo(keyB);
  return byKey != 0 ? byKey : a.compareTo(b);
}

/// A new list of [items] in [compareTextForSort] order of [textOf].
///
/// For rows a query already ordered: SQLite's NOCASE collation folds ASCII
/// case but not accents, so "Écueil" still lands after "Zebra" until the rows
/// are re-sorted here. When [groupOf] is given, only runs of consecutive
/// items with an equal group key are re-sorted, so a leading ORDER BY term
/// (category, type, favourites first) keeps its order. The sort is stable,
/// so identical names keep the query's order.
List<T> sortedByText<T>(
  Iterable<T> items,
  String Function(T item) textOf, {
  Object? Function(T item)? groupOf,
}) {
  final collator = TextCollator();
  int compare(T a, T b) => collator.compare(textOf(a), textOf(b));

  final list = items.toList();
  if (groupOf == null) {
    mergeSort(list, compare: compare);
    return list;
  }
  var start = 0;
  while (start < list.length) {
    final group = groupOf(list[start]);
    var end = start + 1;
    while (end < list.length && groupOf(list[end]) == group) {
      end++;
    }
    mergeSort(list, start: start, end: end, compare: compare);
    start = end;
  }
  return list;
}
