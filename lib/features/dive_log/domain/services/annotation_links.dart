import 'package:markdown/markdown.dart' as md;

import 'package:submersion/core/text/markdown/notes_markdown.dart';
import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// The link scheme that ties a passage of a dive's Notes to an annotation
/// event (#4109): `[words](annotation:<event id>)`. The id is the only
/// coupling between the two tables, so moving an annotation never touches
/// the text.
const String annotationLinkScheme = 'annotation';

final RegExp _schemePrefix = RegExp(
  '^$annotationLinkScheme:',
  caseSensitive: false,
);

/// The annotation id an [href] names, or null for any other address, a
/// missing one, or one with an empty id.
String? annotationIdFromHref(String? href) {
  if (href == null) return null;
  final match = _schemePrefix.firstMatch(href);
  if (match == null) return null;
  final id = href.substring(match.end);
  return id.isEmpty ? null : id;
}

/// The Markdown for an annotation link. Brackets in the words are escaped
/// so the link text starts and ends where the selection did, and so is a
/// last backslash, which would otherwise escape the closing bracket. What
/// the words already escape (a selection is Markdown source) stays as it is.
String annotationLinkMarkdown(String words, String id) {
  final text = words.replaceAllMapped(
    _linkTextEscapes,
    (m) => m[0]!.length == 2 ? m[0]! : '\\${m[0]}',
  );
  return '[$text]($annotationLinkScheme:$id)';
}

final RegExp _linkTextEscapes = RegExp(r'\\[\s\S]|\\$|[\[\]]');

/// Annotation id to the plain words of the first link in [notes] that names
/// it. Inline emphasis inside the link is dropped, so `[**free** flow]`
/// gives `free flow`.
Map<String, String> annotationWordsInNotes(String notes) {
  if (notes.isEmpty) return const {};
  final words = <String, String>{};
  void visit(List<md.Node> nodes) {
    for (final node in nodes) {
      if (node is! md.Element) continue;
      final id = switch (node.tag) {
        'a' => annotationIdFromHref(node.attributes['href']),
        'img' => annotationIdFromHref(node.attributes['src']),
        _ => null,
      };
      if (id != null) {
        words.putIfAbsent(
          id,
          () => node.tag == 'img'
              ? (node.attributes['alt'] ?? '')
              : node.textContent,
        );
        continue;
      }
      visit(node.children ?? const []);
    }
  }

  visit(parseNotesMarkdown(notes));
  return words;
}

/// Whether [notes] can hold an annotation link at all, for skipping a read
/// on a dive that cannot have one.
bool mayLinkAnnotations(String notes) => _schemeInText.hasMatch(notes);

final RegExp _schemeInText = RegExp(
  '$annotationLinkScheme:',
  caseSensitive: false,
);

/// The ids every annotation link in [notes] names.
Set<String> annotationIdsInNotes(String notes) =>
    annotationWordsInNotes(notes).keys.toSet();

/// A link's text as written in Notes, with its escaped pairs. The two
/// alternatives never overlap: if a backslash could be read both ways, a
/// failed match would try every combination, doubling for each backslash.
const String _linkText = r'(?:\\[\s\S]|[^\]\\])*';

/// Any annotation link as written in Notes, whatever its id, which is the
/// first group.
final annotationLinkPattern = RegExp(
  r'\['
  '$_linkText'
  r'\]\('
  '$annotationLinkScheme:'
  r'([^)\s]*)\)',
  caseSensitive: false,
);

/// An annotation address in Notes: the scheme and the id after it (ids are
/// letters, digits, `_` and `-`, so punctuation after one is not part of
/// it), or the scheme alone where a link's id was deleted whole
/// (`](annotation:)`). Prose such as "annotation: none" is not one.
final RegExp _annotationAddress = RegExp(
  '$annotationLinkScheme:[\\w-]+'
  '|(?<=\\]\\()$annotationLinkScheme:(?=\\))',
  caseSensitive: false,
);

/// The annotation addresses in [notes] that are not part of a link the
/// Notes render as one (#4815), once per time each appears, with the scheme
/// lower-cased and the id as written (ids are compared case and all): what
/// is left when a bracket, a parenthesis or part of the id is deleted by
/// hand. Save reads such an annotation as removed, though the diver only
/// meant to edit around its link. [linked] is [annotationIdsInNotes] of
/// [notes], for a caller that has already read it.
List<String> strayAnnotationAddresses(String notes, {Set<String>? linked}) => [
  for (final address in _strayAddresses(notes, linked))
    '$annotationLinkScheme:${annotationIdFromHref(address[0]) ?? ''}',
];

