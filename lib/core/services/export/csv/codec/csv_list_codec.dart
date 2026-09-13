/// A list inside one CSV cell (an equipment row's attribute pairs or its
/// part names), joined with '; '.
///
/// An item is escaped only when it would otherwise be ambiguous: when it
/// contains ';' or ends in a backslash, every backslash is doubled and every
/// ';' becomes `\;`. An escaped item therefore always contains `\;` or ends
/// in a backslash, and an unescaped one never does, which is how
/// [unescapeCsvListItem] knows whether to decode. Every other item, and so
/// every list the export wrote before escaping existed, is unchanged.
library;

const _separator = '; ';

String escapeCsvListItem(String item) {
  if (!item.contains(';') && !item.endsWith(r'\')) return item;
  return item.replaceAll(r'\', r'\\').replaceAll(';', r'\;');
}

String unescapeCsvListItem(String item) {
  if (!item.contains(r'\;') && !item.endsWith(r'\')) return item;
  final out = StringBuffer();
  for (var i = 0; i < item.length; i++) {
    if (item[i] == r'\' && i + 1 < item.length) {
      out.write(item[i + 1]);
      i++;
    } else {
      out.write(item[i]);
    }
  }
  return out.toString();
}

String joinCsvList(Iterable<String> items) =>
    items.map(escapeCsvListItem).join(_separator);

/// Splits a joined cell at each '; ' that is not an escaped ';' (one
/// preceded by an odd run of backslashes). Items stay escaped; decode each
/// with [unescapeCsvListItem].
List<String> splitCsvList(String cell) {
  if (cell.trim().isEmpty) return const [];
  final items = <String>[];
  var start = 0;
  for (var i = 0; i < cell.length - 1; i++) {
    if (cell[i] != ';' || cell[i + 1] != ' ') continue;
    var backslashes = 0;
    for (var j = i - 1; j >= start && cell[j] == r'\'; j--) {
      backslashes++;
    }
    if (backslashes.isOdd) continue;
    items.add(cell.substring(start, i));
    start = i + _separator.length;
    i++;
  }
  items.add(cell.substring(start));
  return items;
}
