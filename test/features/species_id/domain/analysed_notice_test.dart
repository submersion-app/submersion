import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/labels_menu_model.dart';

import '../data/identification_fixtures.dart';

/// What the viewer says once an Analyse the diver asked for has finished
/// and its finds would otherwise draw nothing in Names (issue #4872).
void main() {
  MediaIdentification unnamed(String id) => identification(
    id,
  ).copyWith(suggestable: false, confident: false, specific: false);

  test('nothing found says so', () {
    expect(analysedNotice(const []), AnalysedNotice.nothingFound);
  });

  test('only dismissed finds count as nothing found', () {
    expect(
      analysedNotice([
        identification('a', decision: IdentificationDecision.rejected),
      ]),
      AnalysedNotice.nothingFound,
    );
  });

  test('finds with no name say how many and that none is named', () {
    expect(
      analysedNotice([unnamed('a'), unnamed('b')]),
      AnalysedNotice.noneNamed,
    );
  });

  test('an unnamed find Names dots (it looks like something) still counts '
      'as none named', () {
    expect(
      analysedNotice([unnamed('a').copyWith(specific: true)]),
      AnalysedNotice.noneNamed,
    );
  });

  test('a suggestion is a name: no notice, its pill shows', () {
    expect(
      analysedNotice([
        unnamed('a'),
        identification('b').copyWith(suggestable: true, confident: false),
      ]),
      isNull,
    );
  });

  test('a confident name, a tagged one or a video track named are names', () {
    expect(
      analysedNotice([identification('a').copyWith(confident: true)]),
      isNull,
    );
    expect(
      analysedNotice([
        identification(
          'b',
          decision: IdentificationDecision.accepted,
        ).copyWith(suggestable: true),
      ]),
      isNull,
    );
    expect(analysedNotice([track('c')]), isNull);
  });

  test('a found count leaves dismissed finds out', () {
    expect(
      foundCount([
        unnamed('a'),
        identification('b', decision: IdentificationDecision.rejected),
      ]),
      1,
    );
  });
}
