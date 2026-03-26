import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';

void main() {
  group('DuplicateAction', () {
    test('has three values', () {
      expect(DuplicateAction.values, hasLength(3));
    });

    test('contains skip, importAsNew, and consolidate', () {
      expect(
        DuplicateAction.values,
        containsAll([
          DuplicateAction.skip,
          DuplicateAction.importAsNew,
          DuplicateAction.consolidate,
        ]),
      );
    });

    test('values have correct indices', () {
      expect(DuplicateAction.skip.index, 0);
      expect(DuplicateAction.importAsNew.index, 1);
      expect(DuplicateAction.consolidate.index, 2);
    });

    test('name returns correct enum name strings', () {
      expect(DuplicateAction.skip.name, 'skip');
      expect(DuplicateAction.importAsNew.name, 'importAsNew');
      expect(DuplicateAction.consolidate.name, 'consolidate');
    });
  });
}
