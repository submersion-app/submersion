import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/suggestion_matching.dart';

void main() {
  const suggestions = ['Italy', 'Malta', 'Vatican City'];

  test('matches anywhere in a suggestion, without case, in order', () {
    expect(suggestionsContaining(suggestions, 'ITA'), ['Italy']);
    expect(suggestionsContaining(suggestions, 'a'), suggestions);
  });

  test('blank text offers nothing', () {
    expect(suggestionsContaining(suggestions, '  '), isEmpty);
  });
}
