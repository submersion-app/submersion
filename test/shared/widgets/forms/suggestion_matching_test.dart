import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/suggestion_matching.dart';

void main() {
  const suggestions = ['Italy', 'Malta', 'Vatican City'];

  test('matches anywhere in a suggestion, without case, in order', () {
    expect(suggestionsContaining(suggestions, 'ITA'), ['Italy']);
    expect(suggestionsContaining(suggestions, 'a'), suggestions);
  });

  test('ignores accents on either side (#4498)', () {
    const accented = ['Curaçao', 'Réunion', 'Malta'];
    expect(suggestionsContaining(accented, 'curacao'), ['Curaçao']);
    expect(suggestionsContaining(accented, 'RÉU'), ['Réunion']);
    expect(suggestionsContaining(['Reunion'], 'réu'), ['Reunion']);
  });

  test('blank text offers nothing', () {
    expect(suggestionsContaining(suggestions, '  '), isEmpty);
  });
}
