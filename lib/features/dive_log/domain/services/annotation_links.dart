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
/// so the link text starts and ends where the selection did.
String annotationLinkMarkdown(String words, String id) =>
    '[${words.replaceAll('[', r'\[').replaceAll(']', r'\]')}]'
    '($annotationLinkScheme:$id)';

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

/// The ids every annotation link in [notes] names.
Set<String> annotationIdsInNotes(String notes) =>
    annotationWordsInNotes(notes).keys.toSet();

/// Any annotation link as written in Notes, whatever its id.
final annotationLinkPattern = RegExp(
  r'\[(?:\\.|[^\]])*\]\('
  '$annotationLinkScheme:'
  r'[^)\s]*\)',
  caseSensitive: false,
);

/// [notes] with every `[words](annotation:id)` turned back into `words`.
/// Other text is untouched; an absent [id] returns the input unchanged.
String unlinkAnnotation(String notes, String id) {
  final escapedId = RegExp.escape(id);
  // Case-insensitive on the scheme, like [annotationIdFromHref], so a
  // hand-edited `Annotation:` link is unlinked the way it was recognised.
  final link = RegExp(
    r'\[((?:\\.|[^\]])*)\]\('
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
