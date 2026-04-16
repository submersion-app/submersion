import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';

void main() {
  group('DuplicateAction', () {
    test('has four values', () {
      expect(DuplicateAction.values, hasLength(4));
    });

    test('contains skip, importAsNew, consolidate, and replaceSource', () {
      expect(
        DuplicateAction.values,
        containsAll([
          DuplicateAction.skip,
          DuplicateAction.importAsNew,
          DuplicateAction.consolidate,
          DuplicateAction.replaceSource,
        ]),
      );
    });

    test('values have correct indices', () {
      expect(DuplicateAction.skip.index, 0);
      expect(DuplicateAction.importAsNew.index, 1);
      expect(DuplicateAction.consolidate.index, 2);
      expect(DuplicateAction.replaceSource.index, 3);
    });

    test('name returns correct enum name strings', () {
      expect(DuplicateAction.skip.name, 'skip');
      expect(DuplicateAction.importAsNew.name, 'importAsNew');
      expect(DuplicateAction.consolidate.name, 'consolidate');
      expect(DuplicateAction.replaceSource.name, 'replaceSource');
    });
  });
}