/// The matches of [_annotationAddress] in [notes] that no link the Notes
/// render holds. [linked] as for [strayAnnotationAddresses].
List<RegExpMatch> _strayAddresses(String notes, Set<String>? linked) {
  if (!mayLinkAnnotations(notes)) return const [];
  final ids = linked ?? annotationIdsInNotes(notes);
  final links = [
    for (final link in annotationLinkPattern.allMatches(notes))
      if (ids.contains(link[1])) link,
  ];
  return [
    for (final address in _annotationAddress.allMatches(notes))
      if (!links.any(
        (link) => link.start < address.start && address.start < link.end,
      ))
        address,
  ];
}

/// The markup of each annotation link in [notes] that no longer reads as
/// one (#4815), in order: from the bracket that opened its words, when it
/// is still there in the same paragraph, else from what is left of the
/// markup before the address, to the end of the address and a parenthesis
/// still after it. A pin from the Notes toolbar is refused inside or right
/// after one, where its link would make the broken one harder to mend.
List<({int start, int end})> brokenAnnotationLinkSpans(String notes) => [
  for (final address in _strayAddresses(notes, null))
    (
      start: _brokenMarkupStart(notes, address.start),
      end: notes.startsWith(')', address.end) ? address.end + 1 : address.end,
    ),
];

/// Where the markup before an address at [address] starts: its link's
/// opening bracket in the same paragraph, else the `](`, `]` or `(` left
/// just before it, else the address itself.
int _brokenMarkupStart(String notes, int address) {
  final before = notes.substring(0, address);
  final paragraph = _blankLine
      .allMatches(before)
      .fold(0, (_, blank) => blank.end);
  final opened = _openedLink.firstMatch(before.substring(paragraph));
  if (opened != null) return paragraph + opened.start;
  return address - _markupLeft.firstMatch(before)!.group(0)!.length;
}

final RegExp _blankLine = RegExp(r'\n[ \t\r]*\n');

/// A link's words up to the end of the text, from their opening bracket,
/// with the `]`, `](` or `(` still after them: without any of these, a `[`
/// earlier in the paragraph is not this address's link.
final RegExp _openedLink = RegExp(r'\[(?:\\[\s\S]|[^\[\]\\])*(?:\]\(?|\()$');

/// What is left of a link's markup at the end of the text.
final RegExp _markupLeft = RegExp(r'\]?\(?$');

/// What a dive's stored Notes hold of its annotation links, against which
/// an edit of them is judged (#4815): the ids they link and the addresses
/// they already leave stray.
class AnnotationLinkBaseline {
  AnnotationLinkBaseline._(
    this.notes,
    this.linked,
    this._linkCounts,
    this._strayCounts,
    this.strayIds,
  );

  factory AnnotationLinkBaseline.of(String notes) {
    final linked = annotationIdsInNotes(notes);
    final strayCounts = <String, int>{};
    final strayIds = <String>{};
    for (final address in strayAnnotationAddresses(notes, linked: linked)) {
      strayCounts[address] = (strayCounts[address] ?? 0) + 1;
      // A stored break mended links its id again, which is no edit of it.
      final id = annotationIdFromHref(address);
      if (id != null) strayIds.add(id);
    }
    return AnnotationLinkBaseline._(
      notes,
      linked,
      _linksById(notes, linked),
      strayCounts,
      strayIds,
    );
  }

  /// The stored Notes this baseline was read from.
  final String notes;

  /// The ids the stored Notes link.
  final Set<String> linked;

  /// How many links the stored Notes hold to each id they link.
  final Map<String, int> _linkCounts;

  /// The stored Notes' stray addresses, by how often each appears.
  final Map<String, int> _strayCounts;

  /// The ids the stored Notes name in stray addresses: links already
  /// broken when stored.
  final Set<String> strayIds;

