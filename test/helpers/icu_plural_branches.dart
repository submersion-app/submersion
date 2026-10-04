final _pluralArgument = RegExp(r'\{\s*(\w+)\s*,\s*plural\s*,');
final _selector = RegExp(r'\s*(=\d+|\w+)\s*\{');

/// Calls [visit] once per `{name, plural, ...}` argument in [message], with the
/// argument's name and its selector-to-branch-text map.
///
/// A message can hold more than one plural argument, including one nested in
/// another's branch text, so this walks every match rather than the first.
void forEachPluralArgument(
  String message,
  void Function(String argument, Map<String, String> branches) visit,
) {
  for (final match in _pluralArgument.allMatches(message)) {
    final close = _matchingBrace(message, match.start);
    visit(match.group(1)!, _branches(message, match.end, close));
  }
}

/// Splits `=1{...} other{...}` selectors out of a plural argument's body, which
/// spans [start] up to (not including) [end].
Map<String, String> _branches(String message, int start, int end) {
  final branches = <String, String>{};
  var cursor = start;
  while (cursor < end) {
    final match = _selector.matchAsPrefix(message, cursor);
    if (match == null) break;
    final open = match.end - 1;
    final close = _matchingBrace(message, open);
    branches[match.group(1)!] = message.substring(open + 1, close);
    cursor = close + 1;
  }
  return branches;
}

/// Index of the `}` that closes the `{` at [open].
int _matchingBrace(String message, int open) {
  var depth = 0;
  for (var i = open; i < message.length; i++) {
    if (message[i] == '{') {
      depth++;
    } else if (message[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  throw FormatException('unbalanced braces in: $message');
}
