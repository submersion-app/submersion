import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_editable_item.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_draft.dart';

EditablePreDiveItem _item(
  String id, {
  double? valueMin,
  String? sourceItemId,
  DateTime? updatedAt,
}) => EditablePreDiveItem(
  id: id,
  title: 'Cell 1',
  itemType: PreDiveItemType.value,
  valueMin: valueMin,
  sourceItemId: sourceItemId,
  createdAt: DateTime(2026),
  updatedAt: updatedAt ?? DateTime(2026),
);

PreDiveTemplateDraft _draft({
  bool strictOrder = false,
  List<EditablePreDiveItem> items = const [],
}) => preDiveTemplateDraft(
  name: 'Twinset',
  description: '',
  category: '',
  strictOrder: strictOrder,
  sections: const [],
  itemsInDisplayOrder: items,
);

void main() {
  test('items differing only in their stamps are equal', () {
    expect(
      _draft(items: [_item('a', updatedAt: DateTime(2026, 1, 1, 0, 0, 1))]),
      _draft(items: [_item('a')]),
    );
  });

  test('a threshold of 0.30000000000000004 and one of 0.3 draft alike', () {
    expect(
      _draft(items: [_item('a', valueMin: 0.1 + 0.2)]),
      _draft(items: [_item('a', valueMin: 0.3)]),
    );
  });

  test('a changed threshold is a change', () {
    expect(
      _draft(items: [_item('a', valueMin: 0.4)]),
      isNot(_draft(items: [_item('a', valueMin: 0.3)])),
    );
  });

  test('turning strict order on is a change', () {
    expect(_draft(strictOrder: true), isNot(_draft()));
  });

  test('a cleared source link is a change', () {
    expect(
      _draft(items: [_item('a')]),
      isNot(_draft(items: [_item('a', sourceItemId: 'b')])),
    );
  });

  test('equal drafts share a hash code', () {
    expect(
      _draft(items: [_item('a', valueMin: 1)]).hashCode,
      _draft(items: [_item('a', valueMin: 1)]).hashCode,
    );
  });
}
