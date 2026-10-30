import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_journal.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_journal_mapping.dart';

/// Issue #3491: only Suunto codes seen in real data map to Submersion
/// values; everything else is kept as text in custom fields.
void main() {
  SuuntoJournal fixtureJournal() {
    final body = File(
      p.join(
        'test',
        'fixtures',
        'suunto_cloud',
        'workout_journal_buddies.json',
      ),
    ).readAsStringSync();
    final payload = (jsonDecode(body) as Map)['payload'] as List;
    return SuuntoJournal.parse((payload.single as Map)['journal']);
  }

  test('only codes seen in real data map', () {
    expect(suuntoVisibilityBand('good'), VisibilityBand.good);
    expect(suuntoVisibilityBand('excellent'), isNull);
    expect(suuntoVisibilityBand('GOOD'), isNull);
    expect(suuntoCurrentStrength('none'), CurrentStrength.none);
    expect(suuntoCurrentStrength('light'), isNull);
  });

  test('the real workout yields its custom fields in order', () {
    expect(suuntoCustomFields(fixtureJournal()), [
      (key: 'Suit', value: 'Drysuit'),
      (key: 'Environment', value: 'See'),
      (key: 'Comfort', value: 'Optimal'),
      (key: 'Buoyancy', value: 'Negativ, Neutral'),
      (key: 'State of mind', value: 'Entspannt'),
    ]);
  });

  test('an unmapped visibility or current code is kept as text', () {
    const journal = SuuntoJournal(
      visibility: SuuntoCoded(id: 'excellent', text: 'Exzellent'),
      current: SuuntoCoded(id: 'strong', text: 'Stark'),
    );

    expect(suuntoCustomFields(journal), [
      (key: 'Visibility', value: 'Exzellent'),
      (key: 'Current', value: 'Stark'),
    ]);
  });

  test('a code with no id is kept as text', () {
    const journal = SuuntoJournal(
      visibility: SuuntoCoded(id: '', text: 'Trueb'),
    );

    expect(suuntoCustomFields(journal), [(key: 'Visibility', value: 'Trueb')]);
  });

  test('a mapped code adds no custom field', () {
    const journal = SuuntoJournal(
      visibility: SuuntoCoded(id: 'good', text: 'Gut'),
      current: SuuntoCoded(id: 'none', text: 'Keine'),
    );

    expect(suuntoCustomFields(journal), isEmpty);
  });
}