  /// The ids of [holding], the annotations whose rows a save keeps only
  /// while [edited] links them, that [edited] would lose through a damaged
  /// link rather than a deleted one. Empty when nothing is lost, or only
  /// links deleted whole, address and all, which removes an annotation.
  ///
  /// A lost annotation was damaged when its address is still there out of
  /// any link, when a stray address appears that the stored Notes did not
  /// have (part of an id, or a link's markup broken), or when [edited]
  /// links some id more often than it may: as often as the stored Notes
  /// linked it, once more for each stored break of it (mended), and once
  /// more for a pin [placed] in the sitting, whose link the editor writes.
  /// More than that is an id edited, into an unknown id or another
  /// annotation's. A link that names no annotation in [holding] loses
  /// nothing. Ids are compared exactly, case and all.
  Set<String> damagedBy(
    String edited,
    Set<String> holding, {
    Set<String> placed = const {},
  }) {
    if (!mayLinkAnnotations(edited)) return const {};
    final linkedNow = annotationIdsInNotes(edited);
    final lost = holding.difference(linkedNow);
    if (lost.isEmpty) return const {};
    final addressed = {
      for (final address in _annotationAddress.allMatches(edited))
        ?annotationIdFromHref(address[0]),
    };
    final standing = lost.intersection(addressed);
    if (standing.isNotEmpty) return standing;
    if (!_withinStored(strayAnnotationAddresses(edited, linked: linkedNow))) {
      return lost;
    }
    final now = _linksById(edited, linkedNow);
    final edits = now.entries.any((link) {
      final id = link.key;
      final allowed =
          (_linkCounts[id] ?? 0) +
          (_strayCounts['$annotationLinkScheme:$id'] ?? 0) +
          (placed.contains(id) ? 1 : 0);
      return link.value > allowed;
    });
    return edits ? lost : const {};
  }

  /// How many links [notes] hold to each of [linked], the ids they link.
  static Map<String, int> _linksById(String notes, Set<String> linked) {
    final counts = <String, int>{};
    for (final link in annotationLinkPattern.allMatches(notes)) {
      final id = link[1]!;
      if (linked.contains(id)) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  /// Whether every one of [addresses] was stray in the stored Notes, each
  /// stored one standing for one use.
  bool _withinStored(List<String> addresses) {
    final used = <String, int>{};
    for (final address in addresses) {
      final n = (used[address] ?? 0) + 1;
      if (n > (_strayCounts[address] ?? 0)) return false;
      used[address] = n;
    }
    return true;
  }
}

/// [notes] with each annotation link's id replaced by its entry in [ids]. A
/// link to any other id is left as it is.
String renameAnnotationLinks(String notes, Map<String, String> ids) {
  if (ids.isEmpty) return notes;
  return notes.replaceAllMapped(annotationLinkPattern, (m) {
    final link = m[0]!;
    final id = m[1]!;
    final renamed = ids[id];
    if (renamed == null) return link;
    return '${link.substring(0, link.length - id.length - 1)}$renamed)';
  });
}

/// [notes] with every `[words](annotation:id)` turned back into `words`.
/// Other text is untouched; an absent [id] returns the input unchanged.
String unlinkAnnotation(String notes, String id) {
  final escapedId = RegExp.escape(id);
  // Case-insensitive on the scheme, like [annotationIdFromHref], so a
  // hand-edited `Annotation:` link is unlinked the way it was recognised.
  final link = RegExp(
    r'\[('
    '$_linkText'
    r')\]\('
    '$annotationLinkScheme:$escapedId'
    r'\)',
    caseSensitive: false,
  );
  if (!link.hasMatch(notes)) return notes;
  return notes.replaceAllMapped(
    link,
    (m) => m.group(1)!.replaceAll(r'\]', ']').replaceAll(r'\[', '['),
  );
}

/// Annotation id to its time as `m:ss`, for the Notes view and the PDF.
Map<String, String> annotationTimesOf(List<ProfileEvent> annotations) => {
  for (final a in annotations) a.id: formatMinutesSeconds(a.timestamp),
};

/// [events] without the annotations whose id no link in [notes] names. A
/// computer's events pass through untouched, in their original order.
List<ProfileEvent> dropOrphanAnnotations(
  List<ProfileEvent> events,
  String notes,
) {
  if (!events.any((e) => e.isAnnotation)) return events;
  final linked = annotationIdsInNotes(notes);
  return [
    for (final e in events)
      if (!e.isAnnotation || linked.contains(e.id)) e,
  ];
}

/// The latest second an annotation may fall on when the dive says [known]
/// about its length (the profile's last sample or the runtime, in seconds).
/// A dive that says nothing takes any time within a day, so a diver can
/// still pin a passage of a dive logged with no duration yet.
int annotationTimeCap(int? known) =>
    known != null && known > 0 ? known : 24 * 3600;
