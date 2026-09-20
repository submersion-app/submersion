import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  test('every field parses by its JSON name and back', () {
    for (final f in ExploreDiveField.values) {
      expect(DiveFieldCatalog.parse(f.jsonName), f);
    }
    expect(DiveFieldCatalog.parse('bogus'), isNull);
    expect(
      DiveFieldCatalog.jsonNames,
      hasLength(ExploreDiveField.values.length),
    );
  });

  test('depth is a numeric depth field with ordering ops', () {
    final spec = DiveFieldCatalog.spec(ExploreDiveField.depth);
    expect(spec.dimension, FieldDimension.depth);
    expect(spec.valueType, FieldValueType.number);
    expect(spec.ops, containsAll([ClauseOp.gt, ClauseOp.lt, ClauseOp.between]));
    expect(spec.ops, isNot(contains(ClauseOp.inList)));
  });

  test('waterType is an enum field accepting eq, in and not', () {
    final spec = DiveFieldCatalog.spec(ExploreDiveField.waterType);
    expect(spec.valueType, FieldValueType.enumName);
    expect(spec.enumValues, ['salt', 'fresh', 'brackish']);
    expect(spec.ops, {ClauseOp.eq, ClauseOp.inList, ClauseOp.not});
  });

  test('favorite, deco and noBuddy are flags accepting eq only', () {
    for (final f in [
      ExploreDiveField.favorite,
      ExploreDiveField.deco,
      ExploreDiveField.noBuddy,
    ]) {
      expect(DiveFieldCatalog.spec(f).valueType, FieldValueType.flag);
      expect(DiveFieldCatalog.spec(f).ops, {ClauseOp.eq});
    }
  });
}
