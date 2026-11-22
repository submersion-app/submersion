import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';

void main() {
  group('a day note (#4625)', () {
    final day3 = TripNoteDay(date: DateTime(2026, 11, 5), dayNumber: 3);

    test('the query reads back the day it was written from', () {
      expect(tripNoteDayFromQuery(tripNoteDayQuery(day3)), day3);
    });

    test('a missing or malformed day reads as none', () {
      expect(tripNoteDayFromQuery(const {}), isNull);
      expect(tripNoteDayFromQuery(const {'noteDate': '2026-11-05'}), isNull);
      expect(
        tripNoteDayFromQuery(const {'noteDate': 'x', 'noteDay': '3'}),
        isNull,
      );
      expect(
        tripNoteDayFromQuery(const {'noteDate': '2026-11-05', 'noteDay': 'x'}),
        isNull,
      );
    });

    test('an impossible date or a day number below 1 reads as none', () {
      expect(
        tripNoteDayFromQuery(const {'noteDate': '2026-02-31', 'noteDay': '3'}),
        isNull,
      );
      expect(
        tripNoteDayFromQuery(const {'noteDate': '2026-13-01', 'noteDay': '3'}),
        isNull,
      );
      expect(
        tripNoteDayFromQuery(const {'noteDate': '2026-11-05', 'noteDay': '0'}),
        isNull,
      );
    });

    test('reads the notes section by name', () {
      expect(TripEditSection.fromQuery('notes'), TripEditSection.notes);
    });
  });

  group('TripEditSection.fromQuery', () {
    test('reads a section by name', () {
      expect(TripEditSection.fromQuery('planning'), TripEditSection.planning);
    });

    test('is null for a missing or unknown section', () {
      expect(TripEditSection.fromQuery(null), isNull);
      expect(TripEditSection.fromQuery('bogus'), isNull);
    });
  });
}
