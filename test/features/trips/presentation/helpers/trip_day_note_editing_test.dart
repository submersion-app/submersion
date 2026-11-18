import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_day_note_editing.dart';

const _english = TripDayNotesVocabulary(
  dayLabels: [(prefix: 'day', suffix: '')],
  months: {'nov': 11, 'november': 11},
  weekdays: {},
);

void main() {
  final day3 = TripNoteDay(date: DateTime(2026, 11, 5), dayNumber: 3);

  DayNotePlacement place(String notes) =>
      placeDayNote(notes, day3, _english, headingLabel: 'Day 3');

  group('placeDayNote', () {
    test('an empty note gets the heading and a line under it', () {
      final placed = place('');
      expect(placed.text, '## Day 3\n');
      expect(placed.cursor, placed.text.length);
      expect(placed.insertedHeading, '## Day 3');
    });

    test('the heading goes after a blank line', () {
      expect(place('Trip intro').text, 'Trip intro\n\n## Day 3\n');
    });

    test('the added heading matches the level of the day headings', () {
      final placed = place('# Day 1\nA\n# Day 2\nB');
      expect(placed.text, '# Day 1\nA\n# Day 2\nB\n\n# Day 3\n');
      expect(placed.insertedHeading, '# Day 3');
    });

    test('a code block left open is closed before the heading', () {
      final placed = place('Gear\n```\nfins\nmask');
      expect(placed.text, 'Gear\n```\nfins\nmask\n```\n\n## Day 3\n');
      expect(placed.cursor, placed.text.length);
      expect(placed.insertedHeading, '## Day 3');
    });

    test('a longer tilde fence is closed with its own run', () {
      expect(place('~~~~\nfins').text, '~~~~\nfins\n~~~~\n\n## Day 3\n');
    });

    test('trailing blank lines are not doubled', () {
      expect(place('Trip intro\n\n').text, 'Trip intro\n\n## Day 3\n');
    });

    test(
      "a day with a passage keeps the note and goes to the passage's end",
      () {
        const notes = '## Nov 5\nWreck\n\n## Day 4\nX';
        final placed = place(notes);
        expect(placed.text, notes);
        expect(placed.cursor, notes.indexOf('Wreck') + 'Wreck'.length);
        expect(placed.insertedHeading, isNull);
      },
    );

    test('an empty heading the diver wrote is used, not doubled', () {
      const notes = 'Intro\n## Day 3\n\n## Day 4\nX';
      final placed = place(notes);
      expect(placed.text, notes);
      expect(placed.cursor, notes.indexOf('## Day 3') + '## Day 3\n'.length);
      expect(placed.insertedHeading, isNull);
    });

    test('an empty heading right above another gets a line of its own', () {
      const notes = 'Intro\n## Day 3\n## Day 4\nX';
      final placed = place(notes);
      expect(placed.text, 'Intro\n## Day 3\n\n## Day 4\nX');
      expect(placed.cursor, 'Intro\n## Day 3\n'.length);
      expect(placed.insertedHeading, isNull);
    });

    test('an empty heading on the last line gets a line under it', () {
      final placed = place('Intro\n## Day 3');
      expect(placed.text, 'Intro\n## Day 3\n');
      expect(placed.cursor, placed.text.length);
      expect(placed.insertedHeading, isNull);
    });
  });

  group('dropUntouchedDayHeading', () {
    test('drops the heading and the blank line before it', () {
      expect(
        dropUntouchedDayHeading('Trip intro\n\n## Day 3\n', '## Day 3'),
        'Trip intro',
      );
    });

    test('keeps a heading with words under it', () {
      const notes = 'Trip intro\n\n## Day 3\nSaw a turtle';
      expect(dropUntouchedDayHeading(notes, '## Day 3'), notes);
    });

    test('a later heading closes the empty one', () {
      expect(
        dropUntouchedDayHeading('## Day 3\n\n## Day 4\nX', '## Day 3'),
        '## Day 4\nX',
      );
    });

    test('between two parts, one blank line is left', () {
      expect(
        dropUntouchedDayHeading('A\n\n## Day 3\n\n## Day 4\nX', '## Day 3'),
        'A\n\n## Day 4\nX',
      );
    });

    test('only the last empty copy goes', () {
      expect(
        dropUntouchedDayHeading('## Day 3\n\n## Day 3\n', '## Day 3'),
        '## Day 3',
      );
    });

    test('a deeper heading under it counts as words', () {
      const notes = '## Day 3\n### Wreck\n';
      expect(dropUntouchedDayHeading(notes, '## Day 3'), notes);
    });

    test('a note without the heading is left alone', () {
      expect(dropUntouchedDayHeading('Intro', '## Day 3'), 'Intro');
    });

    test('reads a Windows line ending as the end of a heading', () {
      expect(
        dropUntouchedDayHeading('## Day 3\r\n## Day 4\r\nX', '## Day 3'),
        '## Day 4\r\nX',
      );
    });
  });

  group('DayNotePlacement.toSave', () {
    test('Notes left as they opened are saved as they were loaded', () {
      // The empty heading sits right above Day 4, so a line is added.
      const notes = '## Day 3\n## Day 4\nX';
      final placed = place(notes);
      expect(placed.text, isNot(notes));

      expect(placed.toSave(placed.text), notes);
    });

    test('a closed code block goes too while nothing was written', () {
      const notes = 'Gear\n```\nfins';
      final placed = place(notes);

      expect(placed.toSave(placed.text), notes);
    });

    test('words under the added heading are kept', () {
      final placed = place('Intro');

      expect(
        placed.toSave('${placed.text}Turtle'),
        'Intro\n\n## Day 3\nTurtle',
      );
    });

    test('an edit elsewhere drops the added fence with the heading', () {
      final placed = place('Gear\n```\nfins');

      expect(
        placed.toSave(placed.text.replaceFirst('Gear', 'Gear list')),
        'Gear list\n```\nfins',
      );
    });

    test('words under the added heading keep the added fence', () {
      final placed = place('Gear\n```\nfins');

      expect(
        placed.toSave('${placed.text}Turtle'),
        'Gear\n```\nfins\n```\n\n## Day 3\nTurtle',
      );
    });

    test('an edit elsewhere drops the empty added heading', () {
      final placed = place('Intro');

      expect(placed.toSave('Intro, edited\n\n## Day 3\n'), 'Intro, edited');
    });
  });
}
