import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_day_notes_vocabulary.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Where the trip editor opens a day's note (#4625): the Notes text to load,
/// where the caret goes, and the heading it appended, if it did.
class DayNotePlacement {
  const DayNotePlacement({
    required this.original,
    required this.text,
    required this.cursor,
    this.insertedHeading,
    this.insertedFence,
  });

  /// The Notes as they were loaded, before anything was added for the day.
  final String original;

  final String text;
  final int cursor;

  /// The heading line Add note appended, or null when the Notes already had
  /// one for the day.
  final String? insertedHeading;

  /// The fence Add note closed an open code block with, above
  /// [insertedHeading], or null when it closed none.
  final String? insertedFence;

  /// [notes], the Notes field's text, as it should be saved. Notes left as
  /// they opened are saved as they were loaded, so a line or a code fence
  /// added for the caret never lands on its own; otherwise an added heading
  /// that still has nothing under it is left out, with the fence added
  /// above it.
  String toSave(String notes) {
    if (notes == text) return original;
    final inserted = insertedHeading;
    if (inserted == null) return notes;
    final saved = dropUntouchedDayHeading(notes, inserted);
    // The fence was there only to keep the heading out of the code block.
    final fence = insertedFence;
    if (saved == notes || fence == null || !saved.endsWith('\n$fence')) {
      return saved;
    }
    return saved.substring(0, saved.length - fence.length - 1);
  }
}

/// Opens [day]'s note in [notes]: at the end of its last passage, under its
/// last heading when that has nothing yet, or at a new [headingLabel] heading
/// appended after a blank line, at the level the note's day headings use
/// (`##` when it has none).
DayNotePlacement placeDayNote(
  String notes,
  TripNoteDay day,
  TripDayNotesVocabulary vocabulary, {
  required String headingLabel,
}) {
  final scanned = tripDayNotes(notes, [day], vocabulary);
  final passageEnd = scanned.passageEnds[day.date];
  if (passageEnd != null) {
    return DayNotePlacement(original: notes, text: notes, cursor: passageEnd);
  }
  final headingEnd = scanned.headingLineEnds[day.date];
  if (headingEnd != null) {
    // A heading on the last line gets a line of its own under it.
    if (headingEnd == notes.length) {
      final text = notes.endsWith('\n') ? notes : '$notes\n';
      return DayNotePlacement(original: notes, text: text, cursor: text.length);
    }
    // A heading right above another line (the next heading, with no blank
    // line between) gets an empty line of its own, so what is typed under
    // it never runs into that line.
    final nextLineEnd = notes.indexOf('\n', headingEnd);
    final nextLine = notes.substring(
      headingEnd,
      nextLineEnd < 0 ? notes.length : nextLineEnd,
    );
    if (nextLine.trim().isNotEmpty) {
      return DayNotePlacement(
        original: notes,
        text:
            '${notes.substring(0, headingEnd)}\n${notes.substring(headingEnd)}',
        cursor: headingEnd,
      );
    }
    return DayNotePlacement(original: notes, text: notes, cursor: headingEnd);
  }
  final level = scanned.dayHeadingLevel ?? 2;
  final heading = '${'#' * level} $headingLabel';
  // A code block left open would swallow the heading; close it first.
  final fence = scanned.unclosedFence;
  final before = fence == null
      ? notes.trimRight()
      : '${notes.trimRight()}\n$fence';
  final text = before.isEmpty ? '$heading\n' : '$before\n\n$heading\n';
  return DayNotePlacement(
    original: notes,
    text: text,
    cursor: text.length,
    insertedHeading: heading,
    insertedFence: fence,
  );
}

/// [placeDayNote] in the app's language: its day words, and its day label
/// for a heading it adds.
DayNotePlacement placeDayNoteIn(
  String notes,
  TripNoteDay day,
  AppLocalizations l10n,
) => placeDayNote(
  notes,
  day,
  tripDayNotesVocabularyFor(l10n),
  headingLabel: l10n.trips_story_dayLabel(day.dayNumber),
);

/// [notes] without [insertedHeading] when nothing was written under it:
/// the last line equal to it, the blank lines up to the next heading at its
/// level or higher, and the blank lines just before it. Anything else is
/// left as it is, so a heading the diver wrote, or one with words under it,
/// stays.
String dropUntouchedDayHeading(String notes, String insertedHeading) {
  final lines = notes.split('\n');
  final at = lines.lastIndexWhere(
    (line) => line.trimRight() == insertedHeading,
  );
  if (at < 0) return notes;
  final level = atxHeadingLevel(insertedHeading) ?? 6;

  var after = at + 1;
  while (after < lines.length) {
    final line = lines[after];
    final heading = atxHeadingLevel(line);
    if (heading != null && heading <= level) break;
    if (line.trim().isNotEmpty) return notes;
    after++;
  }

  var before = at;
  while (before > 0 && lines[before - 1].trim().isEmpty) {
    before--;
  }
  final head = lines.sublist(0, before);
  final tail = lines.sublist(after);
  if (head.isEmpty) return tail.join('\n');
  if (tail.isEmpty) return head.join('\n');
  return '${head.join('\n')}\n\n${tail.join('\n')}';
}

/// A day's passage as [DayNotePlacement] opens it, cut out of the Notes so
/// an editor can hold that passage alone (issue #4527): the text before it
/// (down to its heading, and any blank lines under that), the passage, and
/// the text after it.
typedef DayPassage = ({String before, String passage, String after});

/// [placement]'s text cut around [day]'s last passage: the one its caret
/// is in, under the last heading before the caret that is at the level of
/// the note's day headings.
DayPassage dayPassageOf(
  DayNotePlacement placement,
  TripNoteDay day,
  TripDayNotesVocabulary vocabulary,
) {
  final text = placement.text;
  final cursor = placement.cursor;
  final scanned = tripDayNotes(text, [day], vocabulary);
  var start = scanned.headingLineEnds[day.date] ?? cursor;
  if (start > cursor) {
    // The caret is in an earlier passage of the same day: its heading is the
    // last day-level heading above the caret.
    start = _lastHeadingEndBefore(
      text,
      cursor,
      maxLevel: scanned.dayHeadingLevel ?? 6,
    );
  }
  final region = text.substring(start, cursor);
  // Blank lines under the heading stay where they are.
  final lead = RegExp(r'^(?:[ \t]*\n)*').firstMatch(region)!.end;
  return (
    before: text.substring(0, start + lead),
    passage: region.substring(lead),
    after: text.substring(cursor),
  );
}

/// Where the line after the last ATX heading of level [maxLevel] or
/// higher before [offset] in [text] starts; 0 when there is none.
int _lastHeadingEndBefore(String text, int offset, {required int maxLevel}) {
  var lineEnd = offset;
  while (lineEnd > 0) {
    final lineStart = text.lastIndexOf('\n', lineEnd - 1) + 1;
    final line = text.substring(lineStart, lineEnd);
    final level = atxHeadingLevel(line);
    if (level != null && level <= maxLevel) {
      return lineEnd < text.length ? lineEnd + 1 : lineEnd;
    }
    lineEnd = lineStart == 0 ? 0 : lineStart - 1;
  }
  return 0;
}

/// The Notes as saved with [passage] in place of [parts]' passage: as they
/// were when [passage] is the one [placement] opened with, and without a
/// heading [placement] added while nothing is written under it.
String withDayPassage(
  DayNotePlacement placement,
  DayPassage parts,
  String passage,
) => placement.toSave('${parts.before}$passage${parts.after}');
