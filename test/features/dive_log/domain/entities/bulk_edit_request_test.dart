import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';

void main() {
  test('hasScalarChanges is false for an all-absent companion', () {
    const req = BulkEditRequest(diveIds: ['a'], scalars: DivesCompanion());
    expect(req.hasScalarChanges, isFalse);
  });

  test('hasScalarChanges is true when any column is present', () {
    const req = BulkEditRequest(
      diveIds: ['a'],
      scalars: DivesCompanion(rating: Value(5)),
    );
    expect(req.hasScalarChanges, isTrue);
  });

  test('TagsOp carries mode and ids', () {
    const op = TagsOp(mode: BulkCollectionMode.add, tagIds: ['t1']);
    expect(op.mode, BulkCollectionMode.add);
    expect(op.tagIds, ['t1']);
  });
}
