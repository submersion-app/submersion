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
