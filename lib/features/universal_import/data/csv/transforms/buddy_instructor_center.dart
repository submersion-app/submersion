/// The people in one cell of my.divessi.com's "Dive Buddy / Instructor /
/// Center" column (#3629).
typedef BuddyInstructorCenter = ({
  List<String> buddies,
  List<String> instructors,
  String? diveCenter,
});

/// A run of tabs, with any spaces around it, between two parts of the cell.
final _separator = RegExp(r' *\t[\t ]*');

/// The SSI professional on the dive: `SSI Pro: Robin K. (98962)`.
final _ssiPro = RegExp(
  r'^SSI Pro:\s*(.*?)\s*(?:\(\d+\))?$',
  caseSensitive: false,
);

final _spaces = RegExp(r'\s+');

/// Splits a my.divessi.com people cell into its buddies, its SSI pro (the
/// instructor) and its dive centre.
///
/// The site writes each part as an HTML block and the export keeps the
/// layout whitespace: parts are separated by runs of tabs, and the dive
/// centre is the part whose run of tabs ends in its indent of spaces. A
/// buddy the site ran into the next one ("Ann LeeBo Park") cannot be told
/// apart and stays as written.
BuddyInstructorCenter splitBuddyInstructorCenter(String raw) {
  final buddies = <String>[];
  final instructors = <String>[];
  String? diveCenter;

  void add(String part, {required bool indented}) {
    final text = part.trim().replaceAll(_spaces, ' ');
    if (text.isEmpty) return;
    if (indented) {
      diveCenter = text;
      return;
    }
    final pro = _ssiPro.firstMatch(text);
    if (pro != null) {
      final name = pro.group(1)!;
      if (name.isNotEmpty) instructors.add(name);
      return;
    }
    buddies.add(text);
  }

  var start = 0;
  var indented = false;
  for (final match in _separator.allMatches(raw)) {
    add(raw.substring(start, match.start), indented: indented);
    indented = match.group(0)!.endsWith('  ');
    start = match.end;
  }
  add(raw.substring(start), indented: indented);

  return (buddies: buddies, instructors: instructors, diveCenter: diveCenter);
}
