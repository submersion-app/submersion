import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/suunto_cloud/suunto_journal.dart';

/// Issue #3491: the dive details a diver logs in the Suunto app ride on the
/// cloud workout's `journal`, never in the dive export.
void main() {
  Object? fixtureJournal() {
    final body = File(
      p.join(
        'test',
        'fixtures',
        'suunto_cloud',
        'workout_journal_buddies.json',
      ),
    ).readAsStringSync();
    final payload = (jsonDecode(body) as Map)['payload'] as List;
    return (payload.single as Map)['journal'];
  }

  test('reads every field of the real workout', () {
    final journal = SuuntoJournal.parse(fixtureJournal());

    expect(journal.buddies, ['Buddy 1', 'Buddy 2', 'Buddy 3']);
    expect(journal.diveCenter, 'Dive Center');
    expect((journal.visibility!.id, journal.visibility!.text), ('good', 'Gut'));
    expect((journal.current!.id, journal.current!.text), ('none', 'Keine'));
    expect(journal.weightKg, 12.0);
    expect(journal.suit, ['Drysuit']);
    expect(journal.environment, ['See']);
    expect(journal.marineLife, ['Aal', 'Barsch', 'Krebse']);
    expect(journal.comfort, ['Optimal']);
    expect(journal.buoyancy, ['Negativ', 'Neutral']);
    expect(journal.stateOfMind, ['Entspannt']);
    expect(journal.privateNotes, isNull);
    expect(journal.isEmpty, isFalse);
  });

  test('converts pounds to kilograms', () {
    final pounds = SuuntoJournal.parse({
      'diveWeights': {'value': 10, 'unit': 'lbs'},
    });
    expect(pounds.weightKg, closeTo(4.5359237, 1e-9));
    expect(
      SuuntoJournal.parse({
        'diveWeights': {'value': 10, 'unit': 'LB'},
      }).weightKg,
      closeTo(4.5359237, 1e-9),
    );
    expect(
      SuuntoJournal.parse({
        'diveWeights': {'value': 10, 'unit': 'stone'},
      }).weightKg,
      isNull,
    );
  });

  test('a weight of zero or less is no weight', () {
    // A 0 kg belt would show on the dive and then stop a real weight from
    // ever being added.
    for (final value in [0, -2]) {
      expect(
        SuuntoJournal.parse({
          'diveWeights': {'value': value, 'unit': 'KG'},
        }).weightKg,
        isNull,
        reason: '$value',
      );
    }
  });

  test('blank values yield nothing', () {
    final journal = SuuntoJournal.parse({
      'diveBuddy': [
        {'id': 'a', 'value': '  '},
      ],
      'diveSuit': [
        {'id': 'b', 'value': ''},
      ],
      'diveMarineEncounters': [
        {'id': 'c', 'value': '\n'},
      ],
      'diveCenter': {'id': 'd', 'value': ''},
      'diveVisibility': {'id': ' ', 'value': ' '},
      'privateNotes': ' ',
    });

    expect(journal.buddies, isEmpty);
    expect(journal.suit, isEmpty);
    expect(journal.marineLife, isEmpty);
    expect(journal.diveCenter, isNull);
    expect(journal.visibility, isNull);
    expect(journal.privateNotes, isNull);
    expect(journal.isEmpty, isTrue);
  });

  test('a code with no text keeps its id as the text', () {
    final journal = SuuntoJournal.parse({
      'diveCurrent': {'id': 'strong'},
    });
    expect((journal.current!.id, journal.current!.text), ('strong', 'strong'));
  });

  test('a code with text but no id keeps its text', () {
    final journal = SuuntoJournal.parse({
      'diveVisibility': {'id': '', 'value': 'Trueb'},
    });
    expect((journal.visibility!.id, journal.visibility!.text), ('', 'Trueb'));
  });

  test('malformed shapes are passed over', () {
    final journal = SuuntoJournal.parse({
      'diveSuit': 'x',
      'diveBuddy': [
        1,
        {'value': 'Ann'},
        {'value': 'ann'},
      ],
      'diveCenter': 'TKL',
      'diveWeights': {'value': 'heavy', 'unit': 'KG'},
      'privateNotes': 7,
    });

    expect(journal.suit, isEmpty);
    expect(journal.buddies, ['Ann']);
    expect(journal.diveCenter, isNull);
    expect(journal.weightKg, isNull);
    expect(journal.privateNotes, isNull);
    expect(SuuntoJournal.parse(null).isEmpty, isTrue);
    expect(SuuntoJournal.parse('x').isEmpty, isTrue);
  });
}
