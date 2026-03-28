import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';

void main() {
  group('TagSelection', () {
    test('isNew returns true when existingTagId is null', () {
      const tag = TagSelection(name: 'Vacation');
      expect(tag.isNew, isTrue);
    });

    test('isNew returns false when existingTagId is set', () {
      const tag = TagSelection(existingTagId: 'tag-123', name: 'Vacation');
      expect(tag.isNew, isFalse);
    });

    test('equality by name and existingTagId', () {
      const a = TagSelection(name: 'Vacation');
      const b = TagSelection(name: 'Vacation');
      expect(a, equals(b));
    });

    test('inequality when names differ', () {
      const a = TagSelection(name: 'Vacation');
      const b = TagSelection(name: 'Training');
      expect(a, isNot(equals(b)));
    });

    test('inequality when existingTagId differs', () {
      const a = TagSelection(existingTagId: 'id-1', name: 'Vacation');
      const b = TagSelection(existingTagId: 'id-2', name: 'Vacation');
      expect(a, isNot(equals(b)));
    });
  });
}
