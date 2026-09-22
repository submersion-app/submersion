import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';

void main() {
  group('DuplicateAction', () {
    test('has five values', () {
      expect(DuplicateAction.values, hasLength(5));
    });

    test(
      'contains skip, importAsNew, consolidate, replaceSource and fillPlanned',
      () {
        expect(
          DuplicateAction.values,
          containsAll([
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
            DuplicateAction.consolidate,
            DuplicateAction.replaceSource,
            DuplicateAction.fillPlanned,
          ]),
        );
      },
    );

    test('values have correct indices', () {
      expect(DuplicateAction.skip.index, 0);
      expect(DuplicateAction.importAsNew.index, 1);
      expect(DuplicateAction.consolidate.index, 2);
      expect(DuplicateAction.replaceSource.index, 3);
      expect(DuplicateAction.fillPlanned.index, 4);
    });

    test('name returns correct enum name strings', () {
      expect(DuplicateAction.skip.name, 'skip');
      expect(DuplicateAction.importAsNew.name, 'importAsNew');
      expect(DuplicateAction.consolidate.name, 'consolidate');
      expect(DuplicateAction.replaceSource.name, 'replaceSource');
      expect(DuplicateAction.fillPlanned.name, 'fillPlanned');
    });
  });
}
