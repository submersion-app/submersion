import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/presentation/utils/suggestion_child_fields.dart';

void main() {
  const names = {'w': 'Wreck', 'r': 'Reef'};

  test('a changed tag list goes alone', () {
    final fields = suggestionChildFields(
      originalTypeIds: {'w'},
      selectedTypeIds: {'w'},
      typeNames: names,
      originalTagIds: {'t1'},
      selectedTags: [(id: 't1', name: 'Night'), (id: 't2', name: 'Deep')],
    );
    expect(fields.keys, ['tags']);
    expect(fields['tags'], ['Night', 'Deep']);
  });

  test('a changed type list goes alone, by name', () {
    final fields = suggestionChildFields(
      originalTypeIds: {'w'},
      selectedTypeIds: {'w', 'r'},
      typeNames: names,
      originalTagIds: const {},
      selectedTags: const [],
    );
    expect(fields.keys, ['siteTypes']);
    expect(fields['siteTypes'], unorderedEquals(['Wreck', 'Reef']));
  });

  test('nothing changed, nothing proposed', () {
    expect(
      suggestionChildFields(
        originalTypeIds: {'w'},
        selectedTypeIds: {'w'},
        typeNames: names,
        originalTagIds: {'t1'},
        selectedTags: [(id: 't1', name: 'Night')],
      ),
      isEmpty,
    );
  });
}
