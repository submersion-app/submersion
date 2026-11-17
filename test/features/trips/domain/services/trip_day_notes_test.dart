import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';

const _months = {
  'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3, //
  'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7,
  'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'sept': 9,
  'october': 10, 'oct': 10, 'november': 11, 'nov': 11,
  'december': 12, 'dec': 12,
};

const _weekdays = {
  'monday': DateTime.monday, 'mon': DateTime.monday, //
  'tuesday': DateTime.tuesday, 'tue': DateTime.tuesday,
  'wednesday': DateTime.wednesday, 'wed': DateTime.wednesday,
  'thursday': DateTime.thursday, 'thu': DateTime.thursday,
  'friday': DateTime.friday, 'fri': DateTime.friday,
  'saturday': DateTime.saturday, 'sat': DateTime.saturday,
  'sunday': DateTime.sunday, 'sun': DateTime.sunday,
};

const _english = TripDayNotesVocabulary(
  dayLabels: [(prefix: 'day', suffix: '')],
  months: _months,
  weekdays: _weekdays,
);

/// A trip of [count] days from [start], numbered from 1.
List<TripNoteDay> _days(DateTime start, int count) => [
  for (var i = 0; i < count; i++)
    TripNoteDay(
      date: DateTime(start.year, start.month, start.day + i),
      dayNumber: i + 1,
    ),
];

