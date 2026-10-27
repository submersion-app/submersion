import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/checks/public_vocabulary.dart';
import '../../../tool/demo_data/src/story/catalog.dart';

void main() {
  test('the bundled species catalogue is public', () {
    expect(
      Catalog.load('assets/data').publicStrings,
      containsAll(['Whale Shark', 'Rhincodon typus', 'shark']),
    );
  });

  test('tank presets, tank roles and the demo gear words are public', () {
    expect(
      demoPublicVocabulary,
      containsAll([
        'al80',
        'Diluent',
        'Stage',
        'Back gas',
        'Spool',
        'Undersuit',
        'Belt',
        'Trim',
        'Shearwater',
        'Open Water Diver',
        'Favourite',
        'Travel kit',
        'Standard',
        'front.jpg',
        'back.jpg',
      ]),
    );
  });

  test('what the app seeds into a new logbook is public', () async {
    expect(
      await appSeededStrings(),
      containsAll(['Recreational', 'Buddy', 'Reef']),
    );
  });

  test('free text the demo writes is not public', () {
    // Notes and names stay under the check: only fixed vocabulary is let
    // through.
    expect(demoPublicVocabulary, isNot(contains('Garage shelf')));
    expect(demoPublicVocabulary, isNot(contains('Home lakes')));
  });
}