void main() {
  // Tuesday 3 November 2026 to Monday 9 November 2026; the 5th is a Thursday.
  final days = _days(DateTime(2026, 11, 3), 7);
  final nov5 = DateTime(2026, 11, 5);
  final nov6 = DateTime(2026, 11, 6);

  DateTime? named(String text) => dayNamedByHeading(text, days, _english);

  group('dayNamedByHeading', () {
    test('reads the day label with its number', () {
      expect(named('Day 3'), nov5);
      expect(named('day 3:'), nov5);
      expect(named('  DAY 3.  '), nov5);
    });

    test('a day number outside the trip names nothing', () {
      expect(named('Day 12'), isNull);
      expect(named('Day 0'), isNull);
    });

    test('reads an ISO date inside the trip', () {
      expect(named('2026-11-05'), nov5);
      expect(named('2026-12-05'), isNull);
    });

    test('reads month and day in either order, full or short', () {
      for (final text in [
        'Nov 5',
        'November 5',
        '5 Nov',
        '5 November',
        'Nov. 5',
        'Nov 5th',
        'Nov 5, 2026',
        '5 November 2026',
        'Thu Nov 5',
        'Thursday, 5 November',
      ]) {
        expect(named(text), nov5, reason: text);
      }
    });

    test('a weekday that contradicts the date names nothing', () {
      expect(named('Tue Nov 5'), isNull);
    });

    test('a year that is not the day\'s names nothing', () {
      expect(named('Nov 5, 2025'), isNull);
    });

    test('text that is not only a day names nothing', () {
      expect(named('Packing list'), isNull);
      expect(named('Day 3 notes'), isNull);
      expect(named('Nov 5 dives'), isNull);
      expect(named(''), isNull);
    });

    test('a yearless date finds its day across a year boundary', () {
      final newYear = _days(DateTime(2026, 12, 30), 4);
      expect(
        dayNamedByHeading('Jan 1', newYear, _english),
        DateTime(2027, 1, 1),
      );
      expect(
        dayNamedByHeading('Dec 31', newYear, _english),
        DateTime(2026, 12, 31),
      );
    });

    test('reads a label whose number comes first', () {
      const hungarian = TripDayNotesVocabulary(
        dayLabels: [(prefix: '', suffix: '. nap')],
        months: {},
        weekdays: {},
      );
      expect(dayNamedByHeading('3. nap', days, hungarian), nov5);
    });
  });

  group('review fixes', () {
    test('a month that is also a weekday word still reads as the month', () {
      // Spanish, Italian and French abbreviate both March and Tuesday "mar".
      const spanish = TripDayNotesVocabulary(
        dayLabels: [],
        months: {'mar': 3},
        weekdays: {'mar': DateTime.tuesday, 'vie': DateTime.friday},
      );
      final march = _days(DateTime(2027, 3, 2), 7);
      final mar5 = DateTime(2027, 3, 5);
      expect(dayNamedByHeading('Mar 5', march, spanish), mar5);
      expect(dayNamedByHeading('Mar 5, 2027', march, spanish), mar5);
      expect(dayNamedByHeading('vie mar 5', march, spanish), mar5);
    });

    test('a weekday name with a space in it is read whole', () {
      const hebrew = TripDayNotesVocabulary(
        dayLabels: [],
        months: {'\u05e0\u05d5\u05d1\u05de\u05d1\u05e8': 11},
        weekdays: {
          '\u05d9\u05d5\u05dd \u05d7\u05de\u05d9\u05e9\u05d9':
              DateTime.thursday,
        },
      );
      expect(
        dayNamedByHeading(
          '\u05d9\u05d5\u05dd \u05d7\u05de\u05d9\u05e9\u05d9 5 \u05e0\u05d5\u05d1\u05de\u05d1\u05e8',
          days,
          hebrew,
        ),
        nov5,
      );
    });

    test('Windows line endings still mark headings', () {
      final notes = tripDayNotes(
        '## Day 3\r\nVis\r\n## Day 4\r\nX\r\n',
        days,
        _english,
      );
      expect(notes.passages, {nov5: 'Vis', nov6: 'X'});
    });

    test('a one-line code span is not a fence', () {
      final notes = tripDayNotes('```npm i```\n## Day 3\nVis', days, _english);
      expect(notes.passages, {nov5: 'Vis'});
    });

    test(
      'a day heading outside the days asked for still holds its subheadings',
      () {
        // The editor scans for one day; the story scans for all of them. Both
        // must agree that day 3 here sits inside day 2.
        final onlyDay3 = [days[2]];
        final notes = tripDayNotes(
          '## Day 2\n### Day 3\nWreck',
          onlyDay3,
          _english,
        );
        expect(notes.passages, isEmpty);
        expect(notes.headingLineEnds, isEmpty);
      },
    );
  });

  group('tripDayNotes', () {
    TripDayNotes scan(String notes) => tripDayNotes(notes, days, _english);

    test('a passage runs to the next heading at its level', () {
      final notes = scan('## Day 3\nVis 30 m\n## Day 4\nBlown out');
      expect(notes.passages, {nov5: 'Vis 30 m', nov6: 'Blown out'});
    });

    test('a deeper heading stays inside the passage', () {
      final notes = scan('## Day 3\nMorning\n### Afternoon\nWreck\n## Packing');
      expect(notes.passages[nov5], 'Morning\n### Afternoon\nWreck');
    });

    test('a deeper heading that names another day stays inside too', () {
      final notes = scan('## Day 3\nMorning\n### Day 4\nStill day 3');
      expect(notes.passages.keys, [nov5]);
      expect(notes.passages[nov5], 'Morning\n### Day 4\nStill day 3');
    });

    test('a higher heading ends the passage', () {
      final notes = scan('## Day 3\nMorning\n# Gear\nFins');
      expect(notes.passages[nov5], 'Morning');
    });

    test('text outside day headings belongs to no day', () {
      final notes = scan('Intro\n## Packing\nFins\n## Day 3\nVis');
      expect(notes.passages, {nov5: 'Vis'});
    });

    test('two headings for one day join in order', () {
      final notes = scan('## Day 3\nFirst\n## Day 4\nX\n## Nov 5\nSecond');
      expect(notes.passages[nov5], 'First\n\nSecond');
    });

    test('a heading inside a backtick fence is not a heading', () {
      final notes = scan('## Day 3\nBefore\n```\n## Day 4\n```\nAfter');
      expect(notes.passages.keys, [nov5]);
      expect(notes.passages[nov5], 'Before\n```\n## Day 4\n```\nAfter');
    });

    test('a heading inside a tilde fence is not a heading', () {
      final notes = scan('## Day 3\n~~~~\n# Day 4\n~~~~\nAfter');
      expect(notes.passages[nov5], '~~~~\n# Day 4\n~~~~\nAfter');
    });

    test('a fence is closed only by its own character', () {
      final notes = scan('## Day 3\n```\n~~~\n## Day 4\n```\nAfter');
      expect(notes.passages.keys, [nov5]);
    });

    test('a heading with only blank lines under it has no passage', () {
      expect(scan('## Day 3\n\n   \n## Day 4\nX').passages.keys, [nov6]);
    });

    test('a heading at the end of the note has no passage', () {
      expect(scan('Intro\n## Day 3').passages, isEmpty);
      expect(scan('Intro\n## Day 3\n').passages, isEmpty);
    });

    test('a hash with no space after it is not a heading', () {
      expect(scan('#Day 3\nVis').passages, isEmpty);
    });

    test('closing hashes are ignored', () {
      expect(scan('## Day 3 ##\nVis').passages[nov5], 'Vis');
    });

    test('blank lines around a passage are trimmed', () {
      expect(scan('## Day 3\n\n\nVis\n\n\n## Day 4\nX').passages[nov5], 'Vis');
    });

    test('a passage end is the offset after its last character', () {
      const source = '## Day 3\nFirst\n## Day 4\nX\n## Day 3\nSecond line\n\n';
      final notes = scan(source);
      expect(
        notes.passageEnds[nov5],
        source.indexOf('Second line') + 'Second line'.length,
      );
    });

    test('an empty day heading is still found, by where its line ends', () {
      const source = 'Intro\n## Day 3\n\n## Day 4\nX';
      final notes = scan(source);
      expect(notes.passages.containsKey(nov5), isFalse);
      expect(
        notes.headingLineEnds[nov5],
        source.indexOf('## Day 3') + '## Day 3\n'.length,
      );
    });

    test('a heading on the last line ends at the end of the note', () {
      expect(
        scan('Intro\n## Day 3').headingLineEnds[nov5],
        'Intro\n## Day 3'.length,
      );
    });

    test('an empty note has no passages', () {
      expect(scan('').passages, isEmpty);
      expect(scan('').passageEnds, isEmpty);
    });
  });
}
